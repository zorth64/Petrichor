import Foundation
import GRDB

class DatabaseManager: ObservableObject {
    // MARK: - Properties
    private let dbPath: String
    
    enum TrackProcessResult {
        case new(Track)
        case update(Track)
        case skipped
    }
    
    let dbQueue: DatabaseQueue
    
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
    
    // MARK: - Folder Management
    
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
    
    private func addFoldersAsync(_ urls: [URL], bookmarkDataMap: [URL: Data]) async throws -> [Folder] {
        await MainActor.run {
            self.isScanning = true
            self.scanProgress = 0.0
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
        
        await MainActor.run {
            self.scanStatusMessage = "Found \(totalFiles) tracks in \(folder.name)"
        }
        
        // Process in batches
        let batchSize = totalFiles > 1000 ? 100 : 50
        var processedCount = 0
        
        // Create immutable copy for async context
        let fileBatches = musicFiles.chunked(into: batchSize)
        
        for batch in fileBatches {
            let batchWithFolderId = batch.map { url in (url: url, folderId: folderId) }
            try await processBatch(batchWithFolderId)
            
            processedCount += batch.count
            
            await MainActor.run { [processedCount, totalFiles, folderName = folder.name] in
                self.scanStatusMessage = "Processing \(folderName): \(processedCount)/\(totalFiles) tracks"
            }
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

    // MARK: - Metadata Application

    func applyMetadataToTrack(_ track: inout Track, from metadata: TrackMetadata, at fileURL: URL) {
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
        
        // Additional metadata
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
        
        // Audio properties
        track.bitrate = metadata.bitrate
        track.sampleRate = metadata.sampleRate
        track.channels = metadata.channels
        track.codec = metadata.codec
        track.bitDepth = metadata.bitDepth
        
        // File properties
        if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
            track.fileSize = attributes.fileSize.map { Int64($0) }
            track.dateModified = attributes.contentModificationDate
        }
        
        // Extended metadata
        track.extendedMetadata = metadata.extended
    }

    func updateTrackIfNeeded(_ track: inout Track, with metadata: TrackMetadata, at fileURL: URL) -> Bool {
        var hasChanges = false
        
        // Update core metadata
        hasChanges = updateCoreMetadata(&track, with: metadata) || hasChanges
        
        // Update additional metadata
        hasChanges = updateAdditionalMetadata(&track, with: metadata) || hasChanges
        
        // Update audio properties
        hasChanges = updateAudioProperties(&track, with: metadata) || hasChanges
        
        // Update file properties
        hasChanges = updateFileProperties(&track, at: fileURL) || hasChanges
        
        // Always update extended metadata
        track.extendedMetadata = metadata.extended
        hasChanges = true
        
        return hasChanges
    }

    func updateCoreMetadata(_ track: inout Track, with metadata: TrackMetadata) -> Bool {
        var hasChanges = false
        
        if let newTitle = metadata.title, !newTitle.isEmpty && newTitle != track.title {
            track.title = newTitle
            hasChanges = true
        }
        
        if let newArtist = metadata.artist, !newArtist.isEmpty && newArtist != track.artist {
            track.artist = newArtist
            hasChanges = true
        }
        
        if let newAlbum = metadata.album, !newAlbum.isEmpty && newAlbum != track.album {
            track.album = newAlbum
            hasChanges = true
        }
        
        if let newGenre = metadata.genre, !newGenre.isEmpty && (track.genre == "Unknown Genre" || track.genre != newGenre) {
            track.genre = newGenre
            hasChanges = true
        }
        
        if let newComposer = metadata.composer, !newComposer.isEmpty && (track.composer == "Unknown Composer" || track.composer.isEmpty || track.composer != newComposer) {
            track.composer = newComposer
            hasChanges = true
        }
        
        if let newYear = metadata.year, !newYear.isEmpty && (track.year.isEmpty || track.year == "Unknown Year" || track.year != newYear) {
            track.year = newYear
            hasChanges = true
        }
        
        if metadata.duration > 0 && abs(metadata.duration - track.duration) > 0.1 {
            track.duration = metadata.duration
            hasChanges = true
        }
        
        if let newArtworkData = metadata.artworkData, track.artworkData == nil {
            track.artworkData = newArtworkData
            hasChanges = true
        }
        
        return hasChanges
    }

    func updateAdditionalMetadata(_ track: inout Track, with metadata: TrackMetadata) -> Bool {
        var hasChanges = false
        
        // Album metadata
        if let newAlbumArtist = metadata.albumArtist, !newAlbumArtist.isEmpty && newAlbumArtist != track.albumArtist {
            track.albumArtist = newAlbumArtist
            hasChanges = true
        }
        
        // Track/Disc numbers
        if let newTrackNumber = metadata.trackNumber, newTrackNumber != track.trackNumber {
            track.trackNumber = newTrackNumber
            hasChanges = true
        }
        
        if let newTotalTracks = metadata.totalTracks, newTotalTracks != track.totalTracks {
            track.totalTracks = newTotalTracks
            hasChanges = true
        }
        
        if let newDiscNumber = metadata.discNumber, newDiscNumber != track.discNumber {
            track.discNumber = newDiscNumber
            hasChanges = true
        }
        
        if let newTotalDiscs = metadata.totalDiscs, newTotalDiscs != track.totalDiscs {
            track.totalDiscs = newTotalDiscs
            hasChanges = true
        }
        
        // Other metadata
        if let newRating = metadata.rating, newRating != track.rating {
            track.rating = newRating
            hasChanges = true
        }
        
        if metadata.compilation != track.compilation {
            track.compilation = metadata.compilation
            hasChanges = true
        }
        
        if let newReleaseDate = metadata.releaseDate, !newReleaseDate.isEmpty && newReleaseDate != track.releaseDate {
            track.releaseDate = newReleaseDate
            hasChanges = true
        }
        
        if let newOriginalReleaseDate = metadata.originalReleaseDate, !newOriginalReleaseDate.isEmpty && newOriginalReleaseDate != track.originalReleaseDate {
            track.originalReleaseDate = newOriginalReleaseDate
            hasChanges = true
        }
        
        if let newBpm = metadata.bpm, newBpm != track.bpm {
            track.bpm = newBpm
            hasChanges = true
        }
        
        if let newMediaType = metadata.mediaType, !newMediaType.isEmpty && newMediaType != track.mediaType {
            track.mediaType = newMediaType
            hasChanges = true
        }
        
        // Sort fields
        if let newSortTitle = metadata.sortTitle, !newSortTitle.isEmpty && newSortTitle != track.sortTitle {
            track.sortTitle = newSortTitle
            hasChanges = true
        }
        
        if let newSortArtist = metadata.sortArtist, !newSortArtist.isEmpty && newSortArtist != track.sortArtist {
            track.sortArtist = newSortArtist
            hasChanges = true
        }
        
        if let newSortAlbum = metadata.sortAlbum, !newSortAlbum.isEmpty && newSortAlbum != track.sortAlbum {
            track.sortAlbum = newSortAlbum
            hasChanges = true
        }
        
        if let newSortAlbumArtist = metadata.sortAlbumArtist, !newSortAlbumArtist.isEmpty && newSortAlbumArtist != track.sortAlbumArtist {
            track.sortAlbumArtist = newSortAlbumArtist
            hasChanges = true
        }
        
        return hasChanges
    }

    func updateAudioProperties(_ track: inout Track, with metadata: TrackMetadata) -> Bool {
        var hasChanges = false
        
        if let newBitrate = metadata.bitrate, newBitrate != track.bitrate {
            track.bitrate = newBitrate
            hasChanges = true
        }
        
        if let newSampleRate = metadata.sampleRate, newSampleRate != track.sampleRate {
            track.sampleRate = newSampleRate
            hasChanges = true
        }
        
        if let newChannels = metadata.channels, newChannels != track.channels {
            track.channels = newChannels
            hasChanges = true
        }
        
        if let newCodec = metadata.codec, !newCodec.isEmpty && newCodec != track.codec {
            track.codec = newCodec
            hasChanges = true
        }
        
        if let newBitDepth = metadata.bitDepth, newBitDepth != track.bitDepth {
            track.bitDepth = newBitDepth
            hasChanges = true
        }
        
        return hasChanges
    }

    func updateFileProperties(_ track: inout Track, at fileURL: URL) -> Bool {
        var hasChanges = false
        
        if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
            if let newFileSize = attributes.fileSize.map({ Int64($0) }), newFileSize != track.fileSize {
                track.fileSize = newFileSize
                hasChanges = true
            }
            
            if let newDateModified = attributes.contentModificationDate, newDateModified != track.dateModified {
                track.dateModified = newDateModified
                hasChanges = true
            }
        }
        
        return hasChanges
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

    // MARK: - Track Property Updates
    
    // Updates a track's favorite status
    func updateTrackFavoriteStatus(trackId: Int64, isFavorite: Bool) async throws {
        try await dbQueue.write { db in
            try Track
                .filter(Track.Columns.trackId == trackId)
                .updateAll(db, Track.Columns.isFavorite.set(to: isFavorite))
        }
    }
    
    // Updates a track's play count and last played date
    func updateTrackPlayInfo(trackId: Int64, playCount: Int, lastPlayedDate: Date) async throws {
        try await dbQueue.write { db in
            try Track
                .filter(Track.Columns.trackId == trackId)
                .updateAll(db,
                    Track.Columns.playCount.set(to: playCount),
                    Track.Columns.lastPlayedDate.set(to: lastPlayedDate)
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
            // Save the playlist using GRDB's save method
            try playlist.save(db)
            
            // Delete existing track associations
            try PlaylistTrack
                .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                .deleteAll(db)
            
            let deletedCount = db.changesCount
            print("DatabaseManager: Deleted \(deletedCount) existing track associations")
            
            // Batch insert track associations for regular playlists
            if playlist.type == .regular && !playlist.tracks.isEmpty {
                print("DatabaseManager: Saving \(playlist.tracks.count) tracks for playlist '\(playlist.name)'")
                
                // Create all PlaylistTrack objects at once
                let playlistTracks = playlist.tracks.enumerated().compactMap { index, track -> PlaylistTrack? in
                    guard let trackId = track.trackId else {
                        print("DatabaseManager: WARNING - Track '\(track.title)' has no database ID, skipping")
                        return nil
                    }
                    
                    return PlaylistTrack(
                        playlistId: playlist.id.uuidString,
                        trackId: trackId,
                        position: index
                    )
                }
                
                // Batch insert all tracks at once
                if !playlistTracks.isEmpty {
                    try PlaylistTrack.insertMany(playlistTracks, db: db)
                    print("DatabaseManager: Batch inserted \(playlistTracks.count) tracks to playlist")
                }
                
                // Verify the save
                let savedCount = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                    .fetchCount(db)
                
                print("DatabaseManager: Verified \(savedCount) tracks saved for playlist in database")
            }
        }
    }
    
    func savePlaylist(_ playlist: Playlist) throws {
        try dbQueue.write { db in
            // Save the playlist using GRDB's save method
            try playlist.save(db)
            
            // Delete existing track associations
            try PlaylistTrack
                .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                .deleteAll(db)
            
            let deletedCount = db.changesCount
            print("DatabaseManager: Deleted \(deletedCount) existing track associations")
            
            // Batch insert track associations for regular playlists
            if playlist.type == .regular && !playlist.tracks.isEmpty {
                print("DatabaseManager: Saving \(playlist.tracks.count) tracks for playlist '\(playlist.name)'")
                
                // Create all PlaylistTrack objects at once
                let playlistTracks = playlist.tracks.enumerated().compactMap { index, track -> PlaylistTrack? in
                    guard let trackId = track.trackId else {
                        print("DatabaseManager: WARNING - Track '\(track.title)' has no database ID, skipping")
                        return nil
                    }
                    
                    return PlaylistTrack(
                        playlistId: playlist.id.uuidString,
                        trackId: trackId,
                        position: index
                    )
                }
                
                // Batch insert all tracks at once
                if !playlistTracks.isEmpty {
                    try PlaylistTrack.insertMany(playlistTracks, db: db)
                    print("DatabaseManager: Batch inserted \(playlistTracks.count) tracks to playlist")
                }
                
                // Verify the save
                let savedCount = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                    .fetchCount(db)
                
                print("DatabaseManager: Verified \(savedCount) tracks saved for playlist in database")
            }
        }
    }

    func loadAllPlaylists() -> [Playlist] {
        do {
            return try dbQueue.read { db in
                // Fetch all playlists
                var playlists = try Playlist.fetchAll(db)
                
                // Get all playlist IDs that need tracks
                let playlistIDs = playlists
                    .filter { $0.type == .regular }
                    .map { $0.id.uuidString }
                
                if !playlistIDs.isEmpty {
                    // Fetch all playlist tracks for all playlists at once
                    let allPlaylistTracks = try PlaylistTrack
                        .filter(playlistIDs.contains(PlaylistTrack.Columns.playlistId))
                        .order(PlaylistTrack.Columns.playlistId, PlaylistTrack.Columns.position)
                        .fetchAll(db)
                    
                    // Group by playlist
                    let tracksByPlaylist: [String: [PlaylistTrack]] = Dictionary(grouping: allPlaylistTracks) { $0.playlistId }
                    
                    // Get all unique track IDs
                    let allTrackIds = Set(allPlaylistTracks.map { $0.trackId })
                    
                    // Fetch all tracks at once
                    let tracks = try Track
                        .filter(allTrackIds.contains(Track.Columns.trackId))
                        .fetchAll(db)
                    
                    // Create lookup dictionary
                    var trackLookup = [Int64: Track]()
                    for track in tracks {
                        if let id = track.trackId {
                            trackLookup[id] = track
                        }
                    }
                    
                    // Assign tracks to each playlist
                    for index in playlists.indices {
                        if playlists[index].type == .regular,
                           let playlistTracks = tracksByPlaylist[playlists[index].id.uuidString] {
                            
                            var orderedTracks = [Track]()
                            for pt in playlistTracks {
                                if let track = trackLookup[pt.trackId] {
                                    orderedTracks.append(track)
                                }
                            }
                            playlists[index].tracks = orderedTracks
                        }
                    }
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
            // Use GRDB's model deletion
            if let playlist = try Playlist
                .filter(Playlist.Columns.id == playlistId.uuidString)
                .fetchOne(db) {
                try playlist.delete(db)
            }
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
