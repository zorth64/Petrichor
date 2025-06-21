import Foundation
import GRDB

extension DatabaseManager {
    // MARK: - Filter Type Queries (Used by LibraryManager)

    /// Get distinct values for a filter type using normalized tables
    func getDistinctValues(for filterType: LibraryFilterType) -> [String] {
        do {
            return try dbQueue.read { db in
                switch filterType {
                case .artists, .albumArtists, .composers:
                    // Get from normalized artists table
                    let artists = try Artist
                        .select(Artist.Columns.name, as: String.self)
                        .order(Artist.Columns.sortName)
                        .fetchAll(db)

                    // Add "Unknown" placeholder if there are tracks without artists
                    var results = artists
                    if try Track.filter(Track.Columns.artist == filterType.unknownPlaceholder).fetchCount(db) > 0 {
                        results.append(filterType.unknownPlaceholder)
                    }
                    return results

                case .albums:
                    // Get from normalized albums table
                    let albums = try Album
                        .select(Album.Columns.title, as: String.self)
                        .order(Album.Columns.sortTitle)
                        .fetchAll(db)

                    // Add "Unknown Album" if needed
                    var results = albums
                    if try Track.filter(Track.Columns.album == "Unknown Album").fetchCount(db) > 0 {
                        results.append("Unknown Album")
                    }
                    return results

                case .genres:
                    // Get from normalized genres table
                    let genres = try Genre
                        .select(Genre.Columns.name, as: String.self)
                        .order(Genre.Columns.name)
                        .fetchAll(db)

                    // Add "Unknown Genre" if needed
                    var results = genres
                    if try Track.filter(Track.Columns.genre == "Unknown Genre").fetchCount(db) > 0 {
                        results.append("Unknown Genre")
                    }
                    return results

                case .years:
                    // Years don't have a normalized table, use tracks directly
                    return try Track
                        .select(Track.Columns.year, as: String.self)
                        .filter(Track.Columns.year != "")
                        .distinct()
                        .order(Track.Columns.year.desc)
                        .fetchAll(db)
                }
            }
        } catch {
            print("Failed to get distinct values for \(filterType): \(error)")
            return []
        }
    }

    /// Get tracks by filter type and value using normalized tables
    func getTracksByFilterType(_ filterType: LibraryFilterType, value: String) -> [Track] {
        do {
            return try dbQueue.read { db in
                switch filterType {
                case .artists, .albumArtists, .composers:
                    // Handle unknown placeholder
                    if value == filterType.unknownPlaceholder {
                        return try Track
                            .filter(Track.columnMap[filterType.databaseColumn]! == value)
                            .fetchAll(db)
                    }

                    // Find artist by exact name
                    guard let artist = try Artist
                        .filter(Artist.Columns.name == value)
                        .fetchOne(db),
                          let artistId = artist.id else {
                        return []
                    }

                    // Determine role based on filter type
                    let role: String = {
                        switch filterType {
                        case .artists: return TrackArtist.Role.artist
                        case .composers: return TrackArtist.Role.composer
                        case .albumArtists: return TrackArtist.Role.albumArtist
                        default: return TrackArtist.Role.artist
                        }
                    }()

                    // Get track IDs for this artist and role
                    let trackIds = try TrackArtist
                        .filter(TrackArtist.Columns.artistId == artistId)
                        .filter(TrackArtist.Columns.role == role)
                        .select(TrackArtist.Columns.trackId, as: Int64.self)
                        .fetchAll(db)

                    return try Track
                        .filter(trackIds.contains(Track.Columns.trackId))
                        .fetchAll(db)

                case .albums:
                    if value == "Unknown Album" {
                        return try Track
                            .filter(Track.Columns.album == value)
                            .fetchAll(db)
                    }

                    // Find album by exact title
                    guard let album = try Album
                        .filter(Album.Columns.title == value)
                        .fetchOne(db),
                          let albumId = album.id else {
                        return []
                    }

                    return try Track
                        .filter(Track.Columns.albumId == albumId)
                        .order(Track.Columns.discNumber, Track.Columns.trackNumber)
                        .fetchAll(db)

                case .genres:
                    if value == "Unknown Genre" {
                        return try Track
                            .filter(Track.Columns.genre == value)
                            .fetchAll(db)
                    }

                    // Find genre by name
                    guard let genre = try Genre
                        .filter(Genre.Columns.name == value)
                        .fetchOne(db),
                          let genreId = genre.id else {
                        return []
                    }

                    // Get track IDs for this genre
                    let trackIds = try TrackGenre
                        .filter(TrackGenre.Columns.genreId == genreId)
                        .select(TrackGenre.Columns.trackId, as: Int64.self)
                        .fetchAll(db)

                    return try Track
                        .filter(trackIds.contains(Track.Columns.trackId))
                        .fetchAll(db)

                case .years:
                    return try Track
                        .filter(Track.Columns.year == value)
                        .order(Track.Columns.album, Track.Columns.trackNumber)
                        .fetchAll(db)
                }
            }
        } catch {
            print("Failed to get tracks by filter type: \(error)")
            return []
        }
    }

