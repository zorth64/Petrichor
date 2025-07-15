//
// DatabaseManager class extension
//
// This extension contains all the folder management methods which allow mapping folders in the app
// and create corresponding records in `folders` table in the db, and scanning folders for tracks.
//

import Foundation
import GRDB

extension DatabaseManager {
    func addFolders(_ urls: [URL], bookmarkDataMap: [URL: Data], completion: @escaping (Result<[Folder], Error>) -> Void) {
        Task {
            do {
                let folders = try await addFoldersAsync(urls, bookmarkDataMap: bookmarkDataMap)
                await MainActor.run {
                    completion(.success(folders))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                    Logger.error("Failed to add folders: \(error)")
                }
            }
        }
    }

    func addFoldersAsync(_ urls: [URL], bookmarkDataMap: [URL: Data]) async throws -> [Folder] {
        await MainActor.run {
            self.isScanning = true
            self.scanStatusMessage = "Adding folders..."
        }

        // Calculate hashes for all folders
        var mutableHashMap: [URL: String] = [:]
        for url in urls {
            if let hash = await FolderUtils.getHashAsync(for: url) {
                mutableHashMap[url] = hash
            }
        }
        let hashMap = mutableHashMap

        let addedFolders = try await dbQueue.write { db -> [Folder] in
            var folders: [Folder] = []
            
            for url in urls {
                let bookmarkData = bookmarkDataMap[url]
                var folder = Folder(url: url, bookmarkData: bookmarkData)
                
                // Get the file system modification date
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fsModDate = attributes[.modificationDate] as? Date {
                    folder.dateUpdated = fsModDate
                }
                
                // Set the calculated hash
                folder.shasumHash = hashMap[url]

                // Check if folder already exists
                if let existing = try Folder
                    .filter(Folder.Columns.path == url.path)
                    .fetchOne(db) {
                    // Update bookmark data if folder exists
                    var updatedFolder = existing
                    updatedFolder.bookmarkData = bookmarkData
                    try updatedFolder.update(db)
                    folders.append(updatedFolder)
                    Logger.info("Folder already exists: \(existing.name) with ID: \(existing.id ?? -1), updated bookmark")
                } else {
                    // Insert new folder
                    try folder.insert(db)

                    // Fetch the inserted folder to get the generated ID
                    if let insertedFolder = try Folder
                        .filter(Folder.Columns.path == url.path)
                        .fetchOne(db) {
                        folders.append(insertedFolder)
                        Logger.info("Added new folder: \(insertedFolder.name) with ID: \(insertedFolder.id ?? -1)")
                    }
                }
            }
            
            return folders
        }

        // Now scan the folders for tracks
        if !addedFolders.isEmpty {
            try await scanFoldersForTracks(addedFolders)
        }

        await MainActor.run {
            self.isScanning = false
        }

        return addedFolders
    }

    func getAllFolders() -> [Folder] {
        do {
            return try dbQueue.read { db in
                try Folder
                    .order(Folder.Columns.name)
                    .fetchAll(db)
            }
        } catch {
            Logger.error("Failed to fetch folders: \(error)")
            return []
        }
    }

    func refreshFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                await MainActor.run {
                    self.isScanning = true
                    self.scanStatusMessage = "Refreshing \(folder.name)..."
                }

                // Log the current state
                let trackCountBefore = getTracksForFolder(folder.id ?? -1).count
                Logger.info("Starting refresh for folder \(folder.name) with \(trackCountBefore) tracks")

                // Scan the folder - this will check for metadata updates
                try await scanSingleFolder(folder, supportedExtensions: AudioFormat.supportedExtensions)

                // Update folder's metadata
                if let folderId = folder.id {
                    try await updateFolderMetadata(folderId)
                }

                // Log the result
                let trackCountAfter = getTracksForFolder(folder.id ?? -1).count
                Logger.info("Completed refresh for folder \(folder.name) with \(trackCountAfter) tracks (was \(trackCountBefore))")

