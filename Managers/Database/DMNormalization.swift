import Foundation
import GRDB

extension DatabaseManager {
    // MARK: - Artist Management

    /// Find or create an artist by name
    func findOrCreateArtist(_ name: String, in db: Database) throws -> Artist {
        let normalizedName = ArtistParser.normalizeArtistName(name)

        // Try to find existing artist
        if let existing = try Artist
            .filter(Artist.Columns.normalizedName == normalizedName)
            .fetchOne(db) {
            return existing
        }

        // Create new artist
        let artist = Artist(name: name)
        try artist.insert(db)
        return artist
    }

    /// Process all artists for a track (artists, composers, album artists)
    func processTrackArtists(_ track: Track, metadata: TrackMetadata, in db: Database) throws {
        guard let trackId = track.trackId else { return }

        // Process main artists
        if !track.artist.isEmpty && track.artist != "Unknown Artist" {
            try processArtistsForField(
                track.artist,
                trackId: trackId,
                role: TrackArtist.Role.artist,
                in: db
            )
        }

        // Process composers
        if !track.composer.isEmpty && track.composer != "Unknown Composer" {
            try processArtistsForField(
                track.composer,
                trackId: trackId,
                role: TrackArtist.Role.composer,
                in: db
            )
        }

        // Process album artists
        if let albumArtist = track.albumArtist, !albumArtist.isEmpty {
            try processArtistsForField(
                albumArtist,
                trackId: trackId,
                role: TrackArtist.Role.albumArtist,
                in: db
            )
        }
    }

    private func processArtistsForField(_ field: String, trackId: Int64, role: String, in db: Database) throws {
        let artistNames = ArtistParser.parse(field)

        for (index, artistName) in artistNames.enumerated() {
            let artist = try findOrCreateArtist(artistName, in: db)

            guard let artistId = artist.id else { continue }

            // Create track-artist relationship
            let trackArtist = TrackArtist(
                trackId: trackId,
                artistId: artistId,
                role: role,
                position: index
            )

            try trackArtist.insert(db)
        }
    }

    /// Update artist artwork
    func updateArtistArtwork(_ artistId: Int64, artworkData: Data?, in db: Database) throws {
        guard let artworkData = artworkData else { return }

        // Check if artist already has artwork
        guard let artist = try Artist.fetchOne(db, key: artistId),
              artist.artworkData == nil else { return }

        // Update artwork
        artist.artworkData = artworkData
        artist.updatedAt = Date()
        try artist.update(db)
    }

    // MARK: - Album Management

    /// Find or create an album with better duplicate prevention
    func findOrCreateAlbum(_ title: String, artistName: String?, in db: Database) throws -> Album {
        let normalizedTitle = title.lowercased()
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "the ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // First, get or create the artist if we have one
        var artistId: Int64?
        if let artistName = artistName, !artistName.isEmpty, artistName != "Unknown Artist" {
            let artist = try findOrCreateArtist(artistName, in: db)
            artistId = artist.id
        }
        
        // Try to find existing album with same normalized title and artist
        if let artistId = artistId {
            // Look for album with specific artist
            if let existingAlbum = try Album
                .filter(Album.Columns.normalizedTitle == normalizedTitle)
                .filter(Album.Columns.artistId == artistId)
                .fetchOne(db) {
                return existingAlbum
            }
        } else {
            // Look for album with no artist
            if let existingAlbum = try Album
                .filter(Album.Columns.normalizedTitle == normalizedTitle)
                .filter(Album.Columns.artistId == nil)
                .fetchOne(db) {
                return existingAlbum
            }
        }
        
        // No existing album found, create new one
        let album = Album(title: title)
        album.artistId = artistId
        
        try album.insert(db)
        
        return album
    }

    /// Process album for a track
    func processTrackAlbum(_ track: inout Track, in db: Database) throws {
        guard !track.album.isEmpty && track.album != "Unknown Album" else { return }

        // Determine the album artist (prefer albumArtist field, fallback to artist)
        let albumArtistName = track.albumArtist ?? track.artist

        let album = try findOrCreateAlbum(track.album, artistName: albumArtistName, in: db)
        track.albumId = album.id

        // Update album metadata if we have more info
        if let albumId = album.id {
            try updateAlbumMetadata(albumId: albumId, from: track, in: db)
        }
    }