    /// Get tracks where the filter value is contained (for multi-artist parsing)
    func getTracksByFilterTypeContaining(_ filterType: LibraryFilterType, value: String) -> [Track] {
        do {
            return try dbQueue.read { db in
                // This is specifically for multi-artist fields
                guard filterType.usesMultiArtistParsing else {
                    return getTracksByFilterType(filterType, value: value)
                }

                // Find the artist (handles normalized name matching)
                let normalizedSearchName = ArtistParser.normalizeArtistName(value)

                guard let artist = try Artist
                    .filter((Artist.Columns.name == value) || (Artist.Columns.normalizedName == normalizedSearchName))
                    .fetchOne(db),
                    let artistId = artist.id else {
                    return []
                }

                // Get all tracks for this artist (any role)
                let trackIds = try TrackArtist
                    .filter(TrackArtist.Columns.artistId == artistId)
                    .select(TrackArtist.Columns.trackId, as: Int64.self)
                    .fetchAll(db)

                return try Track
                    .filter(trackIds.contains(Track.Columns.trackId))
                    .fetchAll(db)
            }
        } catch {
            print("Failed to get tracks by filter type containing: \(error)")
            return []
        }
    }

    // MARK: - Entity Queries (for Home tab)

    /// Get all artist entities without loading tracks
    func getArtistEntities() -> [ArtistEntity] {
        do {
            return try dbQueue.read { db in
                let artists = try Artist
                    .filter(Artist.Columns.totalTracks > 0)
                    .order(Artist.Columns.sortName)
                    .fetchAll(db)

                return artists.map { artist in
                    ArtistEntity(
                        name: artist.name,
                        trackCount: artist.totalTracks,
                        artworkData: artist.artworkData
                    )
                }
            }
        } catch {
            print("Failed to get artist entities: \(error)")
            return []
        }
    }

    /// Get all album entities without loading tracks
    func getAlbumEntities() -> [AlbumEntity] {
        do {
            return try dbQueue.read { db in
                let albums = try Album
                    .filter(Album.Columns.totalTracks > 0)
                    .order(Album.Columns.sortTitle)
                    .fetchAll(db)

                return albums.map { album in
                    // Fetch artist name if artistId exists
                    var artistName: String?
                    if let artistId = album.artistId {
                        artistName = try? Artist
                            .filter(Artist.Columns.id == artistId)
                            .fetchOne(db)?.name
                    }

                    return AlbumEntity(
                        name: album.title,
                        artist: artistName,
                        trackCount: album.totalTracks ?? 0,
                        artworkData: album.artworkData,
                        albumId: album.id
                    )
                }
            }
        } catch {
            print("Failed to get album entities: \(error)")
            return []
        }
    }

