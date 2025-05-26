import Foundation

class PlaylistManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var currentQueue: [Track] = [] // Current playback queue
    @Published var currentQueueIndex: Int = -1 // Current position in queue
    @Published var currentQueueSource: QueueSource = .library // Source of current queue

    enum QueueSource {
        case library
        case folder
        case playlist
    }

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
    
    // MARK: - Queue Management

    /// Creates a queue from the entire library
    func createLibraryQueue() {
        guard let library = libraryManager else { return }
        currentQueue = library.tracks
        currentPlaylist = nil
        currentQueueSource = .library  // Add this
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }

    /// Sets current queue from a specific playlist
    func setCurrentQueue(from playlist: Playlist) {
        currentPlaylist = playlist
        currentQueue = playlist.tracks
        currentQueueSource = .playlist  // Add this
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
        currentQueueSource = .folder  // Add this
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }

    /// Clears the current queue
    func clearQueue() {
        currentQueue.removeAll()
        currentQueueIndex = -1
        currentPlaylist = nil
        audioPlayer?.stop()
    }

    /// Adds a track to play next (after current track)
    func playNext(_ track: Track) {
        // If queue is empty or no track is playing, just play the track
        if currentQueue.isEmpty || currentQueueIndex < 0 {
            currentQueue = [track]
            currentQueueIndex = 0
            incrementPlayCount(for: track)
            audioPlayer?.playTrack(track)
            return
        }
        
        // Insert after current track
        let insertIndex = currentQueueIndex + 1
        
        // Remove the track if it already exists in queue
        if let existingIndex = currentQueue.firstIndex(where: { $0.id == track.id }) {
            currentQueue.remove(at: existingIndex)
            // Adjust current index if needed
            if existingIndex <= currentQueueIndex {
                currentQueueIndex -= 1
            }
        }
        
        // Insert at the new position
        currentQueue.insert(track, at: min(insertIndex, currentQueue.count))
    }

    /// Adds a track to the end of the queue
    func addToQueue(_ track: Track) {
        // If queue is empty, create a new queue with this track
        if currentQueue.isEmpty {
            currentQueue = [track]
            currentQueueIndex = 0
            incrementPlayCount(for: track)
            audioPlayer?.playTrack(track)
            return
        }
        
        // Add to end of queue if not already present
        if !currentQueue.contains(where: { $0.id == track.id }) {
            currentQueue.append(track)
        }
    }

    /// Removes a track from queue at specific index
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < currentQueue.count else { return }
        
        // Don't allow removing the currently playing track
        if index == currentQueueIndex {
            return
        }
        
        currentQueue.remove(at: index)
        
        // Adjust current index if needed
        if index < currentQueueIndex {
            currentQueueIndex -= 1
        }
    }

    /// Moves a track within the queue
    func moveInQueue(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < currentQueue.count,
              destinationIndex >= 0, destinationIndex < currentQueue.count,
              sourceIndex != destinationIndex else { return }
        
        let track = currentQueue.remove(at: sourceIndex)
        currentQueue.insert(track, at: destinationIndex)
        
        // Update current index to track the currently playing song
        if sourceIndex == currentQueueIndex {
            // Currently playing track was moved
            currentQueueIndex = destinationIndex
        } else if sourceIndex < currentQueueIndex && destinationIndex >= currentQueueIndex {
            // Moved from before to after current
            currentQueueIndex -= 1
        } else if sourceIndex > currentQueueIndex && destinationIndex <= currentQueueIndex {
            // Moved from after to before current
            currentQueueIndex += 1
        }
    }

    /// Plays a track from a specific position in the queue
    func playFromQueue(at index: Int) {
        guard index >= 0 && index < currentQueue.count else { return }
        
        currentQueueIndex = index
        let track = currentQueue[index]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
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
            currentQueueIndex = 0
        } else {
            // No current track, just shuffle everything
            currentQueue.shuffle()
            currentQueueIndex = 0
        }
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
                print("PlaylistManager: Cannot add tracks to smart playlist: \(playlists[index].name)")
                return
            }
            
            var playlist = playlists[index]
            let trackCountBefore = playlist.tracks.count
            playlist.addTrack(track)
            
            print("PlaylistManager: Adding '\(track.title)' to playlist '\(playlist.name)'")
            print("PlaylistManager: Track has database ID: \(track.trackId ?? -1)")
            print("PlaylistManager: Tracks before: \(trackCountBefore), after: \(playlist.tracks.count)")
            
            playlists[index] = playlist
            
            // Save to database synchronously for reliability
            if let dbManager = libraryManager?.databaseManager {
                do {
                    try dbManager.savePlaylist(playlist)
                    print("PlaylistManager: Successfully saved playlist '\(playlist.name)' to database")
                    
                    // Verify the save by checking the database
                    Task {
                        let savedPlaylists = dbManager.loadAllPlaylists()
                        if let saved = savedPlaylists.first(where: { $0.id == playlist.id }) {
                            print("PlaylistManager: Verified - playlist has \(saved.tracks.count) tracks in database")
                        }
                    }
                } catch {
                    print("PlaylistManager: Failed to save playlist to database: \(error)")
                    // Revert the change
                    playlists[index].removeTrack(track)
                }
            }
        } else {
            print("PlaylistManager: Playlist with ID \(playlistID) not found")
        }
    }
    
    /// Removes a track from a playlist
    func removeTrackFromPlaylist(track: Track, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            var playlist = playlists[index]
            let trackCountBefore = playlist.tracks.count
            
            print("PlaylistManager: Removing '\(track.title)' from playlist '\(playlist.name)'")
            print("PlaylistManager: Track ID: \(track.trackId ?? -1), UUID: \(track.id)")
            
            playlist.removeTrack(track)
            
            print("PlaylistManager: Tracks before: \(trackCountBefore), after: \(playlist.tracks.count)")
            
            if trackCountBefore > playlist.tracks.count {
                playlists[index] = playlist
                
                // Force a view update by reassigning the array
                objectWillChange.send()
                
                // Save to database
                Task {
                    do {
                        if let dbManager = libraryManager?.databaseManager {
                            try await dbManager.savePlaylistAsync(playlist)
                            print("PlaylistManager: Successfully saved playlist '\(playlist.name)' to database after track removal")
                        }
                    } catch {
                        print("PlaylistManager: Failed to save playlist to database: \(error)")
                        // Revert the change - add the track back
                        playlists[index].addTrack(track)
                    }
                }
            } else {
                print("PlaylistManager: Track was not found in playlist")
            }
        } else {
            print("PlaylistManager: Playlist with ID \(playlistID) not found")
        }
    }
    
    // MARK: - Smart Playlist Management
    
    /// Updates all smart playlists based on current track metadata
    func updateSmartPlaylists() {
        guard let library = libraryManager else { return }
        
        print("PlaylistManager: Updating smart playlists...")
        print("PlaylistManager: Total library tracks: \(library.tracks.count)")
        
        var updatedSmartPlaylists: [Playlist] = []
        var regularPlaylists: [Playlist] = []
        
        for index in playlists.indices {
            if playlists[index].type == .smart {
                var updatedPlaylist = playlists[index]
                
                switch updatedPlaylist.smartType {
                case .favorites:
                    let favoriteTracks = library.tracks.filter { $0.isFavorite }
                    print("PlaylistManager: Favorite tracks found: \(favoriteTracks.count)")
                    updatedPlaylist.tracks = favoriteTracks
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    
                case .mostPlayed:
                    let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                    let mostPlayedTracks = library.tracks
                        .filter { $0.playCount >= 3 }
                    print("PlaylistManager: Tracks with playCount >= 3: \(mostPlayedTracks.count)")
                    updatedPlaylist.tracks = mostPlayedTracks
                        .sorted { $0.playCount > $1.playCount }
                        .prefix(limit)
                        .map { $0 }
                    
                case .recentlyPlayed:
                    let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                    let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                    
                    let recentTracks = library.tracks
                        .filter { track in
                            guard let lastPlayed = track.lastPlayedDate else { return false }
                            return lastPlayed > oneWeekAgo
                        }
                    print("PlaylistManager: Recently played tracks: \(recentTracks.count)")
                    updatedPlaylist.tracks = recentTracks
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
        guard let trackId = track.trackId else {
            print("PlaylistManager: Cannot update favorite - track has no database ID")
            return
        }
        
        print("PlaylistManager: Toggling favorite for '\(track.title)' (ID: \(trackId)) to \(track.isFavorite)")
        
        Task {
            do {
                // Get the database manager from library manager
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.updateTrackFavoriteStatus(trackId: trackId, isFavorite: track.isFavorite)
                    print("PlaylistManager: Successfully updated favorite status in database")
                }
            } catch {
                print("PlaylistManager: Failed to update favorite status: \(error)")
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
        guard let trackId = track.trackId else {
            print("PlaylistManager: Cannot update play count - track has no database ID")
            return
        }
        
        print("PlaylistManager: Incrementing play count for '\(track.title)' (ID: \(trackId)) to \(track.playCount)")
        
        Task {
            do {
                // Get the database manager from library manager
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.updateTrackPlayInfo(
                        trackId: trackId,
                        playCount: track.playCount,
                        lastPlayedDate: track.lastPlayedDate!
                    )
                    print("PlaylistManager: Successfully updated play info in database")
                }
            } catch {
                print("PlaylistManager: Failed to update play info: \(error)")
                // Revert the changes if database update fails
                track.playCount -= 1
                track.lastPlayedDate = nil
            }
        }
        
        // Update smart playlists to reflect the change
        updateSmartPlaylists()
    }
    
    // MARK: - Playback Control
    
    /// Plays a track with context-aware queue creation
    func playTrack(_ track: Track, fromTracks contextTracks: [Track]? = nil) {
        var queueTracks: [Track] = []
        
        if let contextTracks = contextTracks, !contextTracks.isEmpty {
            // Use the provided context tracks
            if let trackIndex = contextTracks.firstIndex(where: { $0.id == track.id }) {
                if isShuffleEnabled {
                    // Shuffle all tracks except the one being played
                    var tracksToShuffle = contextTracks
                    tracksToShuffle.remove(at: trackIndex)
                    tracksToShuffle.shuffle()
                    
                    // Put the played track first, then shuffled tracks
                    queueTracks = [track] + tracksToShuffle
                    currentQueueIndex = 0
                } else {
                    // Keep original order - include ALL tracks, not just from current position
                    queueTracks = contextTracks
                    currentQueueIndex = trackIndex
                }
            } else {
                // Track not in context, just play it alone
                queueTracks = [track]
                currentQueueIndex = 0
            }
        } else {
            // No context provided, create minimal queue
            queueTracks = [track]
            currentQueueIndex = 0
        }
        
        // Update queue
        currentQueue = queueTracks
        currentPlaylist = nil
        currentQueueSource = .library // This will be set by the calling method
        
        // Increment play count and play
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    /// Plays a track from a specific playlist
    func playTrackFromPlaylist(_ playlist: Playlist, at index: Int) {
        guard index >= 0, index < playlist.tracks.count else { return }
        
        currentPlaylist = playlist
        currentQueueSource = .playlist
        
        let track = playlist.tracks[index]
        
        if isShuffleEnabled {
            // Shuffle all tracks except the one being played
            var tracksToShuffle = playlist.tracks
            tracksToShuffle.remove(at: index)
            tracksToShuffle.shuffle()
            
            // Put the played track first
            currentQueue = [track] + tracksToShuffle
            currentQueueIndex = 0
        } else {
            // Start from the selected track
            currentQueue = Array(playlist.tracks[index...])
            currentQueueIndex = 0
        }
        
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    /// Plays a track from a folder context
    func playTrackFromFolder(_ track: Track, folder: Folder, folderTracks: [Track]) {
        currentQueueSource = .folder
        currentPlaylist = nil
        
        if let trackIndex = folderTracks.firstIndex(where: { $0.id == track.id }) {
            if isShuffleEnabled {
                // Shuffle all tracks except the one being played
                var tracksToShuffle = folderTracks
                tracksToShuffle.remove(at: trackIndex)
                tracksToShuffle.shuffle()
                
                // Put the played track first
                currentQueue = [track] + tracksToShuffle
                currentQueueIndex = 0
            } else {
                // Start from the selected track
                currentQueue = Array(folderTracks[trackIndex...])
                currentQueueIndex = 0
            }
        } else {
            // Fallback: just play the track
            currentQueue = [track]
            currentQueueIndex = 0
        }
        
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
                currentQueueIndex = 0
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
            nextIndex = currentQueueIndex
        case .all:
            // Move to next track, wrap around if at end
            nextIndex = (currentQueueIndex + 1) % currentQueue.count
        case .off:
            // Move to next track, stop if at end
            nextIndex = currentQueueIndex + 1
            if nextIndex >= currentQueue.count {
                return // End of queue
            }
        }
        
        // Update current index and play track
        currentQueueIndex = nextIndex
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
            prevIndex = currentQueueIndex
        case .all:
            // Move to previous track, wrap around if at beginning
            prevIndex = currentQueueIndex > 0 ? currentQueueIndex - 1 : currentQueue.count - 1
        case .off:
            // Move to previous track, stop if at beginning
            prevIndex = currentQueueIndex - 1
            if prevIndex < 0 {
                // At beginning, just restart current track
                audioPlayer?.seekTo(time: 0)
                return
            }
        }
        
        // Update current index and play track
        currentQueueIndex = prevIndex
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
            if let currentTrack = currentQueue.first(where: { _ in currentQueueIndex >= 0 && currentQueueIndex < currentQueue.count }) {
                audioPlayer.playTrack(currentQueue[currentQueueIndex])
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
            // Turning shuffle ON - shuffle the remaining tracks after the current one
            shuffleCurrentQueue()
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
            print("PlaylistManager: No database manager available")
            return
        }
        
        // Save all playlists
        Task {
            for playlist in playlists {
                // Only save regular playlists and user-created smart playlists
                if playlist.type == .regular || (playlist.type == .smart && playlist.smartType == .custom) {
                    do {
                        try await dbManager.savePlaylistAsync(playlist)
                        print("PlaylistManager: Saved playlist '\(playlist.name)' with \(playlist.tracks.count) tracks")
                    } catch {
                        print("PlaylistManager: Failed to save playlist '\(playlist.name)': \(error)")
                    }
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
        guard currentQueueIndex >= 0,
              currentQueueIndex < currentQueue.count else { return nil }
        
        return (
            track: currentQueue[currentQueueIndex],
            index: currentQueueIndex,
            total: currentQueue.count
        )
    }
}
