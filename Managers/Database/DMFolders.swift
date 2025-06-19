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
                }
            }
        }
    }
    
    func addFoldersAsync(_ urls: [URL], bookmarkDataMap: [URL: Data]) async throws -> [Folder] {
        await MainActor.run {
            self.isScanning = true
            self.scanStatusMessage = "Adding folders..."
        }
        
        var addedFolders: [Folder] = []
        
        try await dbQueue.write { db in
            for url in urls {
                let bookmarkData = bookmarkDataMap[url]
                var folder = Folder(url: url, bookmarkData: bookmarkData)
                
                // Check if folder already exists
                if let existing = try Folder
                    .filter(Folder.Columns.path == url.path)
                    .fetchOne(db) {
                    // Update bookmark data if folder exists
                    var updatedFolder = existing
                    updatedFolder.bookmarkData = bookmarkData
                    try updatedFolder.update(db)
                    addedFolders.append(updatedFolder)
                    print("Folder already exists: \(existing.name) with ID: \(existing.id ?? -1), updated bookmark")
                } else {
                    // Insert new folder
                    try folder.insert(db)
                    
                    // Fetch the inserted folder to get the generated ID
                    if let insertedFolder = try Folder
                        .filter(Folder.Columns.path == url.path)
                        .fetchOne(db) {
                        addedFolders.append(insertedFolder)
                        print("Added new folder: \(insertedFolder.name) with ID: \(insertedFolder.id ?? -1)")
                    }
                }
            }
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
            print("Failed to fetch folders: \(error)")
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
                print("DatabaseManager: Starting refresh for folder \(folder.name) with \(trackCountBefore) tracks")
                
                // Scan the folder - this will now always check for metadata updates
                try await scanSingleFolder(folder, supportedExtensions: ["mp3", "m4a", "wav", "aac", "aiff", "flac"])
                
                // Log the result
                let trackCountAfter = getTracksForFolder(folder.id ?? -1).count
                print("DatabaseManager: Completed refresh for folder \(folder.name) with \(trackCountAfter) tracks (was \(trackCountBefore))")
                
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
                }
            }
        }
    }
    
    func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await dbQueue.write { db in
                    try folder.delete(db)
                }
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateFolderBookmark(_ folderId: Int64, bookmarkData: Data) async throws {
        try await dbQueue.write { db in
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
