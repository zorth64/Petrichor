import Foundation

class PlaylistManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var currentPlaylistIndex: Int = -1
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    
    // MARK: - Private Properties
    private var shuffledIndices: [Int] = []
    
    // MARK: - Dependencies
    private weak var audioPlayer: AudioPlayerManager?
    
    // MARK: - Initialization
    init() {
        loadPlaylists()
    }
    
    func setAudioPlayer(_ player: AudioPlayerManager) {
        self.audioPlayer = player
    }
    
    // MARK: - Playlist Management
    
    // Add a new playlist
    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        let newPlaylist = Playlist(name: name, tracks: tracks)
        playlists.append(newPlaylist)
        savePlaylists()
        return newPlaylist
    }
    
    // Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll(where: { $0.id == playlist.id })
        savePlaylists()
    }
    
    // Update a playlist
    func updatePlaylist(_ updatedPlaylist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == updatedPlaylist.id }) {
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    // Add a track to a playlist
    func addTrackToPlaylist(track: Track, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            var playlist = playlists[index]
            playlist.addTrack(track)
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    // Remove a track from a playlist
    func removeTrackFromPlaylist(track: Track, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            var playlist = playlists[index]
            playlist.removeTrack(track)
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    // Play track from playlist
    func playTrackFromPlaylist(_ playlist: Playlist, at index: Int) {
        guard index >= 0, index < playlist.tracks.count else { return }
        
        currentPlaylist = playlist
        currentPlaylistIndex = index
        
        // If shuffle is on, regenerate shuffle indices
        if isShuffleEnabled {
            generateShuffleIndices(forPlaylist: playlist)
        }
        
        audioPlayer?.playTrack(playlist.tracks[index])
    }
    
    // MARK: - Track Navigation
    
    func playNextTrack() {
        guard let playlist = currentPlaylist, currentPlaylistIndex >= 0, let audioPlayer = audioPlayer else { return }
        
        var nextIndex: Int
        
        if isShuffleEnabled {
            // Find current position in shuffled indices
            let currentShufflePosition = shuffledIndices.firstIndex(of: currentPlaylistIndex) ?? -1
            
            // Get next position
            if currentShufflePosition >= 0 && currentShufflePosition < shuffledIndices.count - 1 {
                nextIndex = shuffledIndices[currentShufflePosition + 1]
            } else if repeatMode == .all {
                // Wrap around to beginning of shuffle order
                nextIndex = shuffledIndices.first ?? 0
            } else {
                return // End of playlist with no repeat
            }
        } else {
            // Standard sequential playback
            nextIndex = currentPlaylistIndex + 1
            
            // Handle end of playlist
            if nextIndex >= playlist.tracks.count {
                if repeatMode == .all {
                    nextIndex = 0 // Wrap around to beginning
                } else {
                    return // End of playlist with no repeat
                }
            }
        }
        
        currentPlaylistIndex = nextIndex
        audioPlayer.playTrack(playlist.tracks[nextIndex])
    }
    
    func playPreviousTrack() {
        guard let playlist = currentPlaylist, currentPlaylistIndex >= 0, let audioPlayer = audioPlayer else { return }
        
        // If we're more than 3 seconds into the track, restart it instead of going to previous
        if audioPlayer.currentTime > 3 {
            audioPlayer.seekTo(time: 0)
            return
        }
        
        var prevIndex: Int
        
        if isShuffleEnabled {
            // Find current position in shuffled indices
            let currentShufflePosition = shuffledIndices.firstIndex(of: currentPlaylistIndex) ?? -1
            
            // Get previous position
            if currentShufflePosition > 0 {
                prevIndex = shuffledIndices[currentShufflePosition - 1]
            } else if repeatMode == .all {
                // Wrap around to end of shuffle order
                prevIndex = shuffledIndices.last ?? 0
            } else {
                return // Start of playlist with no repeat
            }
        } else {
            // Standard sequential playback
            prevIndex = currentPlaylistIndex - 1
            
            // Handle start of playlist
            if prevIndex < 0 {
                if repeatMode == .all {
                    prevIndex = playlist.tracks.count - 1 // Wrap around to end
                } else {
                    return // Start of playlist with no repeat
                }
            }
        }
        
        currentPlaylistIndex = prevIndex
        audioPlayer.playTrack(playlist.tracks[prevIndex])
    }
    
    // MARK: - Repeat and Shuffle
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled, let playlist = currentPlaylist {
            generateShuffleIndices(forPlaylist: playlist)
        }
    }
    
    func toggleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    func handleTrackCompletion() {
        switch repeatMode {
        case .one:
            // Replay current track
            guard let audioPlayer = audioPlayer else { return }
            audioPlayer.seekTo(time: 0)
            audioPlayer.togglePlayPause() // Restart playback
        case .all, .off:
            // Play next track (playNextTrack handles repeat.all logic)
            playNextTrack()
        }
    }
    
    private func generateShuffleIndices(forPlaylist playlist: Playlist) {
        // Create array of indices and shuffle them
        shuffledIndices = Array(0..<playlist.tracks.count)
        
        // Fisher-Yates shuffle algorithm
        for i in 0..<shuffledIndices.count {
            let j = Int.random(in: i..<shuffledIndices.count)
            if i != j {
                shuffledIndices.swapAt(i, j)
            }
        }
        
        // Make sure current track is first if we're already playing
        if currentPlaylistIndex >= 0 {
            if let currentPosition = shuffledIndices.firstIndex(of: currentPlaylistIndex) {
                shuffledIndices.swapAt(0, currentPosition)
            }
        }
    }
    
    // MARK: - Data Persistence
    
    // Load playlists from storage
    func loadPlaylists() {
        // In a real implementation, this would load from UserDefaults, a database, or files
        // For now, we'll start with an empty array
        playlists = []
    }
    
    // Save playlists to storage
    private func savePlaylists() {
        // In a real implementation, this would save to UserDefaults, a database, or files
        print("Saving \(playlists.count) playlists")
    }
    
    // Get the current playback queue (accounts for shuffle)
    func getCurrentPlaybackQueue() -> [Track] {
        guard let playlist = currentPlaylist else { return [] }
        
        if isShuffleEnabled {
            // Convert shuffle indices back to tracks
            return shuffledIndices.map { playlist.tracks[$0] }
        } else {
            return playlist.tracks
        }
    }
}
