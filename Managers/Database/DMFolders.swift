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

        let addedFolders = try await dbQueue.write { db -> [Folder] in
            var folders: [Folder] = []
            
            for url in urls {
                let bookmarkData = bookmarkDataMap[url]
                let folder = Folder(url: url, bookmarkData: bookmarkData)

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

                // Scan the folder - this will now always check for metadata updates
                try await scanSingleFolder(folder, supportedExtensions: AudioFormat.supportedExtensions)

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

    func getTracksInFolder(_ folder: Folder) -> [Track] {
        guard let folderId = folder.id else { return [] }
        return getTracksForFolder(folderId)
    }
}
