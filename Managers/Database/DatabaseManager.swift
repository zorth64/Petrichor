//
// DatabaseManager class
//
// This class handles all the Database operations done by the app, note that this file only
// contains core methods, the domain-specific logic is spread across extension files within this
// directory where each file is prefixed with `DM`.
//

import Foundation
import GRDB

class DatabaseManager: ObservableObject {
    // MARK: - Properties
    @Published var isScanning: Bool = false
    @Published var scanStatusMessage: String = ""

    let dbQueue: DatabaseQueue
    private let dbPath: String

    // MARK: - Initialization

    init() throws {
        // Create database in app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("Petrichor", isDirectory: true)

        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: appDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: nil)

        dbPath = appDirectory.appendingPathComponent("petrichor.db").path

        // Configure database before creating the queue
        var config = Configuration()
        config.prepareDatabase { db in
            // Set journal mode to WAL
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            // Enable synchronous mode for better durability
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            // Set a reasonable busy timeout
            try db.execute(sql: "PRAGMA busy_timeout = 5000")
        }

        // Initialize database queue with configuration
        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        // Setup database schema
        try setupDatabase()
    }

    // MARK: - Database Setup

    private func setupDatabase() throws {
        try dbQueue.write { db in
            // Create tables in dependency order
            try createFoldersTable(in: db)
            try createArtistsTable(in: db)
            try createAlbumsTable(in: db)
            try createAlbumArtistsTable(in: db)
            try createGenresTable(in: db)
            try createTracksTable(in: db)
            try createPlaylistsTable(in: db)
            try createPlaylistTracksTable(in: db)
            try createTrackArtistsTable(in: db)
            try createTrackGenresTable(in: db)
            try createPinnedItemsTable(in: db)

            // Create all indices
            try createIndices(in: db)
            
            // Create FTS5 search index
            try createFTSTable(in: db)
            
            // Seed default data
            try seedDefaultPlaylists(in: db)
            try seedDefaultPinnedItems(in: db)
            
            Logger.info("Database schema setup completed")
        }
    }

    func checkpoint() {
        do {
            try dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
            }
            Logger.info("WAL checkpoint completed")
        } catch {
            Logger.error("WAL checkpoint failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    // Clean up database file
    func resetDatabase() throws {
        try dbQueue.erase()
        try setupDatabase()
        Logger.info("Database reset completed")
    }
}

// MARK: - Local Enums

enum TrackProcessResult {
    case new(Track, TrackMetadata)
    case update(Track, TrackMetadata)
    case skipped
}

enum DatabaseError: Error {
    case invalidTrackId
    case updateFailed
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return self.filter { element in
            guard !seen.contains(element) else { return false }
            seen.insert(element)
            return true
        }
    }
}
