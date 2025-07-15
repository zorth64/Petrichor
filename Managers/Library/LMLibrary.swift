//
// LibraryManager class extension
//
// This extension contains methods for loading music files in the library,
// the methods internally also use DatabaseManager methods to work with database.
//

import Foundation

extension LibraryManager {
    func loadMusicLibrary() {
        Logger.info("Loading music library from database...")

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
                    let resolvedURL = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )

                    // Start accessing the security scoped resource
                    if resolvedURL.startAccessingSecurityScopedResource() {
                        folderAccessible = true
                        resolvedFolders.append(folder)
                        Logger.info("Successfully resolved bookmark for \(folder.name)")

                        if isStale {
                            Logger.info("Bookmark for \(folder.name) is stale, queuing for refresh")
                            foldersNeedingRefresh.append(folder)
                        }
                    } else {
                        Logger.error("Failed to start accessing security scoped resource for \(folder.name)")
                    }
                } catch {
                    Logger.error("Failed to resolve bookmark for \(folder.name): \(error)")
                }
            } else {
                Logger.error("No bookmark data for \(folder.name)")
            }

            // If bookmark resolution failed but folder exists, try to create new bookmark
            if !folderAccessible && FileManager.default.fileExists(atPath: folder.url.path) {
                Logger.info("Attempting to create new bookmark for accessible folder \(folder.name)")

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

                        Logger.info("Created new bookmark for \(folder.name)")
                    } catch {
                        Logger.error("Failed to create new bookmark for \(folder.name): \(error)")
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
        updateSearchResults()

        Logger.info("Loaded \(folders.count) folders and \(tracks.count) tracks from database")

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

        refreshEntities()
        // Post notification that library is loaded
        NotificationCenter.default.post(name: NSNotification.Name("LibraryDidLoad"), object: nil)
    }

    func refreshEntities() {
        entitiesLoaded = false
        loadEntities()
    }

    func refreshLibrary() {
        Logger.info("Refreshing library...")
        isBackgroundScanning = true
        
        actor ErrorTracker {
            private var hasErrors = false
            func setError() { hasErrors = true }
            func getHasErrors() -> Bool { hasErrors }
        }
        
        let errorTracker = ErrorTracker()
        let group = DispatchGroup()

        Task {
            // First check bookmarks
            for folder in folders {
                if folder.bookmarkData == nil || !folder.url.startAccessingSecurityScopedResource() {
                    await refreshBookmarkForFolder(folder)
                }
            }

            // Filter folders that need refreshing based on modification date
            let foldersToRefresh = await determineFoldersToRefresh()

            // Only proceed if there are folders to refresh
            if foldersToRefresh.isEmpty {
                await MainActor.run { [weak self] in
                    self?.isBackgroundScanning = false
                    Logger.info("No folders need refreshing")
                }
                return
            }

            Logger.info("Will refresh \(foldersToRefresh.count) of \(folders.count) folders")

            let foldersToProcess = foldersToRefresh

            // Now proceed with scanning only modified folders
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // For each modified folder, trigger a refresh
                for folder in foldersToProcess {
                    group.enter()
                    self.databaseManager.refreshFolder(folder) { result in
                        Task {
                            switch result {
                            case .success:
                                Logger.info("Successfully refreshed folder \(folder.name)")
                            case .failure(let error):
                                Logger.error("Failed to refresh folder \(folder.name): \(error)")
                                await errorTracker.setError()
                            }
                            group.leave()
                        }
                    }
                }

                // When all folders are done refreshing
                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }

                    Task {
                        // Only detect duplicates if we actually refreshed any folders
                        if !foldersToProcess.isEmpty {
                            Logger.info("Detecting and marking duplicate tracks")
                            await self.databaseManager.detectAndMarkDuplicates()
                        }
                        
                        // Reload the library with all changes
                        self.loadMusicLibrary()
                        self.updateSearchResults()
                        
                        // Clear scanning flag
                        self.isBackgroundScanning = false

                        let hasErrors = await errorTracker.getHasErrors()
                        if hasErrors {
                            Logger.warning("Library refresh completed with some errors")
                        } else {
                            Logger.info("Library refresh completed successfully")
                        }
                    }
                }
            }
        }
    }

    private func determineFoldersToRefresh() async -> [Folder] {
        var foldersToRefresh: [Folder] = []
        
        Logger.info("Starting folder refresh check")
        
        for folder in folders {
            // Step 1: Check modification timestamp
            let timestampChanged = FolderUtils.modificationTimestampChanged(
                for: folder.url,
                comparedTo: folder.dateUpdated
            )
            
            if timestampChanged {
                Logger.info("Folder \(folder.name): Timestamp changed, marking for refresh")
                foldersToRefresh.append(folder)
                continue
            }
            
            // Step 2: If timestamp hasn't changed, check content hash
            Logger.info("Folder \(folder.name): Timestamp unchanged, checking content hash...")
            
            // If no hash stored yet, we need to scan
            guard let storedHash = folder.shasumHash else {
                Logger.info("Folder \(folder.name): No hash stored, marking for refresh")
                foldersToRefresh.append(folder)
                continue
            }
            
            // Calculate current hash
            if let currentHash = await FolderUtils.getHashAsync(for: folder.url) {
                if currentHash != storedHash {
                    Logger.info("Folder \(folder.name): Content changed (hash mismatch), marking for refresh")
                    foldersToRefresh.append(folder)
                } else {
                    Logger.info("Folder \(folder.name): No changes detected, skipping")
                }
            } else {
                // If hash calculation fails, scan to be safe
                Logger.warning("Folder \(folder.name): Hash calculation failed, marking for refresh")
                foldersToRefresh.append(folder)
            }
        }
        
        Logger.info("Refresh check complete: \(foldersToRefresh.count)/\(folders.count) folders need refresh")
        return foldersToRefresh
    }

    internal func loadEntities() {
        guard !entitiesLoaded else { return }
        entitiesLoaded = true

        cachedArtistEntities = databaseManager.getArtistEntities()
        cachedAlbumEntities = databaseManager.getAlbumEntities()
    }
}
