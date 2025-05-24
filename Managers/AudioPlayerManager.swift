import Foundation
import AVFoundation

class AudioPlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var volume: Float = 0.7
    
    // MARK: - Private Properties
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // MARK: - Dependencies
    private let libraryManager: LibraryManager
    private let playlistManager: PlaylistManager
    private let nowPlayingManager: NowPlayingManager
    
    // MARK: - Initialization
    init(libraryManager: LibraryManager, playlistManager: PlaylistManager) {
        self.libraryManager = libraryManager
        self.playlistManager = playlistManager
        self.nowPlayingManager = NowPlayingManager()
        
        // For macOS, we don't need to set up an audio session
    }
    
    deinit {
        stop()
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Playback Controls
    func playTrack(_ track: Track) {
        do {
            // Create and prepare player
            player = try AVAudioPlayer(contentsOf: track.url)
            player?.prepareToPlay()
            player?.volume = volume
            player?.play()
            
            // Update state
            currentTrack = track
            isPlaying = true
            
            // Setup timer to update currentTime
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.player else { return }
                self.currentTime = player.currentTime
                
                // Check if track finished
                if player.duration > 0 && player.currentTime >= player.duration - 0.1 {
                    self.playlistManager.handleTrackCompletion()
                }
            }
            
            // Update now playing info
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: currentTime, isPlaying: isPlaying)
        } catch {
            print("Failed to play track: \(error)")
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        
        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: currentTime, isPlaying: isPlaying)
        }
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        
        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: 0, isPlaying: false)
        }
    }
    
    func seekTo(time: Double) {
        player?.currentTime = time
        currentTime = time
        
        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: time, isPlaying: isPlaying)
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }
}
