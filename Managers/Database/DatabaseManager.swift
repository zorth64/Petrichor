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
            try createGenresTable(in: db)
            try createTracksTable(in: db)
            try createPlaylistsTable(in: db)
            try createPlaylistTracksTable(in: db)
            try createTrackArtistsTable(in: db)
            try createTrackGenresTable(in: db)

            // Create all indices
            try createIndices(in: db)
        }
    }

    func checkpoint() {
        do {
            try dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
            }
            print("DatabaseManager: WAL checkpoint completed")
        } catch {
            print("DatabaseManager: WAL checkpoint failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    // Clean up database file
    func resetDatabase() throws {
        try dbQueue.erase()
        try setupDatabase()
    }
}

// MARK: - Local Enums

enum TrackProcessResult {
    case new(Track)
    case update(Track)
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