    /// Get tracks for a specific artist entity
    func getTracksForArtistEntity(_ artistName: String) -> [Track] {
        do {
            return try dbQueue.read { db in
                // First find the artist
                let normalizedName = ArtistParser.normalizeArtistName(artistName)
                guard let artist = try Artist
                    .filter((Artist.Columns.name == artistName) || (Artist.Columns.normalizedName == normalizedName))
                    .fetchOne(db),
                    let artistId = artist.id else {
                    return []
                }
                
                // Get all track IDs for this artist
                let trackIds = try TrackArtist
                    .filter(TrackArtist.Columns.artistId == artistId)
                    .select(TrackArtist.Columns.trackId, as: Int64.self)
                    .fetchAll(db)
                
                // Fetch the tracks
                return try Track
                    .filter(trackIds.contains(Track.Columns.trackId))
                    .order(Track.Columns.album, Track.Columns.trackNumber)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to get tracks for artist entity: \(error)")
            return []
        }
    }

    /// Get tracks for a specific album entity using album ID
    func getTracksForAlbumEntity(_ albumEntity: AlbumEntity) -> [Track] {
        do {
            return try dbQueue.read { db in
                // If we have the album ID, use it directly - this is the most reliable way
                if let albumId = albumEntity.albumId {
                    return try Track
                        .filter(Track.Columns.albumId == albumId)
                        .order(Track.Columns.discNumber, Track.Columns.trackNumber)
                        .fetchAll(db)
                }
                
                // Fallback to name-based search if no ID (shouldn't happen with new code)
                let normalizedTitle = albumEntity.name.lowercased()
                    .replacingOccurrences(of: "the ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                var query = Album
                    .filter(Album.Columns.normalizedTitle == normalizedTitle)
                
                // If artist is provided, use it to narrow down the search
                if let artistName = albumEntity.artist {
                    let normalizedArtistName = ArtistParser.normalizeArtistName(artistName)
                    if let artist = try Artist
                        .filter((Artist.Columns.name == artistName) || (Artist.Columns.normalizedName == normalizedArtistName))
                        .fetchOne(db),
                        let artistId = artist.id {
                        query = query.filter(Album.Columns.artistId == artistId)
                    }
                }
                
                guard let album = try query.fetchOne(db),
                      let albumId = album.id else {
                    print("No album found for entity: \(albumEntity.name)")
                    return []
                }
                
                // Get tracks for this album
                return try Track
                    .filter(Track.Columns.albumId == albumId)
                    .order(Track.Columns.discNumber, Track.Columns.trackNumber)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to get tracks for album entity: \(error)")
            return []
        }
    }

    // MARK: - Quick Count Methods

    func getArtistCount() -> Int {
        do {
            return try dbQueue.read { db in
                try Artist
                    .filter(Artist.Columns.totalTracks > 0)
                    .fetchCount(db)
            }
        } catch {
            print("Failed to get artist count: \(error)")
            return 0
        }
    }

    func getAlbumCount() -> Int {
        do {
            return try dbQueue.read { db in
                try Album
                    .filter(Album.Columns.totalTracks > 0)
                    .fetchCount(db)
            }
        } catch {
            print("Failed to get album count: \(error)")
            return 0
        }
    }

    // MARK: - Library Filter Items

    /// Get artist filter items with counts
    func getArtistFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let artists = try Artist
                    .order(Artist.Columns.sortName)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for artist in artists {
                    guard let artistId = artist.id else { continue }

                    let trackCount = try TrackArtist
                        .filter(TrackArtist.Columns.artistId == artistId)
                        .filter(TrackArtist.Columns.role == TrackArtist.Role.artist)
                        .select(TrackArtist.Columns.trackId, as: Int64.self)
                        .distinct()
                        .fetchCount(db)

                    if trackCount > 0 {
                        items.append(LibraryFilterItem(
                            name: artist.name,
                            count: trackCount,
                            filterType: .artists
                        ))
                    }
                }

                // Add unknown placeholder if needed
                let unknownCount = try Track
                    .filter(Track.Columns.artist == "Unknown Artist")
                    .fetchCount(db)

                if unknownCount > 0 {
                    items.append(LibraryFilterItem(
                        name: "Unknown Artist",
                        count: unknownCount,
                        filterType: .artists
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get artist filter items: \(error)")
            return []
        }
    }

    /// Get album artist filter items with counts
    func getAlbumArtistFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let artists = try Artist
                    .order(Artist.Columns.sortName)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for artist in artists {
                    guard let artistId = artist.id else { continue }

                    let trackCount = try TrackArtist
                        .filter(TrackArtist.Columns.artistId == artistId)
                        .filter(TrackArtist.Columns.role == TrackArtist.Role.albumArtist)
                        .select(TrackArtist.Columns.trackId, as: Int64.self)
                        .distinct()
                        .fetchCount(db)

                    if trackCount > 0 {
                        items.append(LibraryFilterItem(
                            name: artist.name,
                            count: trackCount,
                            filterType: .albumArtists
                        ))
                    }
                }

                // Add unknown placeholder if needed
                let unknownCount = try Track
                    .filter(Track.Columns.albumArtist == "Unknown Album Artist")
                    .fetchCount(db)

                if unknownCount > 0 {
                    items.append(LibraryFilterItem(
                        name: "Unknown Album Artist",
                        count: unknownCount,
                        filterType: .albumArtists
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get album artist filter items: \(error)")
            return []
        }
    }

    /// Get composer filter items with counts
    func getComposerFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let composers = try Artist
                    .order(Artist.Columns.sortName)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for composer in composers {
                    guard let composerId = composer.id else { continue }

                    let trackCount = try TrackArtist
                        .filter(TrackArtist.Columns.artistId == composerId)
                        .filter(TrackArtist.Columns.role == TrackArtist.Role.composer)
                        .select(TrackArtist.Columns.trackId, as: Int64.self)
                        .distinct()
                        .fetchCount(db)

                    if trackCount > 0 {
                        items.append(LibraryFilterItem(
                            name: composer.name,
                            count: trackCount,
                            filterType: .composers
                        ))
                    }
                }

                // Add unknown placeholder if needed
                let unknownCount = try Track
                    .filter(Track.Columns.composer == "Unknown Composer")
                    .fetchCount(db)

                if unknownCount > 0 {
                    items.append(LibraryFilterItem(
                        name: "Unknown Composer",
                        count: unknownCount,
                        filterType: .composers
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get composer filter items: \(error)")
            return []
        }
    }

    /// Get album filter items with counts
    func getAlbumFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let albums = try Album
                    .order(Album.Columns.sortTitle)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for album in albums {
                    guard let albumId = album.id else { continue }

                    let trackCount = try Track
                        .filter(Track.Columns.albumId == albumId)
                        .fetchCount(db)

                    if trackCount > 0 {
                        items.append(LibraryFilterItem(
                            name: album.title,
                            count: trackCount,
                            filterType: .albums
                        ))
                    }
                }

                // Add unknown album if needed
                let unknownCount = try Track
                    .filter(Track.Columns.album == "Unknown Album")
                    .filter(Track.Columns.albumId == nil)
                    .fetchCount(db)

                if unknownCount > 0 {
                    items.append(LibraryFilterItem(
                        name: "Unknown Album",
                        count: unknownCount,
                        filterType: .albums
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get album filter items: \(error)")
            return []
        }
    }

    /// Get genre filter items with counts
    func getGenreFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let genres = try Genre
                    .order(Genre.Columns.name)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for genre in genres {
                    guard let genreId = genre.id else { continue }

                    let trackCount = try TrackGenre
                        .filter(TrackGenre.Columns.genreId == genreId)
                        .select(TrackGenre.Columns.trackId, as: Int64.self)
                        .distinct()
                        .fetchCount(db)

                    if trackCount > 0 {
                        items.append(LibraryFilterItem(
                            name: genre.name,
                            count: trackCount,
                            filterType: .genres
                        ))
                    }
                }

                // Add unknown genre if needed
                let unknownCount = try Track
                    .filter(Track.Columns.genre == "Unknown Genre")
                    .fetchCount(db)

                if unknownCount > 0 {
                    items.append(LibraryFilterItem(
                        name: "Unknown Genre",
                        count: unknownCount,
                        filterType: .genres
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get genre filter items: \(error)")
            return []
        }
    }

    /// Get year filter items with counts
    func getYearFilterItems() -> [LibraryFilterItem] {
        do {
            return try dbQueue.read { db in
                let years = try Track
                    .select(Track.Columns.year, as: String.self)
                    .filter(Track.Columns.year != "")
                    .filter(Track.Columns.year != "Unknown Year")
                    .distinct()
                    .order(Track.Columns.year.desc)
                    .fetchAll(db)

                var items: [LibraryFilterItem] = []

                for year in years {
                    let count = try Track
                        .filter(Track.Columns.year == year)
                        .fetchCount(db)

                    items.append(LibraryFilterItem(
                        name: year,
                        count: count,
                        filterType: .years
                    ))
                }

                return items
            }
        } catch {
            print("Failed to get year filter items: \(error)")
            return []
        }
    }

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
    
    /// Get artist ID by name
    func getArtistId(for artistName: String) -> Int64? {
        do {
            return try dbQueue.read { db in
                let normalizedName = ArtistParser.normalizeArtistName(artistName)
                return try Artist
                    .filter((Artist.Columns.name == artistName) || (Artist.Columns.normalizedName == normalizedName))
                    .fetchOne(db)?
                    .id
            }
        } catch {
            print("DatabaseManager: Failed to get artist ID: \(error)")
            return nil
        }
    }
}
