import Foundation
import AppKit

class LibraryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tracks: [Track] = []
    @Published var folders: [Folder] = []
    @Published var isScanning: Bool = false
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var fileWatcherTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private var securityBookmarks: [URL: Data] = [:]
    
    // Keys for UserDefaults
    private enum UserDefaultsKeys {
        static let savedFolders = "SavedMusicFolders"
        static let savedTracks = "SavedMusicTracks"
        static let lastScanDate = "LastScanDate"
        static let securityBookmarks = "SecurityBookmarks"
    }
    
    // MARK: - Initialization
    init() {
        print("LibraryManager: Initializing...")
        loadSecurityBookmarks()
        loadMusicLibrary()
        startFileWatcher()
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
            
            for url in openPanel.urls {
                let folder = Folder(url: url)
                
                // Check if folder already exists
                if !self.folders.contains(where: { $0.url == url }) {
                    self.folders.append(folder)
                    print("LibraryManager: Added folder - \(folder.name) at \(url.path)")
                    
                    // Create and save security bookmark
                    _ = self.createSecurityBookmark(for: url)
                    
                    // Start scanning for music files immediately
                    self.scanFolderForMusicFiles(url)
                } else {
                    print("LibraryManager: Folder already exists - \(folder.name)")
                }
            }
            
            // Save the updated folder list
            self.saveMusicLibrary()
        }
    }
    
    func removeFolder(_ folder: Folder) {
        // Stop accessing the security scoped resource
        if securityBookmarks[folder.url] != nil {
            folder.url.stopAccessingSecurityScopedResource()
            securityBookmarks.removeValue(forKey: folder.url)
            saveSecurityBookmarks()
        }
        
        folders.removeAll(where: { $0.id == folder.id })
        
        // Remove tracks that were in this folder
        let folderPrefix = folder.url.path
        tracks.removeAll(where: { $0.url.path.hasPrefix(folderPrefix) })
        
        saveMusicLibrary()
    }
    
    // MARK: - File Scanning
    
    func scanFolderForMusicFiles(_ folderURL: URL) {
        print("LibraryManager: Starting scan of folder - \(folderURL.path)")
        
        // Set scanning state
        DispatchQueue.main.async {
            self.isScanning = true
        }
        
        // Supported audio formats
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "flac"]
        
        // Use a background thread for scanning
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newTracks: [Track] = []
            var scannedFiles = 0
            
            do {
                // Check if we have access to this folder (should already be started from bookmark)
                let hasAccess = self.securityBookmarks[folderURL] != nil
                
                if !hasAccess {
                    print("LibraryManager: No security bookmark found for \(folderURL.path)")
                    DispatchQueue.main.async { self.isScanning = false }
                    return
                }
                
                // Get all files in the directory and subdirectories
                let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey, .fileSizeKey]
                let directoryEnumerator = self.fileManager.enumerator(
                    at: folderURL,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { (url, error) -> Bool in
                        print("LibraryManager: Error accessing \(url.path): \(error.localizedDescription)")
                        return true
                    }
                )
                
                guard let enumerator = directoryEnumerator else {
                    print("LibraryManager: Failed to create directory enumerator for \(folderURL.path)")
                    DispatchQueue.main.async { self.isScanning = false }
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    scannedFiles += 1
                    
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                        
                        // Skip if not a regular file
                        guard resourceValues.isRegularFile == true else { continue }
                        
                        let fileExtension = fileURL.pathExtension.lowercased()
                        
                        // Check if it's a supported audio file
                        if supportedExtensions.contains(fileExtension) {
                            // Check if we already have this track
                            let existingTrackExists = self.tracks.contains { existingTrack in
                                existingTrack.url.path == fileURL.path
                            }
                            
                            if !existingTrackExists {
                                let track = Track(url: fileURL)
                                newTracks.append(track)
                                print("LibraryManager: Found new track - \(fileURL.lastPathComponent)")
                            }
                        }
                    } catch {
                        print("LibraryManager: Error reading file properties for \(fileURL.path): \(error.localizedDescription)")
                    }
                }
                
                print("LibraryManager: Scanned \(scannedFiles) files, found \(newTracks.count) new tracks in \(folderURL.lastPathComponent)")
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.tracks.append(contentsOf: newTracks)
                    self.isScanning = false
                    self.saveMusicLibrary() // Save after adding tracks
                    print("LibraryManager: Total tracks in library: \(self.tracks.count)")
                }
                
            } catch {
                print("LibraryManager: Error scanning folder \(folderURL.path): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }
    
    // MARK: - File Access Helper
    
    func ensureFileAccess(for url: URL) -> Bool {
        // Check if this file is within one of our secured folders
        for securedURL in securityBookmarks.keys {
            if url.path.hasPrefix(securedURL.path) {
                return true // We have access through the parent folder
            }
        }
        
        print("LibraryManager: No access available for file: \(url.path)")
        return false
    }
    
    // MARK: - File Watching
    
    private func startFileWatcher() {
        // Create a timer that checks for file changes every 5 minutes
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only scan if we're not currently scanning
            if !self.isScanning {
                print("LibraryManager: Starting periodic scan...")
                for folder in self.folders {
                    self.scanFolderForMusicFiles(folder.url)
                }
            }
        }
    }
    
    // MARK: - Data Management
    
    func saveMusicLibrary() {
        print("LibraryManager: Saving music library...")
        
        // Save folders
        let folderData = folders.map { folder in
            [
                "id": folder.id.uuidString,
                "url": folder.url.absoluteString,
                "name": folder.name
            ]
        }
        userDefaults.set(folderData, forKey: UserDefaultsKeys.savedFolders)
        
        // Save tracks
        let trackData = tracks.map { track in
            [
                "id": track.id.uuidString,
                "url": track.url.absoluteString,
                "title": track.title,
                "artist": track.artist,
                "album": track.album,
                "genre": track.genre,
                "year": track.year,
                "duration": String(track.duration),
                "format": track.format
            ]
        }
        userDefaults.set(trackData, forKey: UserDefaultsKeys.savedTracks)
        
        // Save last scan date
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastScanDate)
        
        print("LibraryManager: Saved \(folders.count) folders and \(tracks.count) tracks to UserDefaults")
    }
    
    func loadMusicLibrary() {
        print("LibraryManager: Loading music library from UserDefaults...")
        
        // Clear existing data
        folders.removeAll()
        tracks.removeAll()
        
        // Load saved folders
        if let savedFolderData = userDefaults.array(forKey: UserDefaultsKeys.savedFolders) as? [[String: String]] {
            var loadedFolders: [Folder] = []
            
            for folderDict in savedFolderData {
                guard let urlString = folderDict["url"],
                      let url = URL(string: urlString) else {
                    print("LibraryManager: Invalid folder data found, skipping...")
                    continue
                }
                
                // Check if the folder still exists and we have access
                if fileManager.fileExists(atPath: url.path) && securityBookmarks[url] != nil {
                    let folder = Folder(url: url)
                    loadedFolders.append(folder)
                    print("LibraryManager: Loaded folder - \(folder.name)")
                } else {
                    print("LibraryManager: Folder no longer exists or no access - \(url.path)")
                }
            }
            
            folders = loadedFolders
        }
        
        // Load saved tracks
        if let savedTrackData = userDefaults.array(forKey: UserDefaultsKeys.savedTracks) as? [[String: String]] {
            var loadedTracks: [Track] = []
            
            for trackDict in savedTrackData {
                guard let urlString = trackDict["url"],
                      let url = URL(string: urlString) else {
                    print("LibraryManager: Invalid track data found, skipping...")
                    continue
                }
                
                // Check if the track file still exists and we have access
                if fileManager.fileExists(atPath: url.path) && ensureFileAccess(for: url) {
                    let track = Track(url: url)
                    
                    // Restore saved metadata
                    if let title = trackDict["title"], !title.isEmpty {
                        track.title = title
                    }
                    if let artist = trackDict["artist"], !artist.isEmpty {
                        track.artist = artist
                    }
                    if let album = trackDict["album"], !album.isEmpty {
                        track.album = album
                    }
                    if let genre = trackDict["genre"], !genre.isEmpty {
                        track.genre = genre
                    }
                    if let year = trackDict["year"], !year.isEmpty {
                        track.year = year
                    }
                    if let durationString = trackDict["duration"],
                       let duration = Double(durationString) {
                        track.duration = duration
                    }
                    
                    loadedTracks.append(track)
                } else {
                    print("LibraryManager: Track file no longer exists or no access - \(url.path)")
                }
            }
            
            tracks = loadedTracks
            print("LibraryManager: Loaded \(loadedTracks.count) tracks from UserDefaults")
        }
        
        print("LibraryManager: Library loading complete - \(folders.count) folders, \(tracks.count) tracks")
    }
    
    // MARK: - Track Management
    
    func getTracksInFolder(_ folder: Folder) -> [Track] {
        let folderPrefix = folder.url.path
        let folderTracks = tracks.filter { $0.url.path.hasPrefix(folderPrefix) }
        print("LibraryManager: Found \(folderTracks.count) tracks in folder \(folder.name)")
        return folderTracks
    }
    
    func getTracksByArtist(_ artist: String) -> [Track] {
        return tracks.filter { $0.artist == artist }
    }
    
    func getTracksByArtistContaining(_ artistName: String) -> [Track] {
        return tracks.filter { track in
            track.artist.localizedCaseInsensitiveContains(artistName)
        }
    }
    
    func getTracksByAlbum(_ album: String) -> [Track] {
        return tracks.filter { $0.album == album }
    }
    
    func getTracksByGenre(_ genre: String) -> [Track] {
        return tracks.filter { $0.genre == genre }
    }
    
    func getTracksByYear(_ year: String) -> [Track] {
        return tracks.filter { $0.year == year }
    }
    
    func getAllArtists() -> [String] {
        return Array(Set(tracks.map { $0.artist })).sorted()
    }
    
    func getAllAlbums() -> [String] {
        return Array(Set(tracks.map { $0.album })).sorted()
    }
    
    func getAllGenres() -> [String] {
        return Array(Set(tracks.map { $0.genre })).sorted()
    }
    
    func getAllYears() -> [String] {
        return Array(Set(tracks.map { $0.year })).sorted {
            // Sort years in descending order (newest first)
            $0.localizedStandardCompare($1) == .orderedDescending
        }
    }
    
    // MARK: - Library Maintenance
    
    func refreshLibrary() {
        print("LibraryManager: Refreshing library...")
        
        // Clear existing tracks and rescan all folders
        tracks.removeAll()
        
        for folder in folders {
            scanFolderForMusicFiles(folder.url)
        }
    }
    
    func cleanupMissingFolders() {
        // Remove folders that no longer exist
        let existingFolders = folders.filter { folder in
            fileManager.fileExists(atPath: folder.url.path)
        }
        
        if existingFolders.count != folders.count {
            print("LibraryManager: Cleaning up \(folders.count - existingFolders.count) missing folders")
            folders = existingFolders
            saveMusicLibrary()
            refreshLibrary()
        }
    }
}
