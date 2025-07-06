import Foundation

extension PlaylistManager {
    // MARK: - Smart Playlist Management

    /// Update all smart playlists with current track data
    func updateSmartPlaylists() {
        guard let libraryManager = libraryManager else { return }
        let allTracks = libraryManager.tracks
        
        Logger.info("Updating smart playlists with \(allTracks.count) tracks")
        
        // Ensure we're on the main thread since we're updating @Published property
        if Thread.isMainThread {
            // Already on main thread, update directly
            for index in playlists.indices {
                guard playlists[index].type == .smart else { continue }
                
                let matchingTracks = evaluateSmartPlaylist(playlists[index], allTracks: allTracks)
                playlists[index].tracks = matchingTracks
                
                Logger.info("Updated '\(playlists[index].name)' with \(matchingTracks.count) tracks")
            }
        } else {
            // Not on main thread, dispatch to main
            DispatchQueue.main.async {
                for index in self.playlists.indices {
                    guard self.playlists[index].type == .smart else { continue }
                    
                    let matchingTracks = self.evaluateSmartPlaylist(self.playlists[index], allTracks: allTracks)
                    self.playlists[index].tracks = matchingTracks
                    
                    Logger.info("Updated '\(self.playlists[index].name)' with \(matchingTracks.count) tracks")
                }
            }
        }
    }
    
    /// Update smart playlists for a specific track change
    func updateSmartPlaylistsForTrack(_ track: Track) {
        guard libraryManager != nil else { return }
        
        Logger.info("Updating smart playlists for track: \(track.title)")
        
        // Check each smart playlist to see if this track should be added/removed
        for index in playlists.indices {
            guard playlists[index].type == .smart,
                  let criteria = playlists[index].smartCriteria else { continue }
            
            let trackBelongs = evaluateTrackAgainstCriteria(track, criteria: criteria)
            let currentlyInPlaylist = playlists[index].tracks.contains { $0.trackId == track.trackId }
            
            if trackBelongs && !currentlyInPlaylist {
                // Track should be in playlist but isn't - add it
                var updatedTracks = playlists[index].tracks
                updatedTracks.append(track)
                
                // Apply sorting and limit
                if let sortBy = criteria.sortBy {
                    updatedTracks = sortTracks(updatedTracks, by: sortBy, ascending: criteria.sortAscending)
                }
                if let limit = criteria.limit {
                    updatedTracks = Array(updatedTracks.prefix(limit))
                }
                
                playlists[index].tracks = updatedTracks
                Logger.info("Added track to '\(playlists[index].name)'")
            } else if !trackBelongs && currentlyInPlaylist {
                // Track shouldn't be in playlist but is - remove it
                playlists[index].tracks.removeAll { $0.trackId == track.trackId }
                Logger.info("Removed track from '\(playlists[index].name)'")
            }
        }
    }
    
    /// Check if a track belongs in a smart playlist
    func trackBelongsInSmartPlaylist(_ track: Track, playlist: Playlist) -> Bool {
        guard playlist.type == .smart,
              let criteria = playlist.smartCriteria else {
            return false
        }
        
        return evaluateTrackAgainstCriteria(track, criteria: criteria)
    }
}
