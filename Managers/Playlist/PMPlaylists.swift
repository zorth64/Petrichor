import Foundation

extension PlaylistManager {
    // MARK: - Core Playlist Operations
    
    /// Load all playlists from database
    func loadPlaylists() {
        guard let dbManager = libraryManager?.databaseManager else {
            return
        }
        
        let savedPlaylists = dbManager.loadAllPlaylists()
        
        let savedSmartPlaylists = savedPlaylists.filter { $0.type == .smart }
        let savedRegularPlaylists = savedPlaylists.filter { $0.type == .regular }
        
        playlists = sortPlaylists(smart: savedSmartPlaylists, regular: savedRegularPlaylists)
        
        // Update smart playlists with current track data
        updateSmartPlaylists()
    }
    
    /// Sort playlists according to type and predefined order
    internal func sortPlaylists(smart: [Playlist], regular: [Playlist]) -> [Playlist] {
        // Combine all playlists and sort by creation date (oldest first)
        let allPlaylists = smart + regular
        return allPlaylists.sorted { $0.dateCreated < $1.dateCreated }
    }
    
    /// Get all playlists that a track belongs to
    func getPlaylistsContainingTrack(_ track: Track) -> [Playlist] {
        playlists.filter { playlist in
            playlist.tracks.contains { $0.id == track.id }
        }
    }
    
    /// Check if a playlist name already exists
    func playlistExists(withName name: String) -> Bool {
        playlists.contains { $0.name.lowercased() == name.lowercased() }
    }
}
