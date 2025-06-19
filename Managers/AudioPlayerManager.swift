import Foundation
import AVFoundation

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // MARK: - Published Properties
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false {
        didSet {
            // Post notification when playback state changes
            NotificationCenter.default.post(name: NSNotification.Name("PlaybackStateChanged"), object: nil)
        }
    }
    @Published var currentTime: Double = 0
    @Published var volume: Float = 0.7
    @Published var restoredUITrack: Track?

    var player: AVAudioPlayer?

    // MARK: - Private Properties
    private var timer: Timer?
    private var stateTimer: Timer?
    private var restoredPosition: Double = 0

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

    func restoreUIState(_ uiState: PlaybackUIState) {
        // Create a temporary track object for UI display
        let tempTrack = Track(url: URL(fileURLWithPath: "/restored"))
        tempTrack.title = uiState.trackTitle
        tempTrack.artist = uiState.trackArtist
        tempTrack.album = uiState.trackAlbum
        tempTrack.artworkData = uiState.artworkData
        tempTrack.duration = uiState.trackDuration
        tempTrack.isMetadataLoaded = true

        // Set UI state
        restoredUITrack = tempTrack
        currentTrack = tempTrack
        restoredPosition = uiState.playbackPosition
        currentTime = uiState.playbackPosition
        volume = uiState.volume

        // Update Now Playing with restored info
        nowPlayingManager.updateNowPlayingInfo(track: tempTrack, currentTime: uiState.playbackPosition, isPlaying: false)
    }

    // MARK: - Playback Controls
    func playTrack(_ track: Track) {
        // Clear any restored UI state
        restoredUITrack = nil

        do {
            // Stop any current playback gracefully first
            if let currentPlayer = player {
                currentPlayer.setVolume(0, fadeDuration: 0.1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    currentPlayer.stop()
                }
            }

            // Create and prepare player
            player = try AVAudioPlayer(contentsOf: track.url)
            player?.delegate = self
            player?.prepareToPlay()

            // Start with zero volume to prevent pop
            player?.volume = 0
            player?.play()

            // Fade in to desired volume
            player?.setVolume(volume, fadeDuration: 0.2)

            // Update state
            currentTrack = track
            isPlaying = true
            restoredPosition = 0
            startStateSaveTimer()

            // Setup timer to update currentTime
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
            timer?.tolerance = 0.1

            // Update now playing info
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: currentTime, isPlaying: isPlaying)
        } catch {
            print("Failed to play track: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            // Fade out before pausing
            player.setVolume(0, fadeDuration: 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                player.pause()
                // Restore volume for next play
                player.volume = self.volume
            }
        } else {
            // Fade in when resuming
            player.volume = 0
            player.play()
            player.setVolume(volume, fadeDuration: 0.1)
        }

        isPlaying.toggle()

        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: currentTime, isPlaying: isPlaying)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // Add a small delay to prevent clicks between tracks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playlistManager.handleTrackCompletion()
            }
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        stateTimer?.invalidate()

        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: 0, isPlaying: false)
        }
    }

    // Graceful stop with fade out for app termination
    func stopGracefully() {
        guard let player = player, player.isPlaying else {
            isPlaying = false
            currentTime = 0
            timer?.invalidate()
            stateTimer?.invalidate()
            return
        }

        // Fade out
        player.setVolume(0, fadeDuration: 0.1)

        // Stop after fade completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.stop()
            player.volume = self.volume // Restore volume for next use

            self.isPlaying = false
            self.currentTime = 0
            self.timer?.invalidate()
            self.stateTimer?.invalidate()
        }
    }

    func seekTo(time: Double) {
        player?.currentTime = time
        currentTime = time
        restoredPosition = time

        if let track = currentTrack {
            nowPlayingManager.updateNowPlayingInfo(track: track, currentTime: time, isPlaying: isPlaying)
        }
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }

    var effectiveCurrentTime: Double {
        // If we have a player and it's been started, use its current time
        if let player = player, player.currentTime > 0 {
            return player.currentTime
        }
        // Otherwise, use the restored position
        return restoredPosition
    }

    // MARK: - Helpers

    private func startStateSaveTimer() {
        stateTimer?.invalidate()
        // Save state every 10 seconds during playback
        stateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            if self?.isPlaying == true {
                AppCoordinator.shared?.savePlaybackState()
            }
        }
    }
}
