import Foundation
import GRDB

// MARK: - Database Setup Extension
extension DatabaseManager {
    // MARK: - Folders Table
    func createFoldersTable(in db: Database) throws {
        try db.create(table: "folders", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("path", .text).notNull().unique()
            t.column("track_count", .integer).notNull().defaults(to: 0)
            t.column("date_added", .datetime).notNull()
            t.column("date_updated", .datetime).notNull()
            t.column("bookmark_data", .blob)
        }
    }

    // MARK: - Artists Table
    func createArtistsTable(in db: Database) throws {
        try db.create(table: "artists", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("normalized_name", .text).notNull()
            t.column("sort_name", .text)
            t.column("artwork_data", .blob)

            // External API metadata
            t.column("bio", .text)
            t.column("bio_source", .text)
            t.column("bio_updated_at", .datetime)
            t.column("image_url", .text)
            t.column("image_source", .text)
            t.column("image_updated_at", .datetime)

            // External identifiers
            t.column("discogs_id", .text)
            t.column("musicbrainz_id", .text)
            t.column("spotify_id", .text)
            t.column("apple_music_id", .text)

            // Additional metadata
            t.column("country", .text)
            t.column("formed_year", .integer)
            t.column("disbanded_year", .integer)
            t.column("genres", .text) // JSON array
            t.column("websites", .text) // JSON array
            t.column("members", .text) // JSON array

            // Stats
            t.column("total_tracks", .integer).notNull().defaults(to: 0)
            t.column("total_albums", .integer).notNull().defaults(to: 0)

            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
    }

    // MARK: - Albums Table
    func createAlbumsTable(in db: Database) throws {
        try db.create(table: "albums", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("title", .text).notNull()
            t.column("normalized_title", .text).notNull()
            t.column("sort_title", .text)
            t.column("artist_id", .integer)
                .references("artists", onDelete: .setNull)
            t.column("artwork_data", .blob)

            // Album metadata
            t.column("release_date", .text)
            t.column("release_year", .integer)
            t.column("album_type", .text)
            t.column("total_tracks", .integer)
            t.column("total_discs", .integer)

            // External API metadata
            t.column("description", .text)
            t.column("review", .text)
            t.column("review_source", .text)
            t.column("cover_art_url", .text)
            t.column("thumbnail_url", .text)

            // External identifiers
            t.column("discogs_id", .text)
            t.column("musicbrainz_id", .text)
            t.column("spotify_id", .text)
            t.column("apple_music_id", .text)

            // Additional metadata
            t.column("label", .text)
            t.column("catalog_number", .text)
            t.column("barcode", .text)
            t.column("genres", .text) // JSON array

            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
    }

    // MARK: - Genres Table
    func createGenresTable(in db: Database) throws {
        try db.create(table: "genres", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull().unique()
        }
    }

    // MARK: - Tracks Table
    func createTracksTable(in db: Database) throws {
        try db.create(table: "tracks", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("folder_id", .integer).notNull()
                .references("folders", onDelete: .cascade)
            t.column("album_id", .integer)
                .references("albums", onDelete: .setNull)
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

            // Additional metadata
            t.column("album_artist", .text)
            t.column("track_number", .integer)
            t.column("total_tracks", .integer)
            t.column("disc_number", .integer)
            t.column("total_discs", .integer)
            t.column("rating", .integer)
            t.column("compilation", .boolean).defaults(to: false)
            t.column("release_date", .text)
            t.column("original_release_date", .text)
            t.column("bpm", .integer)
            t.column("media_type", .text)

            // Audio properties
            t.column("bitrate", .integer)
            t.column("sample_rate", .integer)
            t.column("channels", .integer)
            t.column("codec", .text)
            t.column("bit_depth", .integer)

            // Sort fields
            t.column("sort_title", .text)
            t.column("sort_artist", .text)
            t.column("sort_album", .text)
            t.column("sort_album_artist", .text)

            // Extended metadata as JSON
            t.column("extended_metadata", .text)
        }
    }

    // MARK: - Playlists Table
    func createPlaylistsTable(in db: Database) throws {
        try db.create(table: "playlists", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("type", .text).notNull()
            t.column("is_user_editable", .boolean).notNull()
            t.column("is_content_editable", .boolean).notNull()
            t.column("date_created", .datetime).notNull()
            t.column("date_modified", .datetime).notNull()
            t.column("cover_artwork_data", .blob)
            t.column("smart_criteria", .text)
            t.column("sort_order", .integer).notNull().defaults(to: 0)
        }
    }

    // MARK: - Playlist Tracks Table
    func createPlaylistTracksTable(in db: Database) throws {
        try db.create(table: "playlist_tracks", ifNotExists: true) { t in
            t.column("playlist_id", .text).notNull()
                .references("playlists", column: "id", onDelete: .cascade)
            t.column("track_id", .integer).notNull()
                .references("tracks", column: "id", onDelete: .cascade)
            t.column("position", .integer).notNull()
            t.column("date_added", .datetime).notNull()
            t.primaryKey(["playlist_id", "track_id"])
        }
    }

    // MARK: - Track Artists Junction Table
    func createTrackArtistsTable(in db: Database) throws {
        try db.create(table: "track_artists", ifNotExists: true) { t in
            t.column("track_id", .integer).notNull()
                .references("tracks", onDelete: .cascade)
            t.column("artist_id", .integer).notNull()
                .references("artists", onDelete: .cascade)
            t.column("role", .text).notNull().defaults(to: "artist")
            t.column("position", .integer).notNull().defaults(to: 0)
            t.primaryKey(["track_id", "artist_id", "role"])
        }
    }

    // MARK: - Track Genres Junction Table
    func createTrackGenresTable(in db: Database) throws {
        try db.create(table: "track_genres", ifNotExists: true) { t in
            t.column("track_id", .integer).notNull()
                .references("tracks", onDelete: .cascade)
            t.column("genre_id", .integer).notNull()
                .references("genres", onDelete: .cascade)
            t.primaryKey(["track_id", "genre_id"])
        }
    }
    
    // MARK: - Pinned Items Table
    func createPinnedItemsTable(in db: Database) throws {
        try db.create(table: "pinned_items", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("item_type", .text).notNull() // "library" or "playlist"
            t.column("filter_type", .text) // For library items: artists, albums, etc.
            t.column("filter_value", .text) // The specific artist/album name
            t.column("entity_id", .text) // UUID for entities (optional)
            t.column("artist_id", .integer) // Database ID for artist (optional)
            t.column("album_id", .integer) // Database ID for album (optional)
            t.column("playlist_id", .text) // For playlist items
            t.column("display_name", .text).notNull()
            t.column("subtitle", .text) // For albums, shows artist name
            t.column("icon_name", .text).notNull()
            t.column("sort_order", .integer).notNull().defaults(to: 0)
            t.column("date_added", .datetime).notNull()
        }
    }

    // MARK: - Create All Indices
    func createIndices(in db: Database) throws {
        // Tracks table indices
        try db.create(index: "idx_tracks_folder_id", on: "tracks", columns: ["folder_id"], ifNotExists: true)
        try db.create(index: "idx_tracks_album_id", on: "tracks", columns: ["album_id"], ifNotExists: true)
        try db.create(index: "idx_tracks_artist", on: "tracks", columns: ["artist"], ifNotExists: true)
        try db.create(index: "idx_tracks_album", on: "tracks", columns: ["album"], ifNotExists: true)
        try db.create(index: "idx_tracks_composer", on: "tracks", columns: ["composer"], ifNotExists: true)
        try db.create(index: "idx_tracks_genre", on: "tracks", columns: ["genre"], ifNotExists: true)
        try db.create(index: "idx_tracks_year", on: "tracks", columns: ["year"], ifNotExists: true)
        try db.create(index: "idx_tracks_album_artist", on: "tracks", columns: ["album_artist"], ifNotExists: true)
        try db.create(index: "idx_tracks_rating", on: "tracks", columns: ["rating"], ifNotExists: true)
        try db.create(index: "idx_tracks_compilation", on: "tracks", columns: ["compilation"], ifNotExists: true)
        try db.create(index: "idx_tracks_media_type", on: "tracks", columns: ["media_type"], ifNotExists: true)

        // Artists table indices
        try db.create(index: "idx_artists_normalized_name", on: "artists", columns: ["normalized_name"], ifNotExists: true)

        // Albums table indices
        try db.create(index: "idx_albums_normalized_title", on: "albums", columns: ["normalized_title"], ifNotExists: true)
        try db.create(index: "idx_albums_artist_id", on: "albums", columns: ["artist_id"], ifNotExists: true)
        try db.create(index: "idx_albums_release_year", on: "albums", columns: ["release_year"], ifNotExists: true)

        // Playlist tracks index
        try db.create(index: "idx_playlist_tracks_playlist_id", on: "playlist_tracks", columns: ["playlist_id"], ifNotExists: true)

        // Junction table indices
        try db.create(index: "idx_track_artists_artist_id", on: "track_artists", columns: ["artist_id"], ifNotExists: true)
        try db.create(index: "idx_track_artists_track_id", on: "track_artists", columns: ["track_id"], ifNotExists: true)
        try db.create(index: "idx_track_genres_genre_id", on: "track_genres", columns: ["genre_id"], ifNotExists: true)
        
        // Pinned items indices
        try db.create(index: "idx_pinned_items_sort_order", on: "pinned_items", columns: ["sort_order"], ifNotExists: true)
        try db.create(index: "idx_pinned_items_item_type", on: "pinned_items", columns: ["item_type"], ifNotExists: true)
    }
    
    // MARK: - Seed Default Data
    func seedDefaultPlaylists(in db: Database) throws {
        // Check if playlists table is empty (first time setup)
        let playlistCount = try Playlist.fetchCount(db)
        
        if playlistCount == 0 {
            print("DatabaseManager: Seeding default smart playlists...")
            
            let defaultPlaylists = Playlist.createDefaultSmartPlaylists()
            
            for playlist in defaultPlaylists {
                try playlist.insert(db)
                print("DatabaseManager: Created default playlist: \(playlist.name)")
            }
        }
    }
}
