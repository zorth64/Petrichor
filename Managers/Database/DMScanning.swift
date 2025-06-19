import Foundation
import GRDB

extension DatabaseManager {
    func scanFoldersForTracks(_ folders: [Folder]) async throws {
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "flac"]
        let totalFolders = folders.count
        var processedFolders = 0

        for folder in folders {
            try await scanSingleFolder(folder, supportedExtensions: supportedExtensions)
            processedFolders += 1
        }

        await MainActor.run {
            self.scanStatusMessage = "Scan complete"
        }
    }

    func scanSingleFolder(_ folder: Folder, supportedExtensions: [String]) async throws {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: folder.url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        guard let folderId = folder.id else {
            print("ERROR: Folder has no ID")
            return
        }

        // Get existing tracks for this folder to check for updates
        let existingTracks = getTracksForFolder(folderId)
        let existingTracksByURL = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.url, $0) })

        // Collect all music files first - do this synchronously before async context
        var musicFiles: [URL] = []
        var scannedPaths = Set<URL>()

        // Process enumerator synchronously
        while let fileURL = enumerator.nextObject() as? URL {
            let fileExtension = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(fileExtension) {
                musicFiles.append(fileURL)
                scannedPaths.insert(fileURL)
            }
        }

        // Now we can safely use these in async context
        let totalFiles = musicFiles.count
        let foundPaths = scannedPaths

        // Process in batches
        let batchSize = totalFiles > 1000 ? 100 : 50
        var processedCount = 0

        // Create immutable copy for async context
        let fileBatches = musicFiles.chunked(into: batchSize)

        for (batchIndex, batch) in fileBatches.enumerated() {
            let batchWithFolderId = batch.map { url in (url: url, folderId: folderId) }
            try await processBatch(batchWithFolderId)

            processedCount += batch.count
        }

        // Remove tracks that no longer exist in the folder
        try await dbQueue.write { db in
            for (url, track) in existingTracksByURL {
                if !foundPaths.contains(url) {
                    // File no longer exists, remove from database
                    try track.delete(db)
                    print("Removed track that no longer exists: \(url.lastPathComponent)")
                }
            }
        }

        // Update folder track count
        try await updateFolderTrackCount(folder)
    }

    func updateFolderTrackCount(_ folder: Folder) async throws {
        try await dbQueue.write { db in
            let count = try Track
                .filter(Track.Columns.folderId == folder.id)
                .fetchCount(db)

            var updatedFolder = folder
            updatedFolder.trackCount = count
            updatedFolder.dateUpdated = Date()
            try updatedFolder.update(db)
        }
    }
}