    private func updateAlbumMetadata(albumId: Int64, from track: Track, in db: Database) throws {
        guard let album = try Album.fetchOne(db, key: albumId) else { return }

        var needsUpdate = false

        // Update release year if not set
        if album.releaseYear == nil && !track.year.isEmpty && track.year != "Unknown Year" {
            if let year = Int(track.year) {
                album.releaseYear = year
                needsUpdate = true
            }
        }

        // Update release date if not set
        if album.releaseDate == nil && track.releaseDate != nil {
            album.releaseDate = track.releaseDate
            needsUpdate = true
        }

        // Update total tracks/discs if we have more complete info
        if let trackTotal = track.totalTracks,
           let albumTotal = album.totalTracks,
           trackTotal > albumTotal {
            album.totalTracks = trackTotal
            needsUpdate = true
        }

        if let discTotal = track.totalDiscs,
           let albumTotal = album.totalDiscs,
           discTotal > albumTotal {
            album.totalDiscs = discTotal
            needsUpdate = true
        }

        // Copy extended metadata that might be useful
        if album.label == nil, let label = track.extendedMetadata?.label {
            album.label = label
            needsUpdate = true
        }

        if needsUpdate {
            try album.update(db)
        }
    }

    /// Update album artwork
    func updateAlbumArtwork(_ albumId: Int64, artworkData: Data?, in db: Database) throws {
        guard let artworkData = artworkData, !artworkData.isEmpty else { return }

        // Check current state
        if let album = try Album.fetchOne(db, key: albumId) {
            print("DatabaseManager: Before update - Album '\(album.title)' has \(album.artworkData?.count ?? 0) bytes")
        }

        // Direct update using SQL
        try db.execute(
            sql: "UPDATE albums SET artwork_data = ?, updated_at = ? WHERE id = ?",
            arguments: [artworkData, Date(), albumId]
        )

        // Verify update
        if let album = try Album.fetchOne(db, key: albumId) {
            print("DatabaseManager: After update - Album '\(album.title)' has \(album.artworkData?.count ?? 0) bytes")
        }
    }

    // MARK: - Genre Management

