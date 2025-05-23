import Foundation

class PlaylistManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var currentPlaylistIndex: Int = -1
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var currentQueue: [Track] = [] // Current playback queue
    
    // MARK: - Private Properties
    private var shuffledIndices: [Int] = []
    private var libraryManager: LibraryManager?
    
    // MARK: - Dependencies
    private weak var audioPlayer: AudioPlayerManager?
    
    // MARK: - Initialization
    init() {
        loadPlaylists()
    }
    
    func setAudioPlayer(_ player: AudioPlayerManager) {
        self.audioPlayer = player
    }
    
    func setLibraryManager(_ manager: LibraryManager) {
        self.libraryManager = manager
    }
    
    // MARK: - Queue Management
    
    // Create a queue from the entire library
    func createLibraryQueue() {
        guard let library = libraryManager else { return }
        currentQueue = library.tracks
        currentPlaylist = nil
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    // Set current queue from a specific playlist
    func setCurrentQueue(from playlist: Playlist) {
        currentPlaylist = playlist
        currentQueue = playlist.tracks
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    // Set current queue from a folder
    func setCurrentQueue(fromFolder folder: Folder) {
        guard let library = libraryManager else { return }
        let folderTracks = library.getTracksInFolder(folder)
        currentQueue = folderTracks
        currentPlaylist = nil
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    private func shuffleCurrentQueue() {
        guard !currentQueue.isEmpty else { return }
        
        // If we have a current track, keep it at the beginning
        if let currentTrack = audioPlayer?.currentTrack,
           let currentIndex = currentQueue.firstIndex(where: { $0.id == currentTrack.id }) {
            
            // Remove current track from queue
            var tracksToShuffle = currentQueue
            tracksToShuffle.remove(at: currentIndex)
            
            // Shuffle the remaining tracks
            tracksToShuffle.shuffle()
            
            // Put current track first
            currentQueue = [currentTrack] + tracksToShuffle
            currentPlaylistIndex = 0
        } else {
            // No current track, just shuffle everything
            currentQueue.shuffle()
            currentPlaylistIndex = 0
        }
    }
    
    // MARK: - Playback Control
    
    func playTrack(_ track: Track) {
        // Find the track in current queue or create a new queue
        if let index = currentQueue.firstIndex(where: { $0.id == track.id }) {
            // Track is in current queue
            currentPlaylistIndex = index
        } else {
            // Track not in current queue, create a new queue starting with this track
            if let library = libraryManager {
                currentQueue = library.tracks
                currentPlaylist = nil
                if let index = currentQueue.firstIndex(where: { $0.id == track.id }) {
                    currentPlaylistIndex = index
                    if isShuffleEnabled {
                        shuffleCurrentQueue()
                    }
                }
            }
        }
        
        audioPlayer?.playTrack(track)
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
        
        setCurrentQueue(from: playlist)
        currentPlaylistIndex = index
        audioPlayer?.playTrack(playlist.tracks[index])
    }
    
    // MARK: - Track Navigation
    
    func playNextTrack() {
        guard !currentQueue.isEmpty else {
            // No queue exists, create one from library
            createLibraryQueue()
            if !currentQueue.isEmpty {
                currentPlaylistIndex = 0
                audioPlayer?.playTrack(currentQueue[0])
            }
            return
        }
        
        var nextIndex: Int
        
        // Calculate next index based on repeat mode
        switch repeatMode {
        case .one:
            // Repeat current track
            nextIndex = currentPlaylistIndex
        case .all:
            // Move to next track, wrap around if at end
            nextIndex = (currentPlaylistIndex + 1) % currentQueue.count
        case .off:
            // Move to next track, stop if at end
            nextIndex = currentPlaylistIndex + 1
            if nextIndex >= currentQueue.count {
                return // End of queue
            }
        }
        
        // Update current index and play track
        currentPlaylistIndex = nextIndex
        audioPlayer?.playTrack(currentQueue[nextIndex])
    }
    
    func playPreviousTrack() {
        guard !currentQueue.isEmpty else {
            // No queue exists, create one from library
            createLibraryQueue()
            return
        }
        
        // If we're more than 3 seconds into the track, restart it instead of going to previous
        if let currentTime = audioPlayer?.currentTime, currentTime > 3 {
            audioPlayer?.seekTo(time: 0)
            return
        }
        
        var prevIndex: Int
        
        // Calculate previous index based on repeat mode
        switch repeatMode {
        case .one:
            // Restart current track
            prevIndex = currentPlaylistIndex
        case .all:
            // Move to previous track, wrap around if at beginning
            prevIndex = currentPlaylistIndex > 0 ? currentPlaylistIndex - 1 : currentQueue.count - 1
        case .off:
            // Move to previous track, stop if at beginning
            prevIndex = currentPlaylistIndex - 1
            if prevIndex < 0 {
                // At beginning, just restart current track
                audioPlayer?.seekTo(time: 0)
                return
            }
        }
        
        // Update current index and play track
        currentPlaylistIndex = prevIndex
        audioPlayer?.playTrack(currentQueue[prevIndex])
    }
    
    // MARK: - Repeat and Shuffle
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            shuffleCurrentQueue()
        } else {
            // Turn off shuffle - restore original order
            if let playlist = currentPlaylist {
                currentQueue = playlist.tracks
            } else if let library = libraryManager {
                currentQueue = library.tracks
            }
            
            // Find current track in restored order
            if let currentTrack = audioPlayer?.currentTrack,
               let index = currentQueue.firstIndex(where: { $0.id == currentTrack.id }) {
                currentPlaylistIndex = index
            }
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
            if let currentTrack = currentQueue.first(where: { _ in currentPlaylistIndex >= 0 && currentPlaylistIndex < currentQueue.count }) {
                audioPlayer.playTrack(currentQueue[currentPlaylistIndex])
            }
        case .all, .off:
            // Play next track (playNextTrack handles repeat.all logic)
            playNextTrack()
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
    
    // Get the current playback queue
    func getCurrentPlaybackQueue() -> [Track] {
        return currentQueue
    }
    
    // Get current track info
    func getCurrentTrackInfo() -> (track: Track, index: Int, total: Int)? {
        guard currentPlaylistIndex >= 0,
              currentPlaylistIndex < currentQueue.count else { return nil }
        
        return (
            track: currentQueue[currentPlaylistIndex],
            index: currentPlaylistIndex,
            total: currentQueue.count
        )
    }
}
