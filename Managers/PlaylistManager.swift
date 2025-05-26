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
    private var smartPlaylistsInitialized = false
    
    // MARK: - Dependencies
    private weak var audioPlayer: AudioPlayerManager?
    
    // MARK: - Initialization
    init() {
        // Don't load playlists yet - wait until libraryManager is set
    }
    
    func setAudioPlayer(_ player: AudioPlayerManager) {
        self.audioPlayer = player
    }
    
    func setLibraryManager(_ manager: LibraryManager) {
        self.libraryManager = manager
        print("PlaylistManager: Library manager set, loading playlists...")
        
        // Reload playlists now that we have database access
        loadPlaylists()
    }
    
    // MARK: - Playlist Management
    
    /// Creates a new regular playlist
    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        let newPlaylist = Playlist(name: name, tracks: tracks)
        
        // Instead of just appending, maintain proper order
        let smartPlaylists = playlists.filter { $0.type == .smart }
        let regularPlaylists = playlists.filter { $0.type == .regular }
        
        playlists = sortPlaylists(smart: smartPlaylists, regular: regularPlaylists + [newPlaylist])
        
        savePlaylists()
        return newPlaylist
    }
    
    /// Deletes a playlist (only if user-editable)
    func deletePlaylist(_ playlist: Playlist) {
        // Prevent deletion of system playlists
        guard playlist.isUserEditable else {
            print("Cannot delete system playlist: \(playlist.name)")
            return
        }
        
        playlists.removeAll(where: { $0.id == playlist.id })
        
        // Delete from database
        guard let dbManager = libraryManager?.databaseManager else { return }
        
        Task {
            do {
                try await dbManager.deletePlaylist(playlist.id)
            } catch {
                print("Failed to delete playlist from database: \(error)")
            }
        }
    }
    
    /// Updates an existing playlist
    func updatePlaylist(_ updatedPlaylist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == updatedPlaylist.id }) {
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    /// Renames a playlist
    /// Renames a playlist
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard playlist.isUserEditable else {
            print("Cannot rename system playlist: \(playlist.name)")
            return
        }
        
        print("PlaylistManager: Attempting to rename '\(playlist.name)' to '\(newName)'")
        
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            print("PlaylistManager: Found playlist at index \(index)")
            
            // Create a completely new array to force SwiftUI update
            var newPlaylists = playlists
            newPlaylists[index].name = newName
            newPlaylists[index].dateModified = Date()
            
            // Replace the entire array
            playlists = newPlaylists
            
            print("PlaylistManager: Playlist renamed successfully")
            print("PlaylistManager: New name in array: \(playlists[index].name)")
            
            savePlaylists()
        } else {
            print("PlaylistManager: Could not find playlist to rename")
        }
    }
    
    /// Adds a track to a playlist (only for regular playlists)
    func addTrackToPlaylist(track: Track, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            // Check if it's a regular playlist that allows content editing
            guard playlists[index].isContentEditable else {
                print("Cannot add tracks to smart playlist: \(playlists[index].name)")
                return
            }
            
            var playlist = playlists[index]
            playlist.addTrack(track)
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    /// Removes a track from a playlist
    func removeTrackFromPlaylist(track: Track, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            var playlist = playlists[index]
            playlist.removeTrack(track)
            playlists[index] = playlist
            
            // Force a view update by reassigning the array
            objectWillChange.send()
            
            savePlaylists()
        }
    }
    
    // MARK: - Smart Playlist Management
    
    /// Updates all smart playlists based on current track metadata
    func updateSmartPlaylists() {
        guard let library = libraryManager else { return }
        
        var updatedSmartPlaylists: [Playlist] = []
        var regularPlaylists: [Playlist] = []
        
        for index in playlists.indices {
            if playlists[index].type == .smart {
                var updatedPlaylist = playlists[index]
                
                switch updatedPlaylist.smartType {
                case .favorites:
                    updatedPlaylist.tracks = library.tracks.filter { $0.isFavorite }
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    
                case .mostPlayed:
                    let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                    updatedPlaylist.tracks = library.tracks
                        .filter { $0.playCount >= 3 }
                        .sorted { $0.playCount > $1.playCount }
                        .prefix(limit)
                        .map { $0 }
                    
                case .recentlyPlayed:
                    let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                    let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                    
                    updatedPlaylist.tracks = library.tracks
                        .filter { track in
                            guard let lastPlayed = track.lastPlayedDate else { return false }
                            return lastPlayed > oneWeekAgo
                        }
                        .sorted { track1, track2 in
                            guard let date1 = track1.lastPlayedDate,
                                  let date2 = track2.lastPlayedDate else { return false }
                            return date1 > date2
                        }
                        .prefix(limit)
                        .map { $0 }
                    
                case .custom, .none:
                    break
                }
                
                updatedSmartPlaylists.append(updatedPlaylist)
            } else {
                regularPlaylists.append(playlists[index])
            }
        }
        
        // Maintain proper ordering
        playlists = sortPlaylists(smart: updatedSmartPlaylists, regular: regularPlaylists)
    }
    
    /// Toggles the favorite status of a track
    func toggleFavorite(for track: Track) {
        track.isFavorite.toggle()
        
        // Update the track in the database
        guard let trackId = track.trackId else { return }
        
        Task {
            do {
                // Get the database manager from library manager
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.updateTrackFavoriteStatus(trackId: trackId, isFavorite: track.isFavorite)
                }
            } catch {
                print("Failed to update favorite status: \(error)")
                // Revert the change if database update fails
                track.isFavorite.toggle()
            }
        }
        
        // Update smart playlists to reflect the change
        updateSmartPlaylists()
    }
    
    /// Increments play count and updates last played date
    func incrementPlayCount(for track: Track) {
        track.playCount += 1
        track.lastPlayedDate = Date()
        
        // Update the track in the database
        guard let trackId = track.trackId else { return }
        
        Task {
            do {
                // Get the database manager from library manager
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.updateTrackPlayInfo(
                        trackId: trackId,
                        playCount: track.playCount,
                        lastPlayedDate: track.lastPlayedDate!
                    )
                }
            } catch {
                print("Failed to update play info: \(error)")
                // Revert the changes if database update fails
                track.playCount -= 1
                track.lastPlayedDate = nil
            }
        }
        
        // Update smart playlists to reflect the change
        updateSmartPlaylists()
    }
    
    // MARK: - Queue Management
    
    /// Creates a queue from the entire library
    func createLibraryQueue() {
        guard let library = libraryManager else { return }
        currentQueue = library.tracks
        currentPlaylist = nil
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    /// Sets current queue from a specific playlist
    func setCurrentQueue(from playlist: Playlist) {
        currentPlaylist = playlist
        currentQueue = playlist.tracks
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    /// Sets current queue from a folder
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
    
    /// Plays a track and manages queue/playlist context
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
        
        // Increment play count
        incrementPlayCount(for: track)
        
        audioPlayer?.playTrack(track)
    }
    
    /// Plays a track from a specific playlist
    func playTrackFromPlaylist(_ playlist: Playlist, at index: Int) {
        guard index >= 0, index < playlist.tracks.count else { return }
        
        setCurrentQueue(from: playlist)
        currentPlaylistIndex = index
        
        let track = playlist.tracks[index]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    // MARK: - Track Navigation
    
    /// Plays the next track in the queue
    func playNextTrack() {
        guard !currentQueue.isEmpty else {
            // No queue exists, create one from library
            createLibraryQueue()
            if !currentQueue.isEmpty {
                currentPlaylistIndex = 0
                let track = currentQueue[0]
                incrementPlayCount(for: track)
                audioPlayer?.playTrack(track)
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
        let track = currentQueue[nextIndex]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    /// Plays the previous track in the queue
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
        let track = currentQueue[prevIndex]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    /// Handles track completion based on repeat mode
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
    
    // MARK: - Repeat and Shuffle
    
    /// Toggles shuffle mode and reorganizes queue if needed
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
    
    /// Cycles through repeat modes: off -> all -> one -> off
    func toggleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Data Persistence
    
    /// Loads playlists from storage
    func loadPlaylists() {
        // Load playlists from database
        guard let dbManager = libraryManager?.databaseManager else {
            return
        }
        
        // Load saved playlists
        let savedPlaylists = dbManager.loadAllPlaylists()
        
        // Separate smart and regular playlists
        let savedSmartPlaylists = savedPlaylists.filter { $0.type == .smart }
        let savedRegularPlaylists = savedPlaylists.filter { $0.type == .regular }
        
        // Check if we need to create default smart playlists
        if savedSmartPlaylists.isEmpty && !smartPlaylistsInitialized {
            // Create default smart playlists
            let defaultSmartPlaylists = Playlist.createDefaultSmartPlaylists()
            
            // Save them to database
            for playlist in defaultSmartPlaylists {
                Task {
                    do {
                        try await dbManager.savePlaylistAsync(playlist)
                    } catch {
                        print("Failed to save default playlist: \(error)")
                    }
                }
            }
            
            // Combine with proper ordering
            playlists = sortPlaylists(smart: defaultSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = true
        } else {
            // Use saved playlists with proper ordering
            playlists = sortPlaylists(smart: savedSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = !savedSmartPlaylists.isEmpty
        }
        
        // Update smart playlists content
        updateSmartPlaylists()
    }
    
    /// Saves playlists to storage
    private func savePlaylists() {
        guard let dbManager = libraryManager?.databaseManager else {
            return
        }
        
        // Save regular playlists synchronously
        for playlist in playlists {
            // Only save regular playlists and user-created smart playlists
            if playlist.type == .regular || (playlist.type == .smart && playlist.smartType == .custom) {
                do {
                    try dbManager.savePlaylist(playlist)
                } catch {
                    print("Failed to save playlist \(playlist.name): \(error)")
                }
            }
        }
    }
    
    private func sortPlaylists(smart: [Playlist], regular: [Playlist]) -> [Playlist] {
        // Define the order for smart playlists
        let smartPlaylistOrder: [SmartPlaylistType] = [.favorites, .mostPlayed, .recentlyPlayed]
        
        // Sort smart playlists according to our defined order
        let sortedSmartPlaylists = smart.sorted { playlist1, playlist2 in
            guard let type1 = playlist1.smartType,
                  let type2 = playlist2.smartType else {
                return false
            }
            
            let index1 = smartPlaylistOrder.firstIndex(of: type1) ?? Int.max
            let index2 = smartPlaylistOrder.firstIndex(of: type2) ?? Int.max
            
            return index1 < index2
        }
        
        // Sort regular playlists alphabetically
        let sortedRegularPlaylists = regular.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Combine: smart playlists first, then regular playlists
        return sortedSmartPlaylists + sortedRegularPlaylists
    }
    
    // MARK: - Utility Methods
    
    /// Gets the current playback queue
    func getCurrentPlaybackQueue() -> [Track] {
        return currentQueue
    }
    
    /// Gets current track info with position in queue
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