    /// Find or create genres for a track
    func processTrackGenres(_ track: Track, in db: Database) throws {
        guard let trackId = track.trackId,
              !track.genre.isEmpty && track.genre != "Unknown Genre" else { return }

        // Genres might be separated by various delimiters
        let genreNames = track.genre
            .split(separator: ";")
            .flatMap { $0.split(separator: "/") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for genreName in genreNames {
            let genre = try findOrCreateGenre(String(genreName), in: db)

            guard let genreId = genre.id else { continue }

            // Create track-genre relationship
            let trackGenre = TrackGenre(trackId: trackId, genreId: genreId)
            try trackGenre.insert(db)
        }
    }

    private func findOrCreateGenre(_ name: String, in db: Database) throws -> Genre {
        if let existing = try Genre
            .filter(Genre.Columns.name == name)
            .fetchOne(db) {
            return existing
        }

        let genre = Genre(name: name)
        try genre.insert(db)
        return genre
    }

    // MARK: - Stats Update

    /// Update artist and album statistics
    func updateEntityStats(in db: Database) throws {
        // Batch update artists
        try updateArtistStats(in: db)

        // Batch update albums
        try updateAlbumStats(in: db)
    }

    private func updateArtistStats(in db: Database) throws {
        // First, collect all the stats in memory
        struct ArtistStats {
            let id: Int64
            let trackCount: Int
            let albumCount: Int
        }

        // Get all artist IDs
        let artistIds = try Artist
            .select(Artist.Columns.id, as: Int64.self)
            .fetchAll(db)

        // Collect stats for all artists
        var statsToUpdate: [ArtistStats] = []

        for artistId in artistIds {
            let trackCount = try TrackArtist
                .filter(TrackArtist.Columns.artistId == artistId)
                .select(TrackArtist.Columns.trackId, as: Int64.self)
                .distinct()
                .fetchCount(db)

            let albumCount = try Album
                .filter(Album.Columns.artistId == artistId)
                .fetchCount(db)

            statsToUpdate.append(ArtistStats(
                id: artistId,
                trackCount: trackCount,
                albumCount: albumCount
            ))
        }

        // Batch update using GRDB's updateAll
        let currentTime = Date()
        for stats in statsToUpdate {
            try db.execute(
                sql: "UPDATE artists SET total_tracks = ?, total_albums = ?, updated_at = ? WHERE id = ?",
                arguments: [stats.trackCount, stats.albumCount, currentTime, stats.id]
            )
        }
    }

    private func updateAlbumStats(in db: Database) throws {
        // Get all album IDs with their track counts in a single query
        let albumStats = try Row.fetchAll(db, sql: """
            SELECT album_id, COUNT(*) as track_count
            FROM tracks
            WHERE album_id IS NOT NULL
            GROUP BY album_id
        """)

        // Batch update
        let currentTime = Date()
        for stat in albumStats {
            let albumId: Int64 = stat["album_id"]
            let trackCount: Int = stat["track_count"]

            try db.execute(
                sql: "UPDATE albums SET total_tracks = ?, updated_at = ? WHERE id = ?",
                arguments: [trackCount, currentTime, albumId]
            )
        }
    }

    /// Alternative: Update stats for a single artist (more efficient for incremental updates)
    func updateStatsForArtist(_ artistId: Int64, in db: Database) throws {
        guard let artist = try Artist.fetchOne(db, key: artistId) else { return }

        artist.totalTracks = try TrackArtist
            .filter(TrackArtist.Columns.artistId == artistId)
            .select(TrackArtist.Columns.trackId, as: Int64.self)
            .distinct()
            .fetchCount(db)

        artist.totalAlbums = try Album
            .filter(Album.Columns.artistId == artistId)
            .fetchCount(db)

        artist.updatedAt = Date()
        try artist.update(db)
    }

    /// Alternative: Update stats for a single album (more efficient for incremental updates)
    func updateStatsForAlbum(_ albumId: Int64, in db: Database) throws {
        guard let album = try Album.fetchOne(db, key: albumId) else { return }

        album.totalTracks = try Track
            .filter(Track.Columns.albumId == albumId)
            .fetchCount(db)

        album.updatedAt = Date()
        try album.update(db)
    }

    // MARK: - Query Methods for Normalized Data

    /// Get all artists with track counts
    func getAllArtists() throws -> [Artist] {
        try dbQueue.read { db in
            try Artist
                .order(Artist.Columns.sortName)
                .fetchAll(db)
        }
    }

    /// Get all albums with track counts
    func getAllAlbums() throws -> [Album] {
        try dbQueue.read { db in
            try Album
                .including(optional: Album.artist)
                .order(Album.Columns.sortTitle)
                .fetchAll(db)
        }
    }

    /// Get all genres with track counts
    func getAllGenres() throws -> [Genre] {
        try dbQueue.read { db in
            try Genre
                .order(Genre.Columns.name)
                .fetchAll(db)
        }
    }

    /// Get tracks by artist (including all roles)
    func getTracksByArtist(_ artistId: Int64) throws -> [Track] {
        try dbQueue.read { db in
            let trackIds = try TrackArtist
                .filter(TrackArtist.Columns.artistId == artistId)
                .select(TrackArtist.Columns.trackId, as: Int64.self)
                .fetchAll(db)

            return try Track
                .filter(trackIds.contains(Track.Columns.trackId))
                .fetchAll(db)
        }
    }

    /// Get tracks by album
    func getTracksByAlbum(_ albumId: Int64) throws -> [Track] {
        try dbQueue.read { db in
            try Track
                .filter(Track.Columns.albumId == albumId)
                .order(Track.Columns.discNumber, Track.Columns.trackNumber)
                .fetchAll(db)
        }
    }

    /// Get tracks by genre
    func getTracksByGenre(_ genreId: Int64) throws -> [Track] {
        try dbQueue.read { db in
            let trackIds = try TrackGenre
                .filter(TrackGenre.Columns.genreId == genreId)
                .select(TrackGenre.Columns.trackId, as: Int64.self)
                .fetchAll(db)

            return try Track
                .filter(trackIds.contains(Track.Columns.trackId))
                .fetchAll(db)
        }
    }

    /// Get tracks by decade
    func getTracksByDecade(_ decade: Int) throws -> [Track] {
        try dbQueue.read { db in
            let startYear = String(decade)
            let endYear = String(decade + 9)

            return try Track
                .filter(Track.Columns.year >= startYear)
                .filter(Track.Columns.year <= endYear)
                .filter(Track.Columns.year != "")
                .filter(Track.Columns.year != "Unknown Year")
                .order(Track.Columns.year, Track.Columns.album)
                .fetchAll(db)
        }
    }

    /// Get decade statistics
    func getDecadeStats() throws -> [(decade: Int, count: Int)] {
        try dbQueue.read { db in
            // First, get all valid years
            let validYears = try Track
                .select(Track.Columns.year, as: String.self)
                .filter(Track.Columns.year != "")
                .filter(Track.Columns.year != "Unknown Year")
                .distinct()
                .fetchAll(db)

            // Group by decade
            var decadeStats: [Int: Int] = [:]

            for yearString in validYears {
                guard let year = Int(yearString), year > 0 else { continue }
                let decade = (year / 10) * 10

                let count = try Track
                    .filter(Track.Columns.year == yearString)
                    .fetchCount(db)

                decadeStats[decade, default: 0] += count
            }

            // Convert to array and sort
            return decadeStats
                .map { (decade: $0.key, count: $0.value) }
                .sorted { $0.decade > $1.decade }
        }
    }
}
