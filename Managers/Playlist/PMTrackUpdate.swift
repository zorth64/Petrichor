import Foundation
import GRDB

extension PlaylistManager {
    // MARK: - Track Updates
    
    func updateTrackFavoriteStatus(track: Track, isFavorite: Bool) async {
        guard let trackId = track.trackId else {
            Logger.error("Cannot update favorite - track has no database ID")
            return
        }

        // Update track object
        await MainActor.run {
            track.isFavorite = isFavorite
        }

        do {
            if let dbManager = libraryManager?.databaseManager {
                try await dbManager.updateTrackFavoriteStatus(trackId: trackId, isFavorite: isFavorite)

                // Update library manager's track FIRST
                await MainActor.run {
                    if let libraryTrack = self.libraryManager?.tracks.first(where: { $0.trackId == trackId }) {
                        libraryTrack.isFavorite = isFavorite
                        Logger.info("Updated library track favorite status")
                    }
                }

                Logger.info("Updated favorite status for track: \(track.title) to \(isFavorite)")
                
                // THEN update smart playlists
                await handleTrackPropertyUpdate(track)
            }
        } catch {
            Logger.error("Failed to update favorite status: \(error)")
            // Revert change
            await MainActor.run {
                track.isFavorite = !isFavorite
            }
        }
    }

    /// Add or remove a track from any playlist (handles both regular and smart playlists)
    func updateTrackInPlaylist(track: Track, playlist: Playlist, add: Bool) {
        Task {
            do {
                guard libraryManager?.databaseManager != nil else { return }

                // Handle smart playlists differently
                if playlist.type == .smart {
                    // For smart playlists, we update the track property that controls membership
                    if playlist.name == DefaultPlaylists.favorites && !playlist.isUserEditable {
                        // Update favorite status
                        await updateTrackFavoriteStatus(track: track, isFavorite: add)
                    } else if playlist.type == .smart && !playlist.isContentEditable {
                        // Other smart playlists are read-only
                        Logger.warning("Cannot manually add/remove tracks from \(playlist.name)")
                        return
                    }
                } else {
                    // Regular playlist - directly add/remove
                    if add {
                        await addTrackToRegularPlaylist(track: track, playlistID: playlist.id)
                    } else {
                        await removeTrackFromRegularPlaylist(track: track, playlistID: playlist.id)
                    }
                }

                // Update smart playlists to reflect any changes
                if playlist.type == .smart {
                    await MainActor.run {
                        self.updateSmartPlaylists()
                    }
                }
            }
        }
    }

    /// Add multiple tracks to a playlist at once
    @MainActor
    func addTracksToPlaylist(tracks: [Track], playlistID: UUID) {
        Task {
            guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
                  playlists[index].type == .regular,
                  playlists[index].isContentEditable else {
                Logger.warning("Cannot add to this playlist")
                return
            }

            var updatedPlaylist = playlists[index]
            var tracksAdded = 0

            // Add all tracks that aren't already in the playlist
            for track in tracks {
                if !updatedPlaylist.tracks.contains(where: { $0.trackId == track.trackId }) {
                    updatedPlaylist.addTrack(track)
                    tracksAdded += 1
                }
            }

            if tracksAdded > 0 {
                // Update in-memory
                playlists[index] = updatedPlaylist

                // Save to database once
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(updatedPlaylist)
                        Logger.info("Added \(tracksAdded) tracks to playlist")
                    }
                } catch {
                    Logger.error("Failed to save playlist: \(error)")
                    // Revert changes
                    if let dbManager = libraryManager?.databaseManager {
                        let savedPlaylists = dbManager.loadAllPlaylists()
                        if let originalPlaylist = savedPlaylists.first(where: { $0.id == playlistID }) {
                            playlists[index] = originalPlaylist
                        }
                    }
                }
            }

            // Update smart playlists if needed
            updateSmartPlaylists()
        }
    }

    /// Remove multiple tracks from a playlist at once
    @MainActor
    func removeTracksFromPlaylist(tracks: [Track], playlistID: UUID) {
        Task {
            guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
                  playlists[index].type == .regular,
                  playlists[index].isContentEditable else {
                Logger.warning("Cannot remove from this playlist")
                return
            }

            var updatedPlaylist = playlists[index]
            var tracksRemoved = 0

            // Remove all specified tracks from the playlist
            for track in tracks {
                if updatedPlaylist.tracks.contains(where: { $0.trackId == track.trackId }) {
                    updatedPlaylist.removeTrack(track)  // Pass the track object, not the index
                    tracksRemoved += 1
                }
            }

            if tracksRemoved > 0 {
                // Update in-memory
                playlists[index] = updatedPlaylist

                // Save to database once
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(updatedPlaylist)
                        Logger.info("Removed \(tracksRemoved) tracks from playlist")
                    }
                } catch {
                    Logger.error("Failed to save playlist: \(error)")
                    // Revert changes
                    if let dbManager = libraryManager?.databaseManager {
                        let savedPlaylists = dbManager.loadAllPlaylists()
                        if let originalPlaylist = savedPlaylists.first(where: { $0.id == playlistID }) {
                            playlists[index] = originalPlaylist
                        }
                    }
                }
            }

            // Update smart playlists if needed
            updateSmartPlaylists()
        }
    }

    /// Toggle a track's membership in a playlist
    func toggleTrackInPlaylist(track: Track, playlist: Playlist) {
        let isInPlaylist = playlist.tracks.contains { $0.trackId == track.trackId }
        updateTrackInPlaylist(track: track, playlist: playlist, add: !isInPlaylist)
    }

    /// Check if a track is in a playlist
    func isTrackInPlaylist(track: Track, playlist: Playlist) -> Bool {
        playlist.tracks.contains { $0.trackId == track.trackId }
    }
    
    /// Update track properties that may affect smart playlist membership
    func handleTrackPropertyUpdate(_ track: Track) async {
        await MainActor.run {
            // Only update playlists affected by this specific track
            self.updateSmartPlaylistsForTrack(track)
        }
    }

    /// Update track play count and last played date
    func incrementPlayCount(for track: Track) {
        // These modifications should be on main thread
        Task { @MainActor in
            track.playCount += 1
            track.lastPlayedDate = Date()
            
            guard let trackId = track.trackId else { return }
            
            // Continue with the async work
            Task {
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.updateTrackPlayInfo(
                            trackId: trackId,
                            playCount: track.playCount,
                            lastPlayedDate: track.lastPlayedDate!
                        )

                        // Update smart playlists after play info changes
                        await handleTrackPropertyUpdate(track)
                    }
                } catch {
                    Logger.error("Failed to update play info: \(error)")
                    await MainActor.run {
                        track.playCount -= 1
                        track.lastPlayedDate = nil
                    }
                }
            }
        }
    }
}
