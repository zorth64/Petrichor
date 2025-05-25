import Foundation
import SQLite3

// MARK: - SQLite Constants
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

class DatabaseManager: ObservableObject {
    // MARK: - Properties
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.petrichor.database")
    private let dbPath: String
    
    // MARK: - Published Properties for UI Updates
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage: String = ""
    
    // MARK: - Table Names
    private let foldersTable = "folders"
    private let tracksTable = "tracks"
    
    // MARK: - Initialization
    init() {
        // Create database in app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("Petrichor", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
        
        dbPath = appDirectory.appendingPathComponent("petrichor.db").path
        
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database at \(dbPath)")
            return
        }
        
        // Enable foreign keys
        let enableForeignKeys = "PRAGMA foreign_keys = ON;"
        if sqlite3_exec(db, enableForeignKeys, nil, nil, nil) != SQLITE_OK {
            print("Failed to enable foreign keys")
        }
        
        // Set journal mode to WAL for better concurrency
        let walMode = "PRAGMA journal_mode = WAL;"
        if sqlite3_exec(db, walMode, nil, nil, nil) != SQLITE_OK {
            print("Failed to set WAL mode")
        }
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTables() {
        // Create folders table
        let createFoldersTable = """
            CREATE TABLE IF NOT EXISTS \(foldersTable) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                path TEXT NOT NULL UNIQUE,
                track_count INTEGER DEFAULT 0,
                date_added REAL NOT NULL,
                date_updated REAL NOT NULL
            );
        """
        
        // Create tracks table
        let createTracksTable = """
            CREATE TABLE IF NOT EXISTS \(tracksTable) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                folder_id INTEGER NOT NULL,
                path TEXT NOT NULL UNIQUE,
                filename TEXT NOT NULL,
                title TEXT,
                artist TEXT,
                album TEXT,
                genre TEXT,
                year TEXT,
                duration REAL,
                format TEXT,
                file_size INTEGER,
                date_added REAL NOT NULL,
                date_modified REAL,
                artwork_data BLOB,
                FOREIGN KEY (folder_id) REFERENCES \(foldersTable)(id) ON DELETE CASCADE
            );
        """
        
        // Create indices for better performance
        let createIndices = [
            "CREATE INDEX IF NOT EXISTS idx_tracks_folder_id ON \(tracksTable)(folder_id);",
            "CREATE INDEX IF NOT EXISTS idx_tracks_artist ON \(tracksTable)(artist);",
            "CREATE INDEX IF NOT EXISTS idx_tracks_album ON \(tracksTable)(album);",
            "CREATE INDEX IF NOT EXISTS idx_tracks_genre ON \(tracksTable)(genre);",
            "CREATE INDEX IF NOT EXISTS idx_tracks_year ON \(tracksTable)(year);",
            "CREATE INDEX IF NOT EXISTS idx_folders_path ON \(foldersTable)(path);"
        ]
        
        // Execute table creation on the serial queue
        dbQueue.sync {
            if sqlite3_exec(self.db, createFoldersTable, nil, nil, nil) != SQLITE_OK {
                print("Failed to create folders table")
            }
            
            if sqlite3_exec(self.db, createTracksTable, nil, nil, nil) != SQLITE_OK {
                print("Failed to create tracks table")
            }
            
            // Create indices
            for index in createIndices {
                if sqlite3_exec(self.db, index, nil, nil, nil) != SQLITE_OK {
                    print("Failed to create index: \(index)")
                }
            }
        }
    }
    
    // MARK: - Folder Management
    
    func addFolders(_ urls: [URL], completion: @escaping (Result<[DatabaseFolder], Error>) -> Void) {
        // Move all work to background queue immediately
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isScanning = true
                self.scanProgress = 0.0
                self.scanStatusMessage = "Adding folders..."
            }
            
            var addedFolders: [DatabaseFolder] = []
            let insertSQL = """
                    INSERT OR IGNORE INTO \(self.foldersTable) 
                    (name, path, date_added, date_updated) 
                    VALUES (?, ?, ?, ?);
                """
            
            // Begin transaction for better performance
            sqlite3_exec(self.db, "BEGIN TRANSACTION", nil, nil, nil)
            
