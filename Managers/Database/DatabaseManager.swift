import Foundation
import GRDB

class DatabaseManager: ObservableObject {
    // MARK: - Properties
    
    private let dbQueue: DatabaseQueue
    private let dbPath: String
    
    // MARK: - Published Properties for UI Updates
    
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage: String = ""
    
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
            // Create tables
            try db.create(table: "folders", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("path", .text).notNull().unique()
                t.column("track_count", .integer).notNull().defaults(to: 0)
                t.column("date_added", .datetime).notNull()
                t.column("date_updated", .datetime).notNull()
            }
            
            try db.create(table: "tracks", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("folder_id", .integer).notNull()
                    .references("folders", onDelete: .cascade)
                t.column("path", .text).notNull().unique()
                t.column("filename", .text).notNull()
                t.column("title", .text)
                t.column("artist", .text)
                t.column("album", .text)
                t.column("composer", .text)
                t.column("genre", .text)
                t.column("year", .text)
                t.column("duration", .double)
                t.column("format", .text)
                t.column("file_size", .integer)
                t.column("date_added", .datetime).notNull()
                t.column("date_modified", .datetime)
                t.column("artwork_data", .blob)
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("play_count", .integer).notNull().defaults(to: 0)
                t.column("last_played_date", .datetime)
                t.column("album_artist", .text)
                t.column("track_number", .integer)
                t.column("total_tracks", .integer)
                t.column("disc_number", .integer)
                t.column("total_discs", .integer)
                t.column("rating", .integer) // 0-5 scale
                t.column("compilation", .boolean).defaults(to: false)
                t.column("release_date", .text) // Full date string
                t.column("original_release_date", .text) // For reissues
                t.column("bpm", .integer)
                t.column("media_type", .text) // Music, Audiobook, Podcast, etc.

                t.column("sort_title", .text)
                t.column("sort_artist", .text)
                t.column("sort_album", .text)
                t.column("sort_album_artist", .text)

                t.column("extended_metadata", .text) // JSON stored as text
            }
            
            try db.create(table: "playlists", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("type", .text).notNull() // "regular" or "smart"
                t.column("smart_type", .text) // "favorites", "mostPlayed", "recentlyPlayed", "custom"
                t.column("is_user_editable", .boolean).notNull()
                t.column("is_content_editable", .boolean).notNull()
                t.column("date_created", .datetime).notNull()
                t.column("date_modified", .datetime).notNull()
                t.column("cover_artwork_data", .blob)
                t.column("smart_criteria", .text) // JSON string for smart playlist criteria
            }
            
