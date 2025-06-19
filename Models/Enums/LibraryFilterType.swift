import Foundation

enum LibraryFilterType: String, CaseIterable {
    case artists = "Artists"
    case albums = "Albums"
    case albumArtists = "Album Artists"
    case composers = "Composers"
    case genres = "Genres"
    case years = "Years"

    // MARK: - Computed Props

    var databaseColumn: String {
        switch self {
        case .artists: return "artist"
        case .albums: return "album"
        case .albumArtists: return "album_artist"
        case .composers: return "composer"
        case .genres: return "genre"
        case .years: return "year"
        }
    }

    var stableIndex: Int {
        switch self {
        case .artists: return 0
        case .albums: return 1
        case .albumArtists: return 2
        case .composers: return 3
        case .genres: return 4
        case .years: return 5
        }
    }

    var unknownPlaceholder: String {
        switch self {
        case .artists: return "Unknown Artist"
        case .albums: return "Unknown Album"
        case .albumArtists: return "Unknown Album Artist"
        case .composers: return "Unknown Composer"
        case .genres: return "Unknown Genre"
        case .years: return "Unknown Year"
        }
    }

    var singularDisplayName: String {
        switch self {
        case .artists: return "Artist"
        case .albums: return "Album"
        case .albumArtists: return "Album Artist"
        case .composers: return "Composer"
        case .genres: return "Genre"
        case .years: return "Year"
        }
    }

    var allItemIcon: String {
        switch self {
        case .artists: return "person.2.fill"
        case .albums: return "opticaldisc.fill"
        case .albumArtists: return "person.2.crop.square.stack.fill"
        case .composers: return "person.2.wave.2.fill"
        case .genres: return "music.note.list"
        case .years: return "calendar.circle.fill"
        }
    }

    var icon: String {
        switch self {
        case .artists: return "person.fill"
        case .albums: return "opticaldisc.fill"
        case .albumArtists: return "person.2.crop.square.stack.fill"
        case .composers: return "person.wave.2.fill"
        case .genres: return "music.note.list"
        case .years: return "calendar"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .artists: return "No artists found in your library"
        case .albums: return "No albums found in your library"
        case .albumArtists: return "No album artists found in your library"
        case .composers: return "No composers found in your library"
        case .genres: return "No genres found in your library"
        case .years: return "No release years found in your library"
        }
    }

    var usesMultiArtistParsing: Bool {
        switch self {
        case .artists, .albumArtists, .composers: return true
        default: return false
        }
    }

    // MARK: - Methods

    func getValue(from track: Track) -> String {
        switch self {
        case .artists: return track.artist
        case .albums: return track.album
        case .albumArtists: return track.albumArtist ?? ""
        case .composers: return track.composer
        case .genres: return track.genre
        case .years: return track.year
        }
    }

    func getFilterItems(from tracks: [Track]) -> [LibraryFilterItem] {
        if usesMultiArtistParsing {
            // Multi-artist parsing with deduplication
            var normalizedToArtistInfo: [String: (displayName: String, tracks: Set<Track>)] = [:]

            for track in tracks {
                let value = getValue(from: track)
                let artists = ArtistParser.parse(value, unknownPlaceholder: unknownPlaceholder)

                for artist in artists {
                    let normalizedName = ArtistParser.normalizeArtistName(artist)

                    if var existing = normalizedToArtistInfo[normalizedName] {
                        // Add track to existing artist
                        existing.tracks.insert(track)

                        // Keep the "better" display name (usually longer with more formatting)
                        if artist.count > existing.displayName.count {
                            existing.displayName = artist
                        }

                        normalizedToArtistInfo[normalizedName] = existing
                    } else {
                        // New artist
                        normalizedToArtistInfo[normalizedName] = (displayName: artist, tracks: [track])
                    }
                }
            }

            // Convert to filter items using the best display name
            return normalizedToArtistInfo.map { _, info in
                LibraryFilterItem(name: info.displayName, count: info.tracks.count, filterType: self)
            }
        } else {
            // Generic handling (unchanged)
            var itemCounts: [String: Int] = [:]

            for track in tracks {
                let value = getValue(from: track)
                let normalizedValue = value.isEmpty ? unknownPlaceholder : value
                itemCounts[normalizedValue, default: 0] += 1
            }

            return itemCounts.map { name, count in
                LibraryFilterItem(name: name, count: count, filterType: self)
            }
        }
    }

    func trackMatches(_ track: Track, filterValue: String) -> Bool {
        if usesMultiArtistParsing && filterValue != unknownPlaceholder {
            // Multi-artist parsing with normalization
            let value = getValue(from: track)
            let artists = ArtistParser.parse(value, unknownPlaceholder: unknownPlaceholder)

            // Check if any parsed artist matches the filter value
            return artists.contains { artist in
                artist == filterValue || ArtistParser.normalizeArtistName(artist) == ArtistParser.normalizeArtistName(filterValue)
            }
        } else if filterValue == unknownPlaceholder {
            // Handle unknown values
            let value = getValue(from: track)
            return value.isEmpty || value == unknownPlaceholder
        } else {
            // Exact match
            let value = getValue(from: track)
            return value == filterValue
        }
    }
}

struct LibraryFilterRequest: Equatable {
    let filterType: LibraryFilterType
    let value: String
}
