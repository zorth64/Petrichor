//
// LibraryManager class extension
//
// This extension contains methods for folder management in the library,
// the methods internally also use DatabaseManager methods to work with database.
//

import Foundation
import AppKit

extension LibraryManager {
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
                    Logger.info("Created bookmark for folder - \(url.lastPathComponent) at \(url.path)")
                } catch {
                    Logger.error("Failed to create security bookmark for \(url.path): \(error)")
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
                            Logger.info("Successfully added \(dbFolders.count) folders to database")
                            self.loadMusicLibrary() // Reload to reflect changes
                        case .failure(let error):
                            Logger.error("Failed to add folders to database: \(error)")
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
                Logger.info("Successfully removed folder from database")
                self?.loadMusicLibrary() // Reload to reflect changes
                
                // Notify PlaylistManager to refresh playlists
                if let coordinator = AppCoordinator.shared {
                    coordinator.playlistManager.refreshPlaylistsAfterFolderRemoval()
                }
                
            case .failure(let error):
                Logger.error("Failed to remove folder from database: \(error)")
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
                        Logger.info("Successfully refreshed folder \(folder.name)")
                        // Reload the library to reflect changes
                        self.loadMusicLibrary()
                        self.isBackgroundScanning = false
                    case .failure(let error):
                        Logger.error("Failed to refresh folder \(folder.name): \(error)")
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
            Logger.info("Cleaning up \(foldersToRemove.count) missing folders")

            for folder in foldersToRemove {
                databaseManager.removeFolder(folder) { _ in }
            }

            // Reload after cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadMusicLibrary()
            }
        }
    }

    func refreshBookmarkForFolder(_ folder: Folder) async {
        // Only refresh if we can access the folder
        guard FileManager.default.fileExists(atPath: folder.url.path) else {
            Logger.warning("Folder no longer exists at \(folder.url.path)")
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

            Logger.info("Successfully refreshed bookmark for \(folder.name)")
        } catch {
            Logger.error("Failed to refresh bookmark for \(folder.name): \(error)")
        }
    }
}