            try db.create(table: "playlist_tracks", ifNotExists: true) { t in
                t.column("playlist_id", .text).notNull()
                    .references("playlists", column: "id", onDelete: .cascade)
                t.column("track_id", .integer).notNull()
                    .references("tracks", column: "id", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.primaryKey(["playlist_id", "track_id"])
            }
            
            // Create indices for better performance
            try db.create(index: "idx_tracks_folder_id", on: "tracks", columns: ["folder_id"], ifNotExists: true)
            try db.create(index: "idx_tracks_artist", on: "tracks", columns: ["artist"], ifNotExists: true)
            try db.create(index: "idx_tracks_album", on: "tracks", columns: ["album"], ifNotExists: true)
            try db.create(index: "idx_tracks_composer", on: "tracks", columns: ["composer"], ifNotExists: true)
            try db.create(index: "idx_tracks_genre", on: "tracks", columns: ["genre"], ifNotExists: true)
            try db.create(index: "idx_tracks_year", on: "tracks", columns: ["year"], ifNotExists: true)
            try db.create(index: "idx_tracks_album_artist", on: "tracks", columns: ["album_artist"], ifNotExists: true)
            try db.create(index: "idx_tracks_rating", on: "tracks", columns: ["rating"], ifNotExists: true)
            try db.create(index: "idx_tracks_compilation", on: "tracks", columns: ["compilation"], ifNotExists: true)
            try db.create(index: "idx_tracks_media_type", on: "tracks", columns: ["media_type"], ifNotExists: true)
            try db.create(index: "idx_playlist_tracks_playlist_id", on: "playlist_tracks", columns: ["playlist_id"], ifNotExists: true)
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
    
    // MARK: - Folder Management
    
    func addFolders(_ urls: [URL], completion: @escaping (Result<[Folder], Error>) -> Void) {
        Task {
            do {
                let folders = try await addFoldersAsync(urls)
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
    
    private func addFoldersAsync(_ urls: [URL]) async throws -> [Folder] {
        await MainActor.run {
            self.isScanning = true
            self.scanProgress = 0.0
            self.scanStatusMessage = "Adding folders..."
        }
        
        var addedFolders: [Folder] = []
        
        try await dbQueue.write { db in
            for url in urls {
                var folder = Folder(url: url)
                
                // Check if folder already exists
                if let existing = try Folder
                    .filter(Folder.Columns.path == url.path)
                    .fetchOne(db) {
                    addedFolders.append(existing)
                    print("Folder already exists: \(existing.name) with ID: \(existing.id ?? -1)")
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
    
    // MARK: - Track Scanning
    
    private func scanFoldersForTracks(_ folders: [Folder]) async throws {
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "flac"]
        let totalFolders = folders.count
        var processedFolders = 0
        
        for folder in folders {
            await MainActor.run {
                self.scanStatusMessage = "Scanning \(folder.name)..."
                self.scanProgress = Double(processedFolders) / Double(totalFolders)
            }
            
            try await scanSingleFolder(folder, supportedExtensions: supportedExtensions)
            processedFolders += 1
        }
        
        await MainActor.run {
            self.scanProgress = 1.0
            self.scanStatusMessage = "Scan complete"
        }
    }
    
    private func scanSingleFolder(_ folder: Folder, supportedExtensions: [String]) async throws {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: folder.url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }
        
        // Get existing tracks for this folder to check for updates
        var existingTracks: [URL: Track] = [:]
        if let folderId = folder.id {
            let tracks = getTracksForFolder(folderId)
            for track in tracks {
                existingTracks[track.url] = track
            }
        }
        
        // Collect all music files first
        var musicFiles: [URL] = []
        var scannedPaths = Set<URL>()
        
        for case let fileURL as URL in enumerator {
            let fileExtension = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(fileExtension) {
                musicFiles.append(fileURL)
                scannedPaths.insert(fileURL)
            }
        }
        
        await MainActor.run {
            self.scanStatusMessage = "Found \(musicFiles.count) tracks in \(folder.name)"
        }
        
        // Process in batches
        let batchSize = 50
        var processedCount = 0
        
        for batch in musicFiles.chunked(into: batchSize) {
            try await processBatch(batch, folder: folder, existingTracks: existingTracks)
            processedCount += batch.count
            
            let progress = Double(processedCount) / Double(musicFiles.count)
            await MainActor.run {
                self.scanStatusMessage = "Processing \(folder.name): \(processedCount)/\(musicFiles.count) tracks"
            }
        }
        
        // Remove tracks that no longer exist in the folder
        if let folderId = folder.id {
            try await dbQueue.write { db in
                for (url, track) in existingTracks {
                    if !scannedPaths.contains(url) {
                        // File no longer exists, remove from database
                        try track.delete(db)
                        print("Removed track that no longer exists: \(url.lastPathComponent)")
                    }
                }
            }
        }
        
        // Update folder track count
        try await updateFolderTrackCount(folder)
    }
    
    private func processBatch(_ files: [URL], folder: Folder, existingTracks: [URL: Track]) async throws {
        guard let folderId = folder.id else {
            print("ERROR: Folder has no ID! Folder: \(folder.name)")
            return
        }
        
        try await dbQueue.write { db in
            for fileURL in files {
                let fileModificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                
                if let existingTrack = existingTracks[fileURL] {
                    let metadata = MetadataExtractor.extractMetadataSync(from: fileURL)
                    
                    var hasChanges = false
                    var updatedTrack = existingTrack
                    
                    // Update all core metadata fields if we found better data
                    if let newTitle = metadata.title,
                       !newTitle.isEmpty && newTitle != existingTrack.title {
                        updatedTrack.title = newTitle
                        hasChanges = true
                    }
                    
                    if let newArtist = metadata.artist,
                       !newArtist.isEmpty && newArtist != existingTrack.artist {
                        updatedTrack.artist = newArtist
                        hasChanges = true
                    }
                    
                    if let newAlbum = metadata.album,
                       !newAlbum.isEmpty && newAlbum != existingTrack.album {
                        updatedTrack.album = newAlbum
                        hasChanges = true
                    }
                    
                    if let newGenre = metadata.genre,
                       !newGenre.isEmpty && (existingTrack.genre == "Unknown Genre" || existingTrack.genre != newGenre) {
                        updatedTrack.genre = newGenre
                        hasChanges = true
                    }
                    
                    if let newComposer = metadata.composer,
                       !newComposer.isEmpty && (existingTrack.composer == "Unknown Composer" || existingTrack.composer.isEmpty || existingTrack.composer != newComposer) {
                        updatedTrack.composer = newComposer
                        hasChanges = true
                    }
                    
                    if let newYear = metadata.year,
                       !newYear.isEmpty && (existingTrack.year.isEmpty || existingTrack.year == "Unknown Year" || existingTrack.year != newYear) {
                        updatedTrack.year = newYear
                        hasChanges = true
                    }

                    if metadata.duration > 0 && abs(metadata.duration - existingTrack.duration) > 0.1 {
                        updatedTrack.duration = metadata.duration
                        hasChanges = true
                    }

                    if let newArtworkData = metadata.artworkData,
                       existingTrack.artworkData == nil {
                        updatedTrack.artworkData = newArtworkData
                        hasChanges = true
                    }

                    if let newAlbumArtist = metadata.albumArtist,
                       !newAlbumArtist.isEmpty && newAlbumArtist != existingTrack.albumArtist {
                        updatedTrack.albumArtist = newAlbumArtist
                        hasChanges = true
                    }
                    
                    if let newTrackNumber = metadata.trackNumber,
                       newTrackNumber != existingTrack.trackNumber {
                        updatedTrack.trackNumber = newTrackNumber
                        hasChanges = true
                    }
                    
                    if let newTotalTracks = metadata.totalTracks,
                       newTotalTracks != existingTrack.totalTracks {
                        updatedTrack.totalTracks = newTotalTracks
                        hasChanges = true
                    }
                    
                    if let newDiscNumber = metadata.discNumber,
                       newDiscNumber != existingTrack.discNumber {
                        updatedTrack.discNumber = newDiscNumber
                        hasChanges = true
                    }
                    
                    if let newTotalDiscs = metadata.totalDiscs,
                       newTotalDiscs != existingTrack.totalDiscs {
                        updatedTrack.totalDiscs = newTotalDiscs
                        hasChanges = true
                    }
                    
                    if let newRating = metadata.rating,
                       newRating != existingTrack.rating {
                        updatedTrack.rating = newRating
                        hasChanges = true
                    }
                    
                    if metadata.compilation != existingTrack.compilation {
                        updatedTrack.compilation = metadata.compilation
                        hasChanges = true
                    }
                    
                    if let newReleaseDate = metadata.releaseDate,
                       !newReleaseDate.isEmpty && newReleaseDate != existingTrack.releaseDate {
                        updatedTrack.releaseDate = newReleaseDate
                        hasChanges = true
                    }
                    
                    if let newOriginalReleaseDate = metadata.originalReleaseDate,
                       !newOriginalReleaseDate.isEmpty && newOriginalReleaseDate != existingTrack.originalReleaseDate {
                        updatedTrack.originalReleaseDate = newOriginalReleaseDate
                        hasChanges = true
                    }
                    
                    if let newBpm = metadata.bpm,
                       newBpm != existingTrack.bpm {
                        updatedTrack.bpm = newBpm
                        hasChanges = true
                    }
                    
                    if let newMediaType = metadata.mediaType,
                       !newMediaType.isEmpty && newMediaType != existingTrack.mediaType {
                        updatedTrack.mediaType = newMediaType
                        hasChanges = true
                    }
                    
                    // Update sort fields
                    if let newSortTitle = metadata.sortTitle,
                       !newSortTitle.isEmpty && newSortTitle != existingTrack.sortTitle {
                        updatedTrack.sortTitle = newSortTitle
                        hasChanges = true
                    }
                    
                    if let newSortArtist = metadata.sortArtist,
                       !newSortArtist.isEmpty && newSortArtist != existingTrack.sortArtist {
                        updatedTrack.sortArtist = newSortArtist
                        hasChanges = true
                    }
                    
                    if let newSortAlbum = metadata.sortAlbum,
                       !newSortAlbum.isEmpty && newSortAlbum != existingTrack.sortAlbum {
                        updatedTrack.sortAlbum = newSortAlbum
                        hasChanges = true
                    }
                    
                    if let newSortAlbumArtist = metadata.sortAlbumArtist,
                       !newSortAlbumArtist.isEmpty && newSortAlbumArtist != existingTrack.sortAlbumArtist {
                        updatedTrack.sortAlbumArtist = newSortAlbumArtist
                        hasChanges = true
                    }
                    
                    // Always update extended metadata
                    updatedTrack.extendedMetadata = metadata.extended
                    hasChanges = true
                    
                    // Update in database if there were changes
                    if hasChanges {
                        try updatedTrack.update(db)
                        print("Updated metadata for: \(updatedTrack.title) - Changes detected")
                    }
                } else {
                    // New track - extract metadata and add to database
                    let metadata = MetadataExtractor.extractMetadataSync(from: fileURL)
                    
                    // Create track
                    var track = Track(url: fileURL)
                    track.folderId = folderId
                    
                    // Core fields
                    track.title = metadata.title ?? fileURL.deletingPathExtension().lastPathComponent
                    track.artist = metadata.artist ?? "Unknown Artist"
                    track.album = metadata.album ?? "Unknown Album"
                    track.genre = metadata.genre ?? "Unknown Genre"
                    track.composer = metadata.composer ?? "Unknown Composer"
                    track.year = metadata.year ?? ""
                    track.duration = metadata.duration
                    track.artworkData = metadata.artworkData
                    track.isMetadataLoaded = true
                    track.albumArtist = metadata.albumArtist
                    track.trackNumber = metadata.trackNumber
                    track.totalTracks = metadata.totalTracks
                    track.discNumber = metadata.discNumber
                    track.totalDiscs = metadata.totalDiscs
                    track.rating = metadata.rating
                    track.compilation = metadata.compilation
                    track.releaseDate = metadata.releaseDate
                    track.originalReleaseDate = metadata.originalReleaseDate
                    track.bpm = metadata.bpm
                    track.mediaType = metadata.mediaType
                    
                    // Sort fields
                    track.sortTitle = metadata.sortTitle
                    track.sortArtist = metadata.sortArtist
                    track.sortAlbum = metadata.sortAlbum
                    track.sortAlbumArtist = metadata.sortAlbumArtist

                    track.extendedMetadata = metadata.extended
                    
                    // Save to database
                    try track.save(db)
                    print("Added new track: \(track.title)")
                    
                    // Log some interesting metadata if present
                    if let albumArtist = track.albumArtist {
                        print("  Album Artist: \(albumArtist)")
                    }
                    if let trackNum = track.trackNumber {
                        let totalStr = track.totalTracks.map { "/\($0)" } ?? ""
                        print("  Track: \(trackNum)\(totalStr)")
                    }
                    if let discNum = track.discNumber {
                        let totalStr = track.totalDiscs.map { "/\($0)" } ?? ""
                        print("  Disc: \(discNum)\(totalStr)")
                    }
                    if track.compilation {
                        print("  Compilation: Yes")
                    }
                    if let mbid = track.extendedMetadata?.musicBrainzTrackId {
                        print("  MusicBrainz ID: \(mbid)")
                    }
                }
            }
        }
    }
    
    private func updateFolderTrackCount(_ folder: Folder) async throws {
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
    
    // MARK: - Query Track by Columns

    func getTracksByColumn(_ column: String, value: String) -> [Track] {
        do {
            return try dbQueue.read { db in
                let sql: String
                
                // Check if this is an "Unknown" placeholder value
                if value.starts(with: "Unknown ") {
                    // Match both empty strings and the placeholder value
                    sql = """
                        SELECT * FROM tracks 
                        WHERE \(column) = '' OR \(column) IS NULL OR \(column) = ?
                        ORDER BY title
                        """
                } else if value.isEmpty {
                    // Handle empty value queries
                    sql = """
                        SELECT * FROM tracks 
                        WHERE \(column) = '' OR \(column) IS NULL
                        ORDER BY title
                        """
                } else {
                    // Normal exact match
                    sql = """
                        SELECT * FROM tracks 
                        WHERE \(column) = ?
                        ORDER BY title
                        """
                }
                
                return try Track.fetchAll(db, sql: sql, arguments: [value])
            }
        } catch {
            print("Failed to fetch tracks by \(column): \(error)")
            return []
        }
    }

    // For partial matching (like artists with collaborations)
    func getTracksByColumnContaining(_ column: String, value: String) -> [Track] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT * FROM tracks 
                    WHERE \(column) LIKE ?
                    ORDER BY title
                    """
                return try Track.fetchAll(db, sql: sql, arguments: ["%\(value)%"])
            }
        } catch {
            print("Failed to fetch tracks by \(column) containing '\(value)': \(error)")
            return []
        }
    }

    // Generic method to get distinct values for any column
    func getDistinctValues(for column: String) -> [String] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT DISTINCT \(column) 
                    FROM tracks 
                    WHERE \(column) IS NOT NULL
                    ORDER BY \(column)
                    """
                return try String.fetchAll(db, sql: sql)
            }
        } catch {
            print("Failed to fetch distinct values for \(column): \(error)")
            return []
        }
    }
    
    // MARK: - Track Queries
    
    func getAllTracks() -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .including(optional: Track.folder)
                    .order(Track.Columns.artist, Track.Columns.album, Track.Columns.title)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch tracks: \(error)")
            return []
        }
    }

    func getTracksForFolder(_ folderId: Int64) -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.folderId == folderId)
                    .order(Track.Columns.filename)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch tracks for folder: \(error)")
            return []
        }
    }

    func getArtworkForTrack(_ trackId: Int64) -> Data? {
        do {
            return try dbQueue.read { db in
                try Track
                    .select(Track.Columns.artworkData)
                    .filter(Track.Columns.trackId == trackId)
                    .fetchOne(db)
            }
        } catch {
            print("Failed to fetch artwork: \(error)")
            return nil
        }
    }
    
    // MARK: - Refresh Methods
    
    func refreshFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                await MainActor.run {
                    self.isScanning = true
                    self.scanStatusMessage = "Refreshing \(folder.name)..."
                }
                
                // Scan the folder - this will now always check for metadata updates
                try await scanSingleFolder(folder, supportedExtensions: ["mp3", "m4a", "wav", "aac", "aiff", "flac"])
                
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

    // MARK: - Track Property Updates
    
    // Updates a track's favorite status
    func updateTrackFavoriteStatus(trackId: Int64, isFavorite: Bool) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE tracks SET is_favorite = ? WHERE id = ?",
                arguments: [isFavorite, trackId]
            )
        }
    }
    
    // Updates a track's play count and last played date
    func updateTrackPlayInfo(trackId: Int64, playCount: Int, lastPlayedDate: Date) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE tracks SET play_count = ?, last_played_date = ? WHERE id = ?",
                arguments: [playCount, lastPlayedDate, trackId]
            )
        }
    }
    
    // Batch update for track properties (more efficient for multiple updates)
    func updateTrack(_ track: Track) async throws {
        guard let trackId = track.trackId else {
            throw DatabaseError.invalidTrackId
        }
        
        try await dbQueue.write { db in
            try track.update(db)
        }
    }
    
    // Gets tracks by favorite status
    func getFavoriteTracks() -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.isFavorite == true)
                    .order(Track.Columns.title)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch favorite tracks: \(error)")
            return []
        }
    }
    
    // Gets most played tracks
    func getMostPlayedTracks(minPlayCount: Int = 3, limit: Int = 25) -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.playCount >= minPlayCount)
                    .order(Track.Columns.playCount.desc)
                    .limit(limit)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch most played tracks: \(error)")
            return []
        }
    }
    
    // Gets recently played tracks
    func getRecentlyPlayedTracks(daysBack: Int = 7, limit: Int = 25) -> [Track] {
        do {
            let cutoffDate = Date().addingTimeInterval(-Double(daysBack * 24 * 60 * 60))
            
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.lastPlayedDate > cutoffDate)
                    .order(Track.Columns.lastPlayedDate.desc)
                    .limit(limit)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch recently played tracks: \(error)")
            return []
        }
    }
    
    // MARK: - Playlist Management
    
    func savePlaylistAsync(_ playlist: Playlist) async throws {
        try await dbQueue.write { db in
            // Convert smart criteria to JSON if present
            var smartCriteriaJSON: String? = nil
            if let criteria = playlist.smartCriteria {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(criteria) {
                    smartCriteriaJSON = String(data: data, encoding: .utf8)
                }
            }
            
            // Insert or update playlist
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO playlists 
                    (id, name, type, smart_type, is_user_editable, is_content_editable, 
                     date_created, date_modified, cover_artwork_data, smart_criteria)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    playlist.id.uuidString,
                    playlist.name,
                    playlist.type.rawValue,
                    playlist.smartType?.rawValue,
                    playlist.isUserEditable,
                    playlist.isContentEditable,
                    playlist.dateCreated,
                    playlist.dateModified,
                    playlist.coverArtworkData,
                    smartCriteriaJSON
                ]
            )
            
            // Delete existing track associations
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?",
                arguments: [playlist.id.uuidString]
            )
            
            // Insert track associations (only for regular playlists)
            if playlist.type == .regular {
                for (index, track) in playlist.tracks.enumerated() {
                    guard let trackId = track.trackId else { continue }
                    
                    try db.execute(
                        sql: """
                            INSERT INTO playlist_tracks (playlist_id, track_id, position)
                            VALUES (?, ?, ?)
                            """,
                        arguments: [playlist.id.uuidString, trackId, index]
                    )
                }
            }
        }
    }
    
    func savePlaylist(_ playlist: Playlist) throws {
        try dbQueue.write { db in
            // Convert smart criteria to JSON if present
            var smartCriteriaJSON: String? = nil
            if let criteria = playlist.smartCriteria {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(criteria) {
                    smartCriteriaJSON = String(data: data, encoding: .utf8)
                }
            }
            
            // Insert or update playlist
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO playlists 
                    (id, name, type, smart_type, is_user_editable, is_content_editable, 
                     date_created, date_modified, cover_artwork_data, smart_criteria)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    playlist.id.uuidString,
                    playlist.name,
                    playlist.type.rawValue,
                    playlist.smartType?.rawValue,
                    playlist.isUserEditable,
                    playlist.isContentEditable,
                    playlist.dateCreated,
                    playlist.dateModified,
                    playlist.coverArtworkData,
                    smartCriteriaJSON
                ]
            )
            
            // Delete existing track associations
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?",
                arguments: [playlist.id.uuidString]
            )
            
            // Check how many were deleted (for debugging)
            let deletedCount = db.changesCount
            print("DatabaseManager: Deleted \(deletedCount) existing track associations")
            
            // Insert track associations (only for regular playlists)
            if playlist.type == .regular {
                print("DatabaseManager: Saving \(playlist.tracks.count) tracks for playlist '\(playlist.name)'")
                
                for (index, track) in playlist.tracks.enumerated() {
                    guard let trackId = track.trackId else {
                        print("DatabaseManager: WARNING - Track '\(track.title)' has no database ID, skipping")
                        continue
                    }
                    
                    try db.execute(
                        sql: """
                            INSERT INTO playlist_tracks (playlist_id, track_id, position)
                            VALUES (?, ?, ?)
                            """,
                        arguments: [playlist.id.uuidString, trackId, index]
                    )
                    print("DatabaseManager: Saved track '\(track.title)' (ID: \(trackId)) at position \(index)")
                }
                
                // Verify the save
                let savedCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ?",
                    arguments: [playlist.id.uuidString]
                ) ?? 0
                
                print("DatabaseManager: Verified \(savedCount) tracks saved for playlist in database")
            }
        }
    }
    
    func loadAllPlaylists() -> [Playlist] {
        do {
            return try dbQueue.read { db in
                // Load playlists
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT * FROM playlists ORDER BY date_created"
                )
                
                var playlists: [Playlist] = []
                
                for row in rows {
                    let id = UUID(uuidString: row["id"]) ?? UUID()
                    let name: String = row["name"]
                    let typeRaw: String = row["type"]
                    let type = PlaylistType(rawValue: typeRaw) ?? .regular
                    let smartTypeRaw: String? = row["smart_type"]
                    let smartType = smartTypeRaw.flatMap { SmartPlaylistType(rawValue: $0) }
                    let isUserEditable: Bool = row["is_user_editable"]
                    let isContentEditable: Bool = row["is_content_editable"]
                    let dateCreated: Date = row["date_created"]
                    let dateModified: Date = row["date_modified"]
                    let coverArtworkData: Data? = row["cover_artwork_data"]
                    
                    // Parse smart criteria if present
                    var smartCriteria: SmartPlaylistCriteria? = nil
                    if let criteriaJSON: String = row["smart_criteria"],
                       let data = criteriaJSON.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        smartCriteria = try? decoder.decode(SmartPlaylistCriteria.self, from: data)
                    }
                    
                    // Load tracks for regular playlists
                    var tracks: [Track] = []
                    if type == .regular {
                        tracks = try Track
                            .joining(required: Track.folder)
                            .filter(sql: """
                                tracks.id IN (
                                    SELECT track_id FROM playlist_tracks 
                                    WHERE playlist_id = ? 
                                    ORDER BY position
                                )
                                """, arguments: [id.uuidString])
                            .fetchAll(db)
                    }
                    
                    // Create playlist using the restoration initializer
                    let playlist = Playlist(
                        id: id,
                        name: name,
                        tracks: tracks,
                        dateCreated: dateCreated,
                        dateModified: dateModified,
                        coverArtworkData: coverArtworkData,
                        type: type,
                        smartType: smartType,
                        isUserEditable: isUserEditable,
                        isContentEditable: isContentEditable,
                        smartCriteria: smartCriteria
                    )
                    
                    playlists.append(playlist)
                }
                
                return playlists
            }
        } catch {
            print("DatabaseManager: Failed to load playlists: \(error)")
            return []
        }
    }
    
    func deletePlaylist(_ playlistId: UUID) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM playlists WHERE id = ?",
                arguments: [playlistId.uuidString]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    func getTracksInFolder(_ folder: Folder) -> [Track] {
        guard let folderId = folder.id else { return [] }
        return getTracksForFolder(folderId)
    }
    
    // Clean up database file
    func resetDatabase() throws {
        try dbQueue.erase()
        try setupDatabase()
    }
}

// MARK: - Local Enums

enum DatabaseError: Error {
    case invalidTrackId
    case updateFailed
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
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
