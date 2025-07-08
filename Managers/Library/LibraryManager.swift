//
// LibraryManager class
//
// This class handles all the Library operations done by the app, note that this file only
// contains core methods, the domain-specific logic is spread across extension files within this
// directory where each file is prefixed with `LM`.
//

import Foundation
import AppKit

class LibraryManager: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var folders: [Folder] = []
    @Published var isScanning: Bool = false
    @Published var scanStatusMessage: String = ""
    @Published var isBackgroundScanning: Bool = false
    @Published var globalSearchText: String = "" {
        didSet {
            updateSearchResults()
        }
    }
    @Published var searchResults: [Track] = []
    @Published var pinnedItems: [PinnedItem] = []
    @Published internal var cachedArtistEntities: [ArtistEntity] = []
    @Published internal var cachedAlbumEntities: [AlbumEntity] = []

    // MARK: - Entity Properties
    var artistEntities: [ArtistEntity] {
        if !entitiesLoaded {
            loadEntities()
        }
        return cachedArtistEntities
    }

    var albumEntities: [AlbumEntity] {
        if !entitiesLoaded {
            loadEntities()
        }
        return cachedAlbumEntities
    }

    // MARK: - Private/Internal Properties
    private var fileWatcherTimer: Timer?
    internal var entitiesLoaded = false
    internal let userDefaults = UserDefaults.standard
    internal let fileManager = FileManager.default
    internal var folderTrackCounts: [Int64: Int] = [:]

    // Database manager
    let databaseManager: DatabaseManager

    // Keys for UserDefaults
    internal enum UserDefaultsKeys {
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
            Logger.critical("Failed to initialize database: \(error)")
            fatalError("Failed to initialize database: \(error)")
        }

        // Observe database manager scanning state
        databaseManager.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        databaseManager.$scanStatusMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$scanStatusMessage)

        loadMusicLibrary()
        
        Task {
            await loadPinnedItems()
        }
        
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

    // MARK: - File Watching

    private func startFileWatcher() {
        // Cancel any existing timer
        fileWatcherTimer?.invalidate()
        fileWatcherTimer = nil

        // Get current auto-scan interval
        let currentInterval = autoScanInterval

        // Only start a timer if auto-scan is not set to "only on launch"
        guard let interval = currentInterval.timeInterval else {
            Logger.info("Auto-scan set to only on launch, no timer started")
            return
        }

        Logger.info("LibraryManager: Starting auto-scan timer with interval: \(interval) seconds (\(currentInterval.displayName))")

        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Only refresh if we're not currently scanning
            if !self.isScanning && !self.isBackgroundScanning {
                Logger.info("Starting periodic refresh...")
                self.refreshLibrary()
            }
        }
    }

    private func handleAutoScanIntervalChange() {
        Logger.info("Auto-scan interval changed to: \(autoScanInterval.displayName)")
        // Restart the file watcher with new interval
        startFileWatcher()
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

    @objc
    private func autoScanIntervalDidChange(_ notification: Notification) {
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
