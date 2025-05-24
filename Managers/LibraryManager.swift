import Foundation
import AppKit

class LibraryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tracks: [Track] = []
    @Published var folders: [Folder] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage: String = ""
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var fileWatcherTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private var securityBookmarks: [URL: Data] = [:]
    
    // Database manager
    private let databaseManager = DatabaseManager()
    
    // Cache manager
    private let cacheManager = TrackCacheManager()
    
    // Cache for database folders only
    private var databaseFolders: [DatabaseFolder] = []
    
    // Keys for UserDefaults
    private enum UserDefaultsKeys {
        static let lastScanDate = "LastScanDate"
        static let securityBookmarks = "SecurityBookmarks"
    }
    
    // MARK: - Initialization
    init() {
        print("LibraryManager: Initializing...")
        
        // Observe database manager scanning state
        databaseManager.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
        
        databaseManager.$scanProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$scanProgress)
        
        databaseManager.$scanStatusMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$scanStatusMessage)
        
        loadSecurityBookmarks()
        loadMusicLibrary()
        startFileWatcher()
        
        // Register for memory pressure notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    deinit {
        fileWatcherTimer?.invalidate()
        // Stop accessing all security scoped resources
        for (url, _) in securityBookmarks {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: - Security Bookmarks
    
    private func saveSecurityBookmarks() {
        var bookmarkData: [String: Data] = [:]
        
        for (url, data) in securityBookmarks {
            bookmarkData[url.absoluteString] = data
        }
        
        userDefaults.set(bookmarkData, forKey: UserDefaultsKeys.securityBookmarks)
        print("LibraryManager: Saved \(bookmarkData.count) security bookmarks")
    }
    
    private func loadSecurityBookmarks() {
        guard let savedBookmarks = userDefaults.dictionary(forKey: UserDefaultsKeys.securityBookmarks) as? [String: Data] else {
            print("LibraryManager: No security bookmarks found")
            return
        }
        
        for (urlString, bookmarkData) in savedBookmarks {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                
                if isStale {
                    print("LibraryManager: Bookmark is stale for \(urlString)")
                    continue
                }
                
                // Start accessing the security scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("LibraryManager: Failed to start accessing security scoped resource for \(urlString)")
                    continue
                }
                
                securityBookmarks[url] = bookmarkData
                print("LibraryManager: Restored security bookmark for \(url.lastPathComponent)")
                
            } catch {
                print("LibraryManager: Failed to resolve bookmark for \(urlString): \(error)")
            }
        }
    }
    
    private func createSecurityBookmark(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
            securityBookmarks[url] = bookmarkData
            saveSecurityBookmarks()
            return bookmarkData
        } catch {
            print("LibraryManager: Failed to create security bookmark for \(url.path): \(error)")
            return nil
        }
    }
    
    // MARK: - Folder Management
    
    func addFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Add Music Folder"
        openPanel.message = "Select folders containing your music files"
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK else { return }
            
            var urlsToAdd: [URL] = []
            
            for url in openPanel.urls {
                // Create and save security bookmark
                if self.createSecurityBookmark(for: url) != nil {
                    urlsToAdd.append(url)
                    print("LibraryManager: Added folder - \(url.lastPathComponent) at \(url.path)")
                }
            }
            
            // Add folders to database
            if !urlsToAdd.isEmpty {
                // Show scanning immediately
                self.isScanning = true
                self.scanStatusMessage = "Preparing to scan folders..."
                
                // Small delay to ensure UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.databaseManager.addFolders(urlsToAdd) { result in
                        switch result {
                        case .success(let dbFolders):
                            print("LibraryManager: Successfully added \(dbFolders.count) folders to database")
                            self.loadMusicLibrary() // Reload to reflect changes
                        case .failure(let error):
                            print("LibraryManager: Failed to add folders to database: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func removeFolder(_ folder: Folder) {
        // Find the corresponding database folder
        guard let dbFolder = databaseFolders.first(where: { $0.path == folder.url.path }) else {
            print("LibraryManager: Folder not found in database")
            return
        }
        
        // Stop accessing the security scoped resource
        if securityBookmarks[folder.url] != nil {
            folder.url.stopAccessingSecurityScopedResource()
            securityBookmarks.removeValue(forKey: folder.url)
            saveSecurityBookmarks()
        }
        
        // Remove from database
        databaseManager.removeFolder(dbFolder) { [weak self] result in
            switch result {
            case .success:
                print("LibraryManager: Successfully removed folder from database")
                self?.loadMusicLibrary() // Reload to reflect changes
            case .failure(let error):
                print("LibraryManager: Failed to remove folder from database: \(error)")
            }
        }
    }
    
    // MARK: - Data Management
    
    func loadMusicLibrary() {
        print("LibraryManager: Loading music library from database...")
        
        // Clear caches when reloading
        cacheManager.clearAllCaches()
        
        // Load folders from database
        databaseFolders = databaseManager.getAllFolders()
        folders = databaseFolders.map { dbFolder in
            Folder(url: URL(fileURLWithPath: dbFolder.path))
        }
        
        // Load lightweight tracks from database (without artwork)
        let dbTracks = databaseManager.getAllTracksLightweight()
        tracks = dbTracks.map { dbTrack in
            cacheManager.getTrack(from: dbTrack, using: databaseManager)
        }
        
        print("LibraryManager: Loaded \(folders.count) folders and \(tracks.count) tracks from database")
        
        // Update last scan date
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastScanDate)
    }
    
    // MARK: - File Watching
    
    private func startFileWatcher() {
        // Create a timer that checks for file changes every 5 minutes
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only refresh if we're not currently scanning
            if !self.isScanning {
                print("LibraryManager: Starting periodic refresh...")
                self.refreshLibrary()
            }
        }
    }
    
    // MARK: - Track Management
    
    func getTracksInFolder(_ folder: Folder) -> [Track] {
        // Find the corresponding database folder
        guard let dbFolder = databaseFolders.first(where: { $0.path == folder.url.path }) else {
            print("LibraryManager: Folder not found in database")
            return []
        }
        
        // Get lightweight tracks from database and use cache
        let dbTracks = databaseManager.getTracksForFolderLightweight(dbFolder.id)
        return cacheManager.getTracksForFolder(dbFolder.id, from: dbTracks, using: databaseManager)
    }
    
    func getTracksByArtist(_ artist: String) -> [Track] {
        let dbTracks = databaseManager.getTracksByArtistLightweight(artist)
        return dbTracks.map { cacheManager.getTrack(from: $0, using: databaseManager) }
    }
    
    func getTracksByArtistContaining(_ artistName: String) -> [Track] {
        // The database method already uses LIKE with wildcards
        return getTracksByArtist(artistName)
    }
    
    func getTracksByAlbum(_ album: String) -> [Track] {
        let dbTracks = databaseManager.getTracksByAlbumLightweight(album)
        return dbTracks.map { cacheManager.getTrack(from: $0, using: databaseManager) }
    }
    
    func getTracksByGenre(_ genre: String) -> [Track] {
        let dbTracks = databaseManager.getTracksByGenre(genre)
        return dbTracks.map { cacheManager.getTrack(from: $0, using: databaseManager) }
    }
    
    func getTracksByYear(_ year: String) -> [Track] {
        let dbTracks = databaseManager.getTracksByYear(year)
        return dbTracks.map { cacheManager.getTrack(from: $0, using: databaseManager) }
    }
    
    func getAllArtists() -> [String] {
        return databaseManager.getAllArtists()
    }
    
    func getAllAlbums() -> [String] {
        return databaseManager.getAllAlbums()
    }
    
    func getAllGenres() -> [String] {
        return databaseManager.getAllGenres()
    }
    
    func getAllYears() -> [String] {
        return databaseManager.getAllYears()
    }
    
    // MARK: - Library Maintenance
    
    func refreshLibrary() {
        print("LibraryManager: Refreshing library...")
        
        // For each folder, trigger a refresh in the database
        for dbFolder in databaseFolders {
            databaseManager.refreshFolder(dbFolder) { result in
                switch result {
                case .success:
                    print("LibraryManager: Successfully refreshed folder \(dbFolder.name)")
                case .failure(let error):
                    print("LibraryManager: Failed to refresh folder \(dbFolder.name): \(error)")
                }
            }
        }
        
        // Reload the library after refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadMusicLibrary()
        }
    }
    
    func refreshFolder(_ folder: Folder) {
        // Find the corresponding database folder
        guard let dbFolder = databaseFolders.first(where: { $0.path == folder.url.path }) else {
            print("LibraryManager: Folder not found in database")
            return
        }
        
        // Clear cache for this folder
        cacheManager.clearFolderCache(dbFolder.id)
        
        // Delegate to database manager for refresh
        databaseManager.refreshFolder(dbFolder) { [weak self] result in
            switch result {
            case .success:
                print("LibraryManager: Successfully refreshed folder \(dbFolder.name)")
                // Reload the library to reflect changes
                self?.loadMusicLibrary()
            case .failure(let error):
                print("LibraryManager: Failed to refresh folder \(dbFolder.name): \(error)")
            }
        }
    }
    
    func cleanupMissingFolders() {
        // Check each folder to see if it still exists
        var foldersToRemove: [DatabaseFolder] = []
        
        for dbFolder in databaseFolders {
            if !fileManager.fileExists(atPath: dbFolder.path) {
                foldersToRemove.append(dbFolder)
            }
        }
        
        if !foldersToRemove.isEmpty {
            print("LibraryManager: Cleaning up \(foldersToRemove.count) missing folders")
            
            for folder in foldersToRemove {
                databaseManager.removeFolder(folder) { _ in }
            }
            
            // Reload after cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadMusicLibrary()
            }
        }
    }
    
    // MARK: - Memory Management
    
    @objc private func handleMemoryPressure() {
        print("LibraryManager: Handling memory pressure")
        cacheManager.handleMemoryPressure()
        
        // Clear artwork from tracks that aren't currently playing
        if let coordinator = AppCoordinator.shared,
           let currentTrack = coordinator.audioPlayerManager.currentTrack {
            // Clear artwork from all tracks except the current one
            for track in tracks {
                if track.id != currentTrack.id,
                   let lightweightTrack = track as? LightweightTrack {
                    lightweightTrack.clearArtwork()
                }
            }
        } else {
            // No track playing, clear all artwork
            for track in tracks {
                if let lightweightTrack = track as? LightweightTrack {
                    lightweightTrack.clearArtwork()
                }
            }
        }
    }
}
