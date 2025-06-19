import Foundation

extension PlaylistManager {
    // MARK: - Playback Control
    
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
    
    // MARK: - Track Navigation
    
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
    
    // MARK: - Repeat and Shuffle
    
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
}
