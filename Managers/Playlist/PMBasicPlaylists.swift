import Foundation

extension PlaylistManager {
    // MARK: - Basic Playlist Management
    
    /// Create a new basic playlist
    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        let newPlaylist = Playlist(name: name, tracks: tracks)
        playlists.append(newPlaylist)
        
        // Save to database
        Task {
            do {
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.savePlaylistAsync(newPlaylist)
                }
            } catch {
                print("PlaylistManager: Failed to save new playlist: \(error)")
            }
        }
        
        return newPlaylist
    }
    
    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        // Only allow deletion of user-editable playlists
        guard playlist.isUserEditable else {
            print("PlaylistManager: Cannot delete system playlist: \(playlist.name)")
            return
        }
        
        // Remove from memory
        playlists.removeAll { $0.id == playlist.id }
        
        // Remove from database
        Task {
            do {
                // Remove the playlist from pinned items if needed
                await handlePlaylistDeletionForPinnedItems(playlist.id)
                
                // Remove the playlist from db
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.deletePlaylist(playlist.id)
                }
            } catch {
                print("PlaylistManager: Failed to delete playlist from database: \(error)")
            }
        }
    }
    
    /// Rename a playlist
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard playlist.isUserEditable else {
            print("PlaylistManager: Cannot rename system playlist: \(playlist.name)")
            return
        }
        
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.name = newName
            updatedPlaylist.dateModified = Date()
            playlists[index] = updatedPlaylist
            
            // Save to database
            Task {
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(updatedPlaylist)
                    }
                } catch {
                    print("PlaylistManager: Failed to save renamed playlist: \(error)")
                }
            }
        }
    }
    
    internal func addTrackToRegularPlaylist(track: Track, playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[index].type == .regular,
              playlists[index].isContentEditable else {
            print("PlaylistManager: Cannot add to this playlist")
            return
        }

        // Check if track already exists
        let alreadyExists = await MainActor.run {
            self.playlists[index].tracks.contains { $0.trackId == track.trackId }
        }
        
        if alreadyExists {
            print("PlaylistManager: Track already in playlist")
            return
        }

        // Add track on main thread
        await MainActor.run {
            self.playlists[index].addTrack(track)
        }

        // Save to database - use efficient single track method
        if let dbManager = libraryManager?.databaseManager {
            let success = await dbManager.addTrackToPlaylist(playlistId: playlistID, track: track)
            if !success {
                // Revert change on main thread
                await MainActor.run {
                    self.playlists[index].removeTrack(track)
                }
            }
        }
    }
    
    internal func removeTrackFromRegularPlaylist(track: Track, playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[index].type == .regular,
              playlists[index].isContentEditable else {
            print("PlaylistManager: Cannot remove from this playlist")
            return
        }

        // Perform the track removal on main thread
        await MainActor.run {
            self.playlists[index].removeTrack(track)
        }

        // Save to database
        do {
            if let dbManager = libraryManager?.databaseManager {
                // Get the updated playlist from main thread
                let updatedPlaylist = await MainActor.run { self.playlists[index] }
                try await dbManager.savePlaylistAsync(updatedPlaylist)
                print("PlaylistManager: Removed track from playlist")
            }
        } catch {
            print("PlaylistManager: Failed to save playlist: \(error)")
            // Revert change on main thread
            await MainActor.run {
                self.playlists[index].addTrack(track)
            }
        }
    }
    
    /// Add multiple tracks to a playlist
    func addTracksToPlaylist(tracks: [Track], playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[index].type == .regular,
              playlists[index].isContentEditable else {
            print("PlaylistManager: Cannot add tracks to this playlist")
            return
        }
        
        // Add tracks that don't already exist
        for track in tracks {
            if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
                playlists[index].addTrack(track)
            }
        }
        
        // Save to database
        do {
            if let dbManager = libraryManager?.databaseManager {
                try await dbManager.savePlaylistAsync(playlists[index])
            }
        } catch {
            print("PlaylistManager: Failed to save playlist after adding tracks: \(error)")
        }
    }
    
    /// Refresh playlists after a folder is removed from the library
    func refreshPlaylistsAfterFolderRemoval() {
        // Remove tracks that no longer exist from regular playlists
        for index in playlists.indices {
            if playlists[index].type == .regular {
                let validTracks = playlists[index].tracks.filter { track in
                    // Check if track still exists in library
                    libraryManager?.tracks.contains { $0.trackId == track.trackId } ?? false
                }
                
                if validTracks.count < playlists[index].tracks.count {
                    playlists[index].tracks = validTracks
                    playlists[index].dateModified = Date()
                    
                    // Save updated playlist
                    Task {
                        do {
                            if let dbManager = libraryManager?.databaseManager {
                                try await dbManager.savePlaylistAsync(playlists[index])
                            }
                        } catch {
                            print("PlaylistManager: Failed to update playlist after folder removal: \(error)")
                        }
                    }
                }
            }
        }
        
        // Update smart playlists
        updateSmartPlaylists()
    }
}
