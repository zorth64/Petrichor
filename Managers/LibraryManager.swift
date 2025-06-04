import Foundation
import AppKit

class LibraryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tracks: [Track] = []
    @Published var folders: [Folder] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage: String = ""
    @Published var isBackgroundScanning: Bool = false
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var fileWatcherTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private var folderTrackCounts: [Int64: Int] = [:]
    
    // Database manager
    let databaseManager: DatabaseManager
    
    // Keys for UserDefaults
    private enum UserDefaultsKeys {
        static let lastScanDate = "LastScanDate"
        static let securityBookmarks = "SecurityBookmarks"
        static let autoScanInterval = "autoScanInterval"
    }
    
    private var autoScanInterval: AutoScanInterval {
        let rawValue = userDefaults.string(forKey: UserDefaultsKeys.autoScanInterval) ?? AutoScanInterval.every60Minutes.rawValue
        return AutoScanInterval(rawValue: rawValue) ?? .every60Minutes
    }
    
    // MARK: - Initialization
    init() {
        do {
            // Initialize database manager
            databaseManager = try DatabaseManager()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
        
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
        
        loadMusicLibrary()
        startFileWatcher()
        
        // Observe auto-scan interval changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoScanIntervalDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        fileWatcherTimer?.invalidate()
        // Stop accessing all security scoped resources
        for folder in folders {
            if folder.bookmarkData != nil {
                folder.url.stopAccessingSecurityScopedResource()
            }
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
        
        openPanel.beginSheetModal(for: NSApp.keyWindow!) { [weak self] response in
            guard let self = self, response == .OK else { return }
            
            var urlsToAdd: [URL] = []
            var bookmarkDataMap: [URL: Data] = [:]
            
            for url in openPanel.urls {
                // Create security bookmark
                do {
                    let bookmarkData = try url.bookmarkData(options: [.withSecurityScope],
                                                            includingResourceValuesForKeys: nil,
                                                            relativeTo: nil)
                    urlsToAdd.append(url)
                    bookmarkDataMap[url] = bookmarkData
                    print("LibraryManager: Created bookmark for folder - \(url.lastPathComponent) at \(url.path)")
                } catch {
                    print("LibraryManager: Failed to create security bookmark for \(url.path): \(error)")
                }
            }
            
            // Add folders to database with their bookmarks
            if !urlsToAdd.isEmpty {
                // Show scanning immediately
                self.isScanning = true
                self.scanStatusMessage = "Preparing to scan folders..."
                
                // Small delay to ensure UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.databaseManager.addFolders(urlsToAdd, bookmarkDataMap: bookmarkDataMap) { result in
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
        // Remove from database
        databaseManager.removeFolder(folder) { [weak self] result in
            switch result {
            case .success:
                print("LibraryManager: Successfully removed folder from database")
                self?.loadMusicLibrary() // Reload to reflect changes
            case .failure(let error):
                print("LibraryManager: Failed to remove folder from database: \(error)")
            }
        }
    }
    
    private func refreshBookmarkForFolder(_ folder: Folder) async {
        // Only refresh if we can access the folder
        guard FileManager.default.fileExists(atPath: folder.url.path) else {
            print("LibraryManager: Folder no longer exists at \(folder.url.path)")
            return
        }
        
        do {
            // Create a fresh bookmark
            let newBookmarkData = try folder.url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Update the folder with new bookmark
            var updatedFolder = folder
            updatedFolder.bookmarkData = newBookmarkData
            
            // Save to database
            try await databaseManager.updateFolderBookmark(folder.id!, bookmarkData: newBookmarkData)
            
            print("LibraryManager: Successfully refreshed bookmark for \(folder.name)")
        } catch {
            print("LibraryManager: Failed to refresh bookmark for \(folder.name): \(error)")
        }
    }
    
    // MARK: - Data Management
    
    func loadMusicLibrary() {
        print("LibraryManager: Loading music library from database...")
        
        // Clear caches
        folderTrackCounts.removeAll()
        
        // Load folders and resolve their bookmarks
        let dbFolders = databaseManager.getAllFolders()
        var resolvedFolders: [Folder] = []
        var foldersNeedingRefresh: [Folder] = []
        
        for folder in dbFolders {
            var folderAccessible = false
            
            // Try to resolve bookmark if available
            if let bookmarkData = folder.bookmarkData {
                do {
                    var isStale = false
                    let resolvedURL = try URL(resolvingBookmarkData: bookmarkData,
                                             options: [.withSecurityScope],
                                             relativeTo: nil,
                                             bookmarkDataIsStale: &isStale)
                    
                    // Start accessing the security scoped resource
                    if resolvedURL.startAccessingSecurityScopedResource() {
                        folderAccessible = true
                        resolvedFolders.append(folder)
                        print("LibraryManager: Successfully resolved bookmark for \(folder.name)")
                        
                        if isStale {
                            print("LibraryManager: Bookmark for \(folder.name) is stale, queuing for refresh")
                            foldersNeedingRefresh.append(folder)
                        }
                    } else {
                        print("LibraryManager: Failed to start accessing security scoped resource for \(folder.name)")
                    }
                } catch {
                    print("LibraryManager: Failed to resolve bookmark for \(folder.name): \(error)")
                }
            } else {
                print("LibraryManager: No bookmark data for \(folder.name)")
            }
            
            // If bookmark resolution failed but folder exists, try to create new bookmark
            if !folderAccessible && FileManager.default.fileExists(atPath: folder.url.path) {
                print("LibraryManager: Attempting to create new bookmark for accessible folder \(folder.name)")
                
                // Check if we already have permission to access this path
                if folder.url.startAccessingSecurityScopedResource() {
                    // We have access! Create a new bookmark
                    do {
                        let newBookmarkData = try folder.url.bookmarkData(
                            options: [.withSecurityScope],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        var updatedFolder = folder
                        updatedFolder.bookmarkData = newBookmarkData
                        resolvedFolders.append(updatedFolder)
                        foldersNeedingRefresh.append(updatedFolder)
                        
                        print("LibraryManager: Created new bookmark for \(folder.name)")
                    } catch {
                        print("LibraryManager: Failed to create new bookmark for \(folder.name): \(error)")
                        resolvedFolders.append(folder) // Add anyway
                    }
                } else {
                    // No access - add to list anyway
                    resolvedFolders.append(folder)
                }
            } else if !folderAccessible {
                // Folder doesn't exist or isn't accessible
                resolvedFolders.append(folder)
            }
        }
        
        folders = resolvedFolders
        tracks = databaseManager.getAllTracks()
        
        print("LibraryManager: Loaded \(folders.count) folders and \(tracks.count) tracks from database")
        
        // Refresh stale bookmarks in background
        if !foldersNeedingRefresh.isEmpty {
            Task {
                for folder in foldersNeedingRefresh {
                    await refreshBookmarkForFolder(folder)
                }
            }
        }
        
        // Update last scan date
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastScanDate)
        
        // Notify playlist manager to update smart playlists
        if let coordinator = AppCoordinator.shared {
            coordinator.playlistManager.updateSmartPlaylists()
            coordinator.handleLibraryChanged()
        }
        
        // Post notification that library is loaded
        NotificationCenter.default.post(name: NSNotification.Name("LibraryDidLoad"), object: nil)
    }
    
    // MARK: - File Watching
    
    private func startFileWatcher() {
        // Cancel any existing timer
        fileWatcherTimer?.invalidate()
        fileWatcherTimer = nil
        
        // Get current auto-scan interval
        let currentInterval = autoScanInterval
        
        // Only start a timer if auto-scan is not set to "only on launch"
        guard let interval = currentInterval.timeInterval else {
            print("LibraryManager: Auto-scan set to only on launch, no timer started")
            return
        }
        
        print("LibraryManager: Starting auto-scan timer with interval: \(interval) seconds (\(currentInterval.displayName))")
        
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only refresh if we're not currently scanning
            if !self.isScanning && !self.isBackgroundScanning {
                print("LibraryManager: Starting periodic refresh...")
                self.refreshLibrary()
            }
        }
    }
    
    private func handleAutoScanIntervalChange() {
        print("LibraryManager: Auto-scan interval changed to: \(autoScanInterval.displayName)")
        // Restart the file watcher with new interval
        startFileWatcher()
    }
    
    // MARK: - Track Management
    
    func getTracksInFolder(_ folder: Folder) -> [Track] {
        guard let folderId = folder.id else {
            print("LibraryManager: Folder has no ID")
            return []
        }
        
        return databaseManager.getTracksForFolder(folderId)
    }
    
    func getTrackCountForFolder(_ folder: Folder) -> Int {
        guard let folderId = folder.id else { return 0 }
        
        // Check cache first
        if let cachedCount = folderTrackCounts[folderId] {
            return cachedCount
        }
        
        // Get count from database (this should be a fast query)
        let tracks = databaseManager.getTracksForFolder(folderId)
        let count = tracks.count
        
        // Cache it
        folderTrackCounts[folderId] = count
        
        return count
    }
    
    // MARK: - Track Queries

    func getTracksBy(filterType: LibraryFilterType, value: String) -> [Track] {
        if filterType.usesMultiArtistParsing && value != filterType.unknownPlaceholder {
            return databaseManager.getTracksByFilterTypeContaining(filterType, value: value)
        } else {
            return databaseManager.getTracksByFilterType(filterType, value: value)
        }
    }

    func getDistinctValues(for filterType: LibraryFilterType) -> [String] {
        let values = databaseManager.getDistinctValues(for: filterType)
        
        // For composers, normalize empty strings to "Unknown Composer"
        if filterType == .composers {
            return values.map { value in
                value.isEmpty ? filterType.unknownPlaceholder : value
            }.removingDuplicates()
        }
        
        return values
    }

    // MARK: - Library Maintenance
    
    func refreshLibrary() {
        print("LibraryManager: Refreshing library...")
        
        // Set background scanning flag instead of regular scanning
        isBackgroundScanning = true
        
        // Track completion of all folder refreshes
        let group = DispatchGroup()
        var hasErrors = false
        
        // First, ensure all folders have valid bookmarks
        Task {
            for folder in folders {
                // Check and refresh bookmark if needed
                if folder.bookmarkData == nil || !folder.url.startAccessingSecurityScopedResource() {
                    await refreshBookmarkForFolder(folder)
                }
            }
            
            // Now proceed with scanning
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                // For each folder, trigger a refresh in the database
                for folder in self.folders {
                    group.enter()
                    self.databaseManager.refreshFolder(folder) { result in
                        switch result {
                        case .success:
                            print("LibraryManager: Successfully refreshed folder \(folder.name)")
                        case .failure(let error):
                            print("LibraryManager: Failed to refresh folder \(folder.name): \(error)")
                            hasErrors = true
                        }
                        group.leave()
                    }
                }
                
                // When all folders are done refreshing
                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    
                    // Reload the library after all refreshes complete
                    self.loadMusicLibrary()
                    self.isBackgroundScanning = false
                    
                    if hasErrors {
                        print("LibraryManager: Library refresh completed with some errors")
                    } else {
                        print("LibraryManager: Library refresh completed successfully")
                    }
                }
            }
        }
    }
    
    func refreshFolder(_ folder: Folder) {
        // Set background scanning flag
        isBackgroundScanning = true
        
        // First, ensure we have a valid bookmark
        Task {
            // Refresh bookmark if needed
            if folder.bookmarkData == nil || !folder.url.startAccessingSecurityScopedResource() {
                await refreshBookmarkForFolder(folder)
            }
            
            // Then proceed with scanning
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                // Delegate to database manager for refresh
                self.databaseManager.refreshFolder(folder) { result in
                    switch result {
                    case .success:
                        print("LibraryManager: Successfully refreshed folder \(folder.name)")
                        // Reload the library to reflect changes
                        self.loadMusicLibrary()
                        self.isBackgroundScanning = false
                    case .failure(let error):
                        print("LibraryManager: Failed to refresh folder \(folder.name): \(error)")
                        self.isBackgroundScanning = false
                    }
                }
            }
        }
    }
    
    func cleanupMissingFolders() {
        // Check each folder to see if it still exists
        var foldersToRemove: [Folder] = []
        
        for folder in folders {
            if !fileManager.fileExists(atPath: folder.url.path) {
                foldersToRemove.append(folder)
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

    // MARK: - Database Management

    func resetAllData() async throws {
        // Use the existing resetDatabase method
        try databaseManager.resetDatabase()
        
        // Ensure UI updates happen on main thread
        await MainActor.run {
            // Clear in-memory data
            folders.removeAll()
            tracks.removeAll()
            
            // Clear UserDefaults (remove the security bookmarks reference)
            UserDefaults.standard.removeObject(forKey: "LastScanDate")
        }
    }
    
    @objc private func autoScanIntervalDidChange(_ notification: Notification) {
        let newInterval = autoScanInterval
        
        // Store the current interval to compare
        struct LastInterval {
            static var value: AutoScanInterval?
        }
        
        // Only proceed if the interval actually changed
        guard LastInterval.value != newInterval else { return }
        LastInterval.value = newInterval
        
        // Check if the auto-scan interval specifically changed
        DispatchQueue.main.async { [weak self] in
            self?.handleAutoScanIntervalChange()
        }
    }
}
