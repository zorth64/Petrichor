import Foundation

class PlaylistManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var currentQueue: [Track] = []
    @Published var currentQueueIndex: Int = -1
    @Published var currentQueueSource: QueueSource = .library

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
        loadPlaylists()
    }
    
    // MARK: - Unified Playlist Management
    
    /// Add or remove a track from any playlist (handles both regular and smart playlists)
    func updateTrackInPlaylist(track: Track, playlist: Playlist, add: Bool) {
        Task {
            do {
                guard let dbManager = libraryManager?.databaseManager else { return }
                
                // Handle smart playlists differently
                if playlist.type == .smart {
                    // For smart playlists, we update the track property that controls membership
                    switch playlist.smartType {
                    case .favorites:
                        // Update favorite status
                        await updateTrackFavoriteStatus(track: track, isFavorite: add)
                    case .mostPlayed, .recentlyPlayed:
                        // These are read-only smart playlists
                        print("PlaylistManager: Cannot manually add/remove tracks from \(playlist.name)")
                        return
                    default:
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
                await MainActor.run {
                    self.updateSmartPlaylists()
                }
            }
        }
    }
    
    /// Add multiple tracks to a playlist at once
    func addTracksToPlaylist(tracks: [Track], playlistID: UUID) {
        Task {
            guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
                  playlists[index].type == .regular,
                  playlists[index].isContentEditable else {
                print("PlaylistManager: Cannot add to this playlist")
                return
            }
            
            var playlist = playlists[index]
            var tracksAdded = 0
            
            // Add all tracks that aren't already in the playlist
            for track in tracks {
                if !playlist.tracks.contains(where: { $0.trackId == track.trackId }) {
                    playlist.addTrack(track)
                    tracksAdded += 1
                }
            }
            
            if tracksAdded > 0 {
                // Update in-memory
                await MainActor.run {
                    self.playlists[index] = playlist
                }
                
                // Save to database once
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(playlist)
                        print("PlaylistManager: Added \(tracksAdded) tracks to playlist")
                    }
                } catch {
                    print("PlaylistManager: Failed to save playlist: \(error)")
                    // Revert changes
                    await MainActor.run {
                        // Reload from the original
                        if let dbManager = self.libraryManager?.databaseManager {
                            let savedPlaylists = dbManager.loadAllPlaylists()
                            if let originalPlaylist = savedPlaylists.first(where: { $0.id == playlistID }) {
                                self.playlists[index] = originalPlaylist
                            }
                        }
                    }
                }
            }
            
            // Update smart playlists if needed
            await MainActor.run {
                self.updateSmartPlaylists()
            }
        }
    }

    /// Remove multiple tracks from a playlist at once
    func removeTracksFromPlaylist(tracks: [Track], playlistID: UUID) {
        Task {
            guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
                  playlists[index].type == .regular,
                  playlists[index].isContentEditable else {
                print("PlaylistManager: Cannot remove from this playlist")
                return
            }
            
            var playlist = playlists[index]
            var tracksRemoved = 0
            
            // Remove all specified tracks
            for track in tracks {
                let beforeCount = playlist.tracks.count
                playlist.removeTrack(track)
                if playlist.tracks.count < beforeCount {
                    tracksRemoved += 1
                }
            }
            
            if tracksRemoved > 0 {
                // Update in-memory
                await MainActor.run {
                    self.playlists[index] = playlist
                }
                
                // Save to database once
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(playlist)
                        print("PlaylistManager: Removed \(tracksRemoved) tracks from playlist")
                    }
                } catch {
                    print("PlaylistManager: Failed to save playlist: \(error)")
                    // Revert changes
                    await MainActor.run {
                        if let dbManager = self.libraryManager?.databaseManager {
                            let savedPlaylists = dbManager.loadAllPlaylists()
                            if let originalPlaylist = savedPlaylists.first(where: { $0.id == playlistID }) {
                                self.playlists[index] = originalPlaylist
                            }
                        }
                    }
                }
            }
            
            // Update smart playlists if needed
            await MainActor.run {
                self.updateSmartPlaylists()
            }
        }
    }
    
    /// Toggle a track's membership in a playlist
    func toggleTrackInPlaylist(track: Track, playlist: Playlist) {
        let isInPlaylist = playlist.tracks.contains { $0.trackId == track.trackId }
        updateTrackInPlaylist(track: track, playlist: playlist, add: !isInPlaylist)
    }
    
    /// Check if a track is in a playlist
    func isTrackInPlaylist(track: Track, playlist: Playlist) -> Bool {
        return playlist.tracks.contains { $0.trackId == track.trackId }
    }
    
    // MARK: - Private Helper Methods
    
    private func addTrackToRegularPlaylist(track: Track, playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[index].type == .regular,
              playlists[index].isContentEditable else {
            print("PlaylistManager: Cannot add to this playlist")
            return
        }
        
        var playlist = playlists[index]
        
        // Check if track already exists
        if playlist.tracks.contains(where: { $0.trackId == track.trackId }) {
            print("PlaylistManager: Track already in playlist")
            return
        }
        
        playlist.addTrack(track)
        
        // Update in-memory
        await MainActor.run {
            self.playlists[index] = playlist
        }
        
        // Save to database
        do {
            if let dbManager = libraryManager?.databaseManager {
                try await dbManager.savePlaylistAsync(playlist)
                print("PlaylistManager: Added track to playlist")
            }
        } catch {
            print("PlaylistManager: Failed to save playlist: \(error)")
            // Revert change
            await MainActor.run {
                self.playlists[index].removeTrack(track)
            }
        }
    }
    
    private func removeTrackFromRegularPlaylist(track: Track, playlistID: UUID) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[index].type == .regular,
              playlists[index].isContentEditable else {
            print("PlaylistManager: Cannot remove from this playlist")
            return
        }
        
        var playlist = playlists[index]
        playlist.removeTrack(track)
        
        // Update in-memory
        await MainActor.run {
            self.playlists[index] = playlist
        }
        
        // Save to database
        do {
            if let dbManager = libraryManager?.databaseManager {
                try await dbManager.savePlaylistAsync(playlist)
                print("PlaylistManager: Removed track from playlist")
            }
        } catch {
            print("PlaylistManager: Failed to save playlist: \(error)")
            // Revert change
            await MainActor.run {
                self.playlists[index].addTrack(track)
            }
        }
    }
    
    private func updateTrackFavoriteStatus(track: Track, isFavorite: Bool) async {
        guard let trackId = track.trackId else {
            print("PlaylistManager: Cannot update favorite - track has no database ID")
            return
        }
        
        // Update track object
        await MainActor.run {
            track.isFavorite = isFavorite
        }
        
        do {
            if let dbManager = libraryManager?.databaseManager {
                try await dbManager.updateTrackFavoriteStatus(trackId: trackId, isFavorite: isFavorite)
                
                // Update library manager's track
                await MainActor.run {
                    if let libraryTrack = self.libraryManager?.tracks.first(where: { $0.trackId == trackId }) {
                        libraryTrack.isFavorite = isFavorite
                    }
                }
                
                print("PlaylistManager: Updated favorite status")
            }
        } catch {
            print("PlaylistManager: Failed to update favorite status: \(error)")
            // Revert change
            await MainActor.run {
                track.isFavorite = !isFavorite
            }
        }
    }
    
    // MARK: - Smart Playlist Management
    
    func updateSmartPlaylists() {
        guard let library = libraryManager else { return }
        
        print("PlaylistManager: Updating smart playlists...")
        
        for index in playlists.indices {
            guard playlists[index].type == .smart else { continue }
            
            var updatedPlaylist = playlists[index]
            
            switch updatedPlaylist.smartType {
            case .favorites:
                updatedPlaylist.tracks = library.tracks
                    .filter { $0.isFavorite }
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
                
            default:
                break
            }
            
            playlists[index] = updatedPlaylist
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Toggle favorite status for a track
    func toggleFavorite(for track: Track) {
        if let favoritesPlaylist = playlists.first(where: { $0.smartType == .favorites }) {
            updateTrackInPlaylist(track: track, playlist: favoritesPlaylist, add: !track.isFavorite)
        }
    }
    
    /// Add track to a specific playlist by ID
    func addTrackToPlaylist(track: Track, playlistID: UUID) {
        if let playlist = playlists.first(where: { $0.id == playlistID }) {
            updateTrackInPlaylist(track: track, playlist: playlist, add: true)
        }
    }
    
    /// Remove track from a specific playlist by ID
    func removeTrackFromPlaylist(track: Track, playlistID: UUID) {
        if let playlist = playlists.first(where: { $0.id == playlistID }) {
            updateTrackInPlaylist(track: track, playlist: playlist, add: false)
        }
    }
    
    // MARK: - Playlist CRUD Operations
    
    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        let newPlaylist = Playlist(name: name, tracks: tracks)
        
        let smartPlaylists = playlists.filter { $0.type == .smart }
        let regularPlaylists = playlists.filter { $0.type == .regular }
        
        playlists = sortPlaylists(smart: smartPlaylists, regular: regularPlaylists + [newPlaylist])
        
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
    
    func deletePlaylist(_ playlist: Playlist) {
        guard playlist.isUserEditable else {
            print("Cannot delete system playlist: \(playlist.name)")
            return
        }
        
        playlists.removeAll(where: { $0.id == playlist.id })
        
        guard let dbManager = libraryManager?.databaseManager else { return }
        
        Task {
            do {
                try await dbManager.deletePlaylist(playlist.id)
            } catch {
                print("Failed to delete playlist from database: \(error)")
            }
        }
    }
    
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard playlist.isUserEditable else {
            print("Cannot rename system playlist: \(playlist.name)")
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
                    print("Failed to save renamed playlist: \(error)")
                }
            }
        }
    }
    
    // MARK: - Playback Management
    
    func incrementPlayCount(for track: Track) {
        track.playCount += 1
        track.lastPlayedDate = Date()
        
        guard let trackId = track.trackId else { return }
        
        Task {
            do {
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.updateTrackPlayInfo(
                        trackId: trackId,
                        playCount: track.playCount,
                        lastPlayedDate: track.lastPlayedDate!
                    )
                    
                    // Update smart playlists after play info changes
                    await MainActor.run {
                        self.updateSmartPlaylists()
                    }
                }
            } catch {
                print("Failed to update play info: \(error)")
                track.playCount -= 1
                track.lastPlayedDate = nil
            }
        }
    }
    
    // MARK: - Queue Management (unchanged)
    
    func createLibraryQueue() {
        guard let library = libraryManager else { return }
        currentQueue = library.tracks
        currentPlaylist = nil
        currentQueueSource = .library
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }

    func setCurrentQueue(from playlist: Playlist) {
        currentPlaylist = playlist
        currentQueue = playlist.tracks
        currentQueueSource = .playlist
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }

    func setCurrentQueue(fromFolder folder: Folder) {
        guard let library = libraryManager else { return }
        let folderTracks = library.getTracksInFolder(folder)
        currentQueue = folderTracks
        currentPlaylist = nil
        currentQueueSource = .folder
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }

    func clearQueue() {
        currentQueue.removeAll()
        currentQueueIndex = -1
        currentPlaylist = nil
        audioPlayer?.stop()
        audioPlayer?.currentTrack = nil
    }

    func playNext(_ track: Track) {
        if currentQueue.isEmpty || currentQueueIndex < 0 {
            currentQueue = [track]
            currentQueueIndex = 0
            incrementPlayCount(for: track)
            audioPlayer?.playTrack(track)
            return
        }
        
        let insertIndex = currentQueueIndex + 1
        
        if let existingIndex = currentQueue.firstIndex(where: { $0.id == track.id }) {
            currentQueue.remove(at: existingIndex)
            if existingIndex <= currentQueueIndex {
                currentQueueIndex -= 1
            }
        }
        
        currentQueue.insert(track, at: min(insertIndex, currentQueue.count))
    }

    func addToQueue(_ track: Track) {
        if currentQueue.isEmpty {
            currentQueue = [track]
            currentQueueIndex = 0
            incrementPlayCount(for: track)
            audioPlayer?.playTrack(track)
            return
        }
        
        if !currentQueue.contains(where: { $0.id == track.id }) {
            currentQueue.append(track)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < currentQueue.count else { return }
        
        if index == currentQueueIndex {
            return
        }
        
        currentQueue.remove(at: index)
        
        if index < currentQueueIndex {
            currentQueueIndex -= 1
        }
    }

    func moveInQueue(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < currentQueue.count,
              destinationIndex >= 0, destinationIndex < currentQueue.count,
              sourceIndex != destinationIndex else { return }
        
        let track = currentQueue.remove(at: sourceIndex)
        currentQueue.insert(track, at: destinationIndex)
        
        if sourceIndex == currentQueueIndex {
            currentQueueIndex = destinationIndex
        } else if sourceIndex < currentQueueIndex && destinationIndex >= currentQueueIndex {
            currentQueueIndex -= 1
        } else if sourceIndex > currentQueueIndex && destinationIndex <= currentQueueIndex {
            currentQueueIndex += 1
        }
    }

    func playFromQueue(at index: Int) {
        guard index >= 0 && index < currentQueue.count else { return }
        
        currentQueueIndex = index
        let track = currentQueue[index]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    private func shuffleCurrentQueue() {
        guard !currentQueue.isEmpty else { return }
        
        if let currentTrack = audioPlayer?.currentTrack,
           let currentIndex = currentQueue.firstIndex(where: { $0.id == currentTrack.id }) {
            
            var tracksToShuffle = currentQueue
            tracksToShuffle.remove(at: currentIndex)
            tracksToShuffle.shuffle()
            
            currentQueue = [currentTrack] + tracksToShuffle
            currentQueueIndex = 0
        } else {
            currentQueue.shuffle()
            currentQueueIndex = 0
        }
    }
    
    // MARK: - Playback Control (unchanged)
    
    func playTrack(_ track: Track, fromTracks contextTracks: [Track]? = nil) {
        var queueTracks: [Track] = []
        
        if let contextTracks = contextTracks, !contextTracks.isEmpty {
            if let trackIndex = contextTracks.firstIndex(where: { $0.id == track.id }) {
                if isShuffleEnabled {
                    var tracksToShuffle = contextTracks
                    tracksToShuffle.remove(at: trackIndex)
                    tracksToShuffle.shuffle()
                    
                    queueTracks = [track] + tracksToShuffle
                    currentQueueIndex = 0
                } else {
                    queueTracks = contextTracks
                    currentQueueIndex = trackIndex
                }
            } else {
                queueTracks = [track]
                currentQueueIndex = 0
            }
        } else {
            queueTracks = [track]
            currentQueueIndex = 0
        }
        
        currentQueue = queueTracks
        currentPlaylist = nil
        
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    func playTrackFromPlaylist(_ playlist: Playlist, at index: Int) {
        guard index >= 0, index < playlist.tracks.count else { return }
        
        currentPlaylist = playlist
        currentQueueSource = .playlist
        
        let track = playlist.tracks[index]
        
        if isShuffleEnabled {
            var tracksToShuffle = playlist.tracks
            tracksToShuffle.remove(at: index)
            tracksToShuffle.shuffle()
            
            currentQueue = [track] + tracksToShuffle
            currentQueueIndex = 0
        } else {
            currentQueue = Array(playlist.tracks[index...])
            currentQueueIndex = 0
        }
        
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    func playTrackFromFolder(_ track: Track, folder: Folder, folderTracks: [Track]) {
        currentQueueSource = .folder
        currentPlaylist = nil
        
        if let trackIndex = folderTracks.firstIndex(where: { $0.id == track.id }) {
            if isShuffleEnabled {
                var tracksToShuffle = folderTracks
                tracksToShuffle.remove(at: trackIndex)
                tracksToShuffle.shuffle()
                
                currentQueue = [track] + tracksToShuffle
                currentQueueIndex = 0
            } else {
                currentQueue = Array(folderTracks[trackIndex...])
                currentQueueIndex = 0
            }
        } else {
            currentQueue = [track]
            currentQueueIndex = 0
        }
        
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    // MARK: - Track Navigation (unchanged)
    
    func playNextTrack() {
        guard !currentQueue.isEmpty else {
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
        
        switch repeatMode {
        case .one:
            nextIndex = currentQueueIndex
        case .all:
            nextIndex = (currentQueueIndex + 1) % currentQueue.count
        case .off:
            nextIndex = currentQueueIndex + 1
            if nextIndex >= currentQueue.count {
                return
            }
        }
        
        currentQueueIndex = nextIndex
        let track = currentQueue[nextIndex]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    func playPreviousTrack() {
        guard !currentQueue.isEmpty else {
            createLibraryQueue()
            return
        }
        
        if let currentTime = audioPlayer?.currentTime, currentTime > 3 {
            audioPlayer?.seekTo(time: 0)
            return
        }
        
        var prevIndex: Int
        
        switch repeatMode {
        case .one:
            prevIndex = currentQueueIndex
        case .all:
            prevIndex = currentQueueIndex > 0 ? currentQueueIndex - 1 : currentQueue.count - 1
        case .off:
            prevIndex = currentQueueIndex - 1
            if prevIndex < 0 {
                audioPlayer?.seekTo(time: 0)
                return
            }
        }
        
        currentQueueIndex = prevIndex
        let track = currentQueue[prevIndex]
        incrementPlayCount(for: track)
        audioPlayer?.playTrack(track)
    }
    
    func handleTrackCompletion() {
        switch repeatMode {
        case .one:
            guard let audioPlayer = audioPlayer else { return }
            audioPlayer.seekTo(time: 0)
            if let currentTrack = currentQueue.first(where: { _ in currentQueueIndex >= 0 && currentQueueIndex < currentQueue.count }) {
                audioPlayer.playTrack(currentQueue[currentQueueIndex])
            }
        case .all, .off:
            playNextTrack()
        }
    }
    
    // MARK: - Repeat and Shuffle (unchanged)
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            shuffleCurrentQueue()
        }
    }
    
    func toggleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Data Persistence
    
    func loadPlaylists() {
        guard let dbManager = libraryManager?.databaseManager else {
            return
        }
        
        let savedPlaylists = dbManager.loadAllPlaylists()
        
        let savedSmartPlaylists = savedPlaylists.filter { $0.type == .smart }
        let savedRegularPlaylists = savedPlaylists.filter { $0.type == .regular }
        
        if savedSmartPlaylists.isEmpty && !smartPlaylistsInitialized {
            let defaultSmartPlaylists = Playlist.createDefaultSmartPlaylists()
            
            for playlist in defaultSmartPlaylists {
                Task {
                    do {
                        try await dbManager.savePlaylistAsync(playlist)
                    } catch {
                        print("Failed to save default playlist: \(error)")
                    }
                }
            }
            
            playlists = sortPlaylists(smart: defaultSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = true
        } else {
            playlists = sortPlaylists(smart: savedSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = !savedSmartPlaylists.isEmpty
        }
        
        updateSmartPlaylists()
    }
    
    private func sortPlaylists(smart: [Playlist], regular: [Playlist]) -> [Playlist] {
        let smartPlaylistOrder: [SmartPlaylistType] = [.favorites, .mostPlayed, .recentlyPlayed]
        
        let sortedSmartPlaylists = smart.sorted { playlist1, playlist2 in
            guard let type1 = playlist1.smartType,
                  let type2 = playlist2.smartType else {
                return false
            }
            
            let index1 = smartPlaylistOrder.firstIndex(of: type1) ?? Int.max
            let index2 = smartPlaylistOrder.firstIndex(of: type2) ?? Int.max
            
            return index1 < index2
        }
        
        let sortedRegularPlaylists = regular.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        return sortedSmartPlaylists + sortedRegularPlaylists
    }
}