            for url in urls {
                var stmt: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                    let name = url.lastPathComponent
                    let path = url.path
                    let now = Date().timeIntervalSince1970
                    
                    sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 2, path, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_double(stmt, 3, now)
                    sqlite3_bind_double(stmt, 4, now)
                    
                    if sqlite3_step(stmt) == SQLITE_DONE {
                        let folderId = sqlite3_last_insert_rowid(self.db)
                        let folder = DatabaseFolder(
                            id: Int(folderId),
                            name: name,
                            path: path,
                            trackCount: 0,
                            dateAdded: Date(timeIntervalSince1970: now),
                            dateUpdated: Date(timeIntervalSince1970: now)
                        )
                        addedFolders.append(folder)
                    }
                }
                sqlite3_finalize(stmt)
            }
            
            // Commit transaction
            sqlite3_exec(self.db, "COMMIT", nil, nil, nil)
            
            // Now scan the folders for tracks in background
            self.scanFoldersForTracks(addedFolders) { result in
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion(.success(addedFolders))
                }
            }
        }
    }
    
    func getAllFolders() -> [DatabaseFolder] {
        var folders: [DatabaseFolder] = []
        let query = "SELECT id, name, path, track_count, date_added, date_updated FROM \(foldersTable) ORDER BY name;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(stmt, 0))
                    let name = String(cString: sqlite3_column_text(stmt, 1))
                    let path = String(cString: sqlite3_column_text(stmt, 2))
                    let trackCount = Int(sqlite3_column_int(stmt, 3))
                    let dateAdded = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                    let dateUpdated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
                    
                    let folder = DatabaseFolder(
                        id: id,
                        name: name,
                        path: path,
                        trackCount: trackCount,
                        dateAdded: dateAdded,
                        dateUpdated: dateUpdated
                    )
                    folders.append(folder)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return folders
    }
    
    func removeFolder(_ folder: DatabaseFolder, completion: @escaping (Result<Void, Error>) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            let deleteSQL = "DELETE FROM \(self.foldersTable) WHERE id = ?;"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(folder.id))
                
                if sqlite3_step(stmt) == SQLITE_DONE {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    let error = NSError(domain: "DatabaseManager", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to delete folder"])
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Track Management
    
    private func scanFoldersForTracks(_ folders: [DatabaseFolder], completion: @escaping (Result<Void, Error>) -> Void) {
        // Ensure this runs on background queue
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            let supportedExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "flac"]
            let totalFolders = folders.count
            var processedFolders = 0
            
            for folder in folders {
                autoreleasepool {
                    DispatchQueue.main.async {
                        self.scanStatusMessage = "Scanning \(folder.name)..."
                        self.scanProgress = Double(processedFolders) / Double(totalFolders)
                    }
                    
                    self.scanSingleFolder(folder, supportedExtensions: supportedExtensions)
                    processedFolders += 1
                }
            }
            
            DispatchQueue.main.async {
                self.scanProgress = 1.0
                self.scanStatusMessage = "Scan complete"
                completion(.success(()))
            }
        }
    }
    
    private func scanSingleFolder(_ folder: DatabaseFolder, supportedExtensions: [String]) {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folder.path)
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }
        
        // Collect all music files first
        var musicFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            let fileExtension = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(fileExtension) {
                musicFiles.append(fileURL)
            }
        }
        
        // Update progress
        DispatchQueue.main.async {
            self.scanStatusMessage = "Found \(musicFiles.count) tracks in \(folder.name)"
        }
        
        // Process in batches for better performance
        let batchSize = 50
        var processedCount = 0
        
        for batch in musicFiles.chunked(into: batchSize) {
            autoreleasepool {
                // Begin transaction for batch
                sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
                
                let insertSQL = """
                    INSERT OR IGNORE INTO \(tracksTable) 
                    (folder_id, path, filename, title, artist, album, genre, year, 
                     duration, format, file_size, date_added, artwork_data)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
                
                for fileURL in batch {
                    autoreleasepool {
                        var stmt: OpaquePointer?
                        
                        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                            // Extract metadata using optimized extractor
                            let metadata = MetadataExtractor.extractMetadataSync(from: fileURL)
                            
                            // Bind values
                            sqlite3_bind_int(stmt, 1, Int32(folder.id))
                            sqlite3_bind_text(stmt, 2, fileURL.path, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 3, fileURL.lastPathComponent, -1, SQLITE_TRANSIENT)
                            
                            // Use metadata or defaults
                            let title = metadata.title ?? fileURL.deletingPathExtension().lastPathComponent
                            let artist = metadata.artist ?? "Unknown Artist"
                            let album = metadata.album ?? "Unknown Album"
                            let genre = metadata.genre ?? "Unknown Genre"
                            let year = metadata.year ?? ""
                            
                            sqlite3_bind_text(stmt, 4, title, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 5, artist, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 6, album, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 7, genre, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_text(stmt, 8, year, -1, SQLITE_TRANSIENT)
                            sqlite3_bind_double(stmt, 9, metadata.duration)
                            sqlite3_bind_text(stmt, 10, fileURL.pathExtension.lowercased(), -1, SQLITE_TRANSIENT)
                            
                            // Get file size
                            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                               let fileSize = attributes[.size] as? Int64 {
                                sqlite3_bind_int64(stmt, 11, fileSize)
                            } else {
                                sqlite3_bind_null(stmt, 11)
                            }
                            
                            sqlite3_bind_double(stmt, 12, Date().timeIntervalSince1970)
                            
                            // Bind artwork data if available
                            if let artworkData = metadata.artworkData {
                                artworkData.withUnsafeBytes { bytes in
                                    sqlite3_bind_blob(stmt, 13, bytes.baseAddress, Int32(artworkData.count), SQLITE_TRANSIENT)
                                }
                            } else {
                                sqlite3_bind_null(stmt, 13)
                            }
                            
                            if sqlite3_step(stmt) == SQLITE_DONE {
                                processedCount += 1
                            }
                        }
                        sqlite3_finalize(stmt)
                    }
                }
                
                // Commit batch transaction
                sqlite3_exec(db, "COMMIT", nil, nil, nil)
                
                // Update progress
                let progress = Double(processedCount) / Double(musicFiles.count)
                DispatchQueue.main.async {
                    self.scanStatusMessage = "Processing \(folder.name): \(processedCount)/\(musicFiles.count) tracks"
                }
            }
        }
        
        // Update folder track count
        updateFolderTrackCount(folder.id, trackCount: processedCount)
    }
    
    private func updateFolderTrackCount(_ folderId: Int, trackCount: Int) {
        let updateSQL = """
            UPDATE \(foldersTable) 
            SET track_count = ?, date_updated = ? 
            WHERE id = ?;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(trackCount))
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            sqlite3_bind_int(stmt, 3, Int32(folderId))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    // MARK: - Track Queries
    
    func getAllTracks() -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            ORDER BY t.artist, t.album, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // Get all tracks WITHOUT artwork data for better performance
    func getAllTracksLightweight() -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, NULL as artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            ORDER BY t.artist, t.album, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    func getTracksForFolder(_ folderId: Int) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.folder_id = ?
            ORDER BY t.filename;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(folderId))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // Get tracks for folder WITHOUT artwork
    func getTracksForFolderLightweight(_ folderId: Int) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, NULL as artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.folder_id = ?
            ORDER BY t.filename;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(folderId))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    func getTracksByArtist(_ artist: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.artist LIKE ?
            ORDER BY t.album, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, "%\(artist)%", -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // Get tracks by artist WITHOUT artwork
    func getTracksByArtistLightweight(_ artist: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, NULL as artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.artist LIKE ?
            ORDER BY t.album, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, "%\(artist)%", -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    func getTracksByAlbum(_ album: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.album = ?
            ORDER BY t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, album, -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // Get tracks by album WITHOUT artwork
    func getTracksByAlbumLightweight(_ album: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, NULL as artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.album = ?
            ORDER BY t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, album, -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    func getTracksByGenre(_ genre: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.genre = ?
            ORDER BY t.artist, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, genre, -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    func getTracksByYear(_ year: String) -> [DatabaseTrack] {
        var tracks: [DatabaseTrack] = []
        let query = """
            SELECT t.id, t.folder_id, t.path, t.filename, t.title, t.artist, 
                   t.album, t.genre, t.year, t.duration, t.format, t.file_size, 
                   t.date_added, t.artwork_data, f.name as folder_name
            FROM \(tracksTable) t
            JOIN \(foldersTable) f ON t.folder_id = f.id
            WHERE t.year = ?
            ORDER BY t.artist, t.album, t.title;
        """
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, year, -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let track = extractTrackFromStatement(stmt)
                    tracks.append(track)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tracks
    }
    
    // MARK: - Aggregate Queries
    
    func getAllArtists() -> [String] {
        var artists: [String] = []
        let query = "SELECT DISTINCT artist FROM \(tracksTable) WHERE artist IS NOT NULL ORDER BY artist;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let artist = sqlite3_column_text(stmt, 0) {
                        artists.append(String(cString: artist))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return artists
    }
    
    func getAllAlbums() -> [String] {
        var albums: [String] = []
        let query = "SELECT DISTINCT album FROM \(tracksTable) WHERE album IS NOT NULL ORDER BY album;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let album = sqlite3_column_text(stmt, 0) {
                        albums.append(String(cString: album))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return albums
    }
    
    func getAllGenres() -> [String] {
        var genres: [String] = []
        let query = "SELECT DISTINCT genre FROM \(tracksTable) WHERE genre IS NOT NULL ORDER BY genre;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let genre = sqlite3_column_text(stmt, 0) {
                        genres.append(String(cString: genre))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return genres
    }
    
    func getAllYears() -> [String] {
        var years: [String] = []
        let query = "SELECT DISTINCT year FROM \(tracksTable) WHERE year IS NOT NULL ORDER BY year DESC;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let year = sqlite3_column_text(stmt, 0) {
                        years.append(String(cString: year))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return years
    }
    
    // Get artwork for a specific track when needed
    func getArtworkForTrack(_ trackId: Int) -> Data? {
        var artworkData: Data? = nil
        let query = "SELECT artwork_data FROM \(tracksTable) WHERE id = ?;"
        
        dbQueue.sync {
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(trackId))
                
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let artworkBlob = sqlite3_column_blob(stmt, 0) {
                        let artworkSize = sqlite3_column_bytes(stmt, 0)
                        artworkData = Data(bytes: artworkBlob, count: Int(artworkSize))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return artworkData
    }
    
    // MARK: - Helper Methods
    
    private func extractTrackFromStatement(_ stmt: OpaquePointer?) -> DatabaseTrack {
        let id = Int(sqlite3_column_int(stmt, 0))
        let folderId = Int(sqlite3_column_int(stmt, 1))
        let path = String(cString: sqlite3_column_text(stmt, 2))
        let filename = String(cString: sqlite3_column_text(stmt, 3))
        
        let title = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : filename
        let artist = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : "Unknown Artist"
        let album = sqlite3_column_text(stmt, 6) != nil ? String(cString: sqlite3_column_text(stmt, 6)) : "Unknown Album"
        let genre = sqlite3_column_text(stmt, 7) != nil ? String(cString: sqlite3_column_text(stmt, 7)) : "Unknown Genre"
        let year = sqlite3_column_text(stmt, 8) != nil ? String(cString: sqlite3_column_text(stmt, 8)) : ""
        
        let duration = sqlite3_column_double(stmt, 9)
        let format = String(cString: sqlite3_column_text(stmt, 10))
        let fileSize = sqlite3_column_int64(stmt, 11)
        let dateAdded = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
        
        var artworkData: Data? = nil
        if let artworkBlob = sqlite3_column_blob(stmt, 13) {
            let artworkSize = sqlite3_column_bytes(stmt, 13)
            artworkData = Data(bytes: artworkBlob, count: Int(artworkSize))
        }
        
        let folderName = String(cString: sqlite3_column_text(stmt, 14))
        
        return DatabaseTrack(
            id: id,
            folderId: folderId,
            folderName: folderName,
            path: path,
            filename: filename,
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            year: year,
            duration: duration,
            format: format,
            fileSize: fileSize,
            dateAdded: dateAdded,
            artworkData: artworkData
        )
    }
    
    // MARK: - Refresh Methods
    
    func refreshFolder(_ folder: DatabaseFolder, completion: @escaping (Result<Void, Error>) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isScanning = true
                self.scanStatusMessage = "Refreshing \(folder.name)..."
            }
            
            // Delete existing tracks for this folder
            let deleteSQL = "DELETE FROM \(self.tracksTable) WHERE folder_id = ?;"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(folder.id))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            // Rescan the folder
            self.scanSingleFolder(folder, supportedExtensions: ["mp3", "m4a", "wav", "aac", "aiff", "flac"])
            
            DispatchQueue.main.async {
                self.isScanning = false
                self.scanStatusMessage = ""
                completion(.success(()))
            }
        }
    }
}

// MARK: - Database Models

struct DatabaseFolder: Identifiable, Equatable {
    let id: Int
    let name: String
    let path: String
    let trackCount: Int
    let dateAdded: Date
    let dateUpdated: Date
}

struct DatabaseTrack: Identifiable, Equatable {
    let id: Int
    let folderId: Int
    let folderName: String
    let path: String
    let filename: String
    let title: String
    let artist: String
    let album: String
    let genre: String
    let year: String
    let duration: Double
    let format: String
    let fileSize: Int64
    let dateAdded: Date
    let artworkData: Data?
    
    // Convert to Track model for playback
    func toTrack() -> Track {
        let url = URL(fileURLWithPath: path)
        let track = Track(url: url)
        
        // Set the metadata immediately from database
        track.title = title
        track.artist = artist
        track.album = album
        track.genre = genre
        track.year = year
        track.duration = duration
        track.artworkData = artworkData
        track.isMetadataLoaded = true
        
        return track
    }
}