                await MainActor.run {
                    self.isScanning = false
                    self.scanStatusMessage = ""
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    self.isScanning = false
                    self.scanStatusMessage = ""
                    completion(.failure(error))
                    Logger.error("Failed to refresh folder \(folder.name): \(error)")
                }
            }
        }
    }

    func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await dbQueue.write { db in
                    // Delete the folder (cascades to tracks and junction tables)
                    try folder.delete(db)
                    
                    // Get all artist IDs that still have tracks
                    let artistsWithTracks = try TrackArtist
                        .select(TrackArtist.Columns.artistId, as: Int64.self)
                        .distinct()
                        .fetchSet(db)
                    
                    // Delete artists that are NOT in the set of artists with tracks
                    try Artist
                        .filter(!artistsWithTracks.contains(Artist.Columns.id))
                        .deleteAll(db)
                    
                    // Get all album IDs that still have tracks
                    let albumsWithTracks = try Track
                        .select(Track.Columns.albumId, as: Int64?.self)
                        .filter(Track.Columns.albumId != nil)
                        .distinct()
                        .fetchSet(db)
                        .compactMap { $0 }
                    
                    // Delete albums that are NOT in the set of albums with tracks
                    try Album
                        .filter(!albumsWithTracks.contains(Album.Columns.id))
                        .deleteAll(db)
                    
                    // Get all genre IDs that still have tracks
                    let genresWithTracks = try TrackGenre
                        .select(TrackGenre.Columns.genreId, as: Int64.self)
                        .distinct()
                        .fetchSet(db)
                    
                    // Delete genres that are NOT in the set of genres with tracks
                    try Genre
                        .filter(!genresWithTracks.contains(Genre.Columns.id))
                        .deleteAll(db)
                    
                    Logger.info("Removed folder '\(folder.name)' and cleaned up orphaned data")
                }
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                    Logger.error("Failed to remove folder '\(folder.name)': \(error)")
                }
            }
        }
    }

    func updateFolderBookmark(_ folderId: Int64, bookmarkData: Data) async throws {
        _ = try await dbQueue.write { db in
            try Folder
                .filter(Folder.Columns.id == folderId)
                .updateAll(db, Folder.Columns.bookmarkData.set(to: bookmarkData))
        }
    }
    
    func updateFolderMetadata(_ folderId: Int64) async throws {
        // First, get the folder and calculate hash outside the database transaction
        let folderData = try await dbQueue.read { db in
            try Folder.fetchOne(db, key: folderId)
        }
        
        guard let folder = folderData else { return }
        
        let hash = await FolderUtils.getHashAsync(for: folder.url)
        
        try await dbQueue.write { db in
            guard var folder = try Folder.fetchOne(db, key: folderId) else { return }
            
            // Get and store the file system's modification date
            if let attributes = try? FileManager.default.attributesOfItem(atPath: folder.url.path),
               let fsModDate = attributes[.modificationDate] as? Date {
                folder.dateUpdated = fsModDate
            } else {
                // Fallback to current date if we can't get FS date
                folder.dateUpdated = Date()
            }
            
            // Store the calculated hash
            if let hash = hash {
                folder.shasumHash = hash
                Logger.info("Updated hash for folder \(folder.name)")
            } else {
                Logger.warning("Failed to calculate hash for folder \(folder.name)")
            }
            
            // Update track count
            let trackCount = try Track
                .filter(Track.Columns.folderId == folderId)
                .filter(Track.Columns.isDuplicate == false)
                .fetchCount(db)
            folder.trackCount = trackCount
            
            try folder.update(db)
        }
    }

    func getTracksInFolder(_ folder: Folder) -> [Track] {
        guard let folderId = folder.id else { return [] }
        return getTracksForFolder(folderId)
    }
    
    func scanFoldersForTracks(_ folders: [Folder]) async throws {
        let supportedExtensions = AudioFormat.supportedExtensions
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
            Logger.error("Folder has no ID")
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

        for batch in fileBatches {
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
                    Logger.info("Removed track that no longer exists: \(url.lastPathComponent)")
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
