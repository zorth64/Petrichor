import Foundation
import GRDB

extension DatabaseManager {
    func savePlaylistAsync(_ playlist: Playlist) async throws {
        try await dbQueue.write { db in
            // Save the playlist using GRDB's save method
            try playlist.save(db)
            
            // Delete existing track associations
            try PlaylistTrack
                .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                .deleteAll(db)
            
            let deletedCount = db.changesCount
            Logger.info("Deleted \(deletedCount) existing track associations")
            
            // Batch insert track associations for regular playlists
            if playlist.type == .regular && !playlist.tracks.isEmpty {
                Logger.info("Saving \(playlist.tracks.count) tracks for playlist '\(playlist.name)'")
                
                // Create all PlaylistTrack objects at once
                let playlistTracks = playlist.tracks.enumerated().compactMap { index, track -> PlaylistTrack? in
                    guard let trackId = track.trackId else {
                        Logger.warning("Track '\(track.title)' has no database ID, skipping")
                        return nil
                    }
                    
                    return PlaylistTrack(
                        playlistId: playlist.id.uuidString,
                        trackId: trackId,
                        position: index,
                        dateAdded: Date()
                    )
                }
                
                // Batch insert all tracks at once
                if !playlistTracks.isEmpty {
                    try PlaylistTrack.insertMany(playlistTracks, db: db)
                    Logger.info("Batch inserted \(playlistTracks.count) tracks to playlist")
                }
                
                // Verify the save
                let savedCount = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                    .fetchCount(db)
                
                Logger.info("Verified \(savedCount) tracks saved for playlist in database")
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
            Logger.info("Deleted \(deletedCount) existing track associations")
            
            // Batch insert track associations for regular playlists
            if playlist.type == .regular && !playlist.tracks.isEmpty {
                Logger.info("Saving \(playlist.tracks.count) tracks for playlist '\(playlist.name)'")
                
                // Create all PlaylistTrack objects at once
                let playlistTracks = playlist.tracks.enumerated().compactMap { index, track -> PlaylistTrack? in
                    guard let trackId = track.trackId else {
                        Logger.warning("Track '\(track.title)' has no database ID, skipping")
                        return nil
                    }
                    
                    return PlaylistTrack(
                        playlistId: playlist.id.uuidString,
                        trackId: trackId,
                        position: index,
                        dateAdded: Date()
                    )
                }
                
                // Batch insert all tracks at once
                if !playlistTracks.isEmpty {
                    try PlaylistTrack.insertMany(playlistTracks, db: db)
                    Logger.info("Batch inserted \(playlistTracks.count) tracks to playlist")
                }
                
                // Verify the save
                let savedCount = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlist.id.uuidString)
                    .fetchCount(db)
                
                Logger.info("Verified \(savedCount) tracks saved for playlist in database")
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
            Logger.error("Failed to load playlists: \(error)")
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
    
    /// Add a single track to a playlist without rebuilding entire playlist
    func addTrackToPlaylist(playlistId: UUID, track: Track) async -> Bool {
        guard let trackId = track.trackId else {
            Logger.error("Cannot add track - no database ID")
            return false
        }
        
        do {
            try await dbQueue.write { db in
                // Get current max position
                let maxPosition = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlistId.uuidString)
                    .select(max(PlaylistTrack.Columns.position))
                    .fetchOne(db) ?? -1
                
                // Insert new track at the end
                let playlistTrack = PlaylistTrack(
                    playlistId: playlistId.uuidString,
                    trackId: trackId,
                    position: maxPosition + 1,
                    dateAdded: Date()
                )
                
                try playlistTrack.insert(db)
                Logger.info("Added single track to playlist")
            }
            return true
        } catch {
            Logger.error("Failed to add track to playlist: \(error)")
            return false
        }
    }
    
    /// Remove a single track from a playlist without rebuilding
    func removeTrackFromPlaylist(playlistId: UUID, trackId: Int64) async -> Bool {
        do {
            try await dbQueue.write { db in
                let deleted = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlistId.uuidString)
                    .filter(PlaylistTrack.Columns.trackId == trackId)
                    .deleteAll(db)
                
                Logger.info("Removed \(deleted) track from playlist")
                
                // Reorder remaining tracks to close the gap
                let remainingTracks = try PlaylistTrack
                    .filter(PlaylistTrack.Columns.playlistId == playlistId.uuidString)
                    .order(PlaylistTrack.Columns.position)
                    .fetchAll(db)
                
                // Update positions
                for (index, track) in remainingTracks.enumerated() {
                    try db.execute(
                        sql: "UPDATE playlist_tracks SET position = ? WHERE playlist_id = ? AND track_id = ?",
                        arguments: [index, track.playlistId, track.trackId]
                    )
                }
            }
            return true
        } catch {
            Logger.error("Failed to remove track from playlist: \(error)")
            return false
        }
    }
}
