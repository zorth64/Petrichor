import SwiftUI

class AppCoordinator: ObservableObject {
    // MARK: - Managers
    static var shared: AppCoordinator?
    let libraryManager: LibraryManager
    let playlistManager: PlaylistManager
    let audioPlayerManager: AudioPlayerManager
    let nowPlayingManager: NowPlayingManager
    let menuBarManager: MenuBarManager
    
    private let playbackStateKey = "SavedPlaybackState"
    private let playbackUIStateKey = "SavedPlaybackUIState"
    
    @Published var isQueueVisible: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // Initialize managers
        libraryManager = LibraryManager()
        playlistManager = PlaylistManager()
        
        // Create audio player with dependencies
        audioPlayerManager = AudioPlayerManager(libraryManager: libraryManager, playlistManager: playlistManager)
        
        // Connect managers
        playlistManager.setAudioPlayer(audioPlayerManager)
        playlistManager.setLibraryManager(libraryManager)
        
        // Setup now playing
        nowPlayingManager = NowPlayingManager()
        nowPlayingManager.connectRemoteCommandCenter(audioPlayer: audioPlayerManager, playlistManager: playlistManager)
        
        // Setup menubar
        menuBarManager = MenuBarManager(audioPlayerManager: audioPlayerManager, playlistManager: playlistManager)
        
        Self.shared = self
        
        // Restore UI state immediately
        restoreUIStateImmediately()

        // Schedule restoration after a delay to ensure everything is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restorePlaybackState()
        }
    }
    
    // MARK: - Playback State Persistence
    
    func savePlaybackState() {
        // Only save if we have a current track
        guard let currentTrack = audioPlayerManager.currentTrack else {
            // Clear saved state if no track
            UserDefaults.standard.removeObject(forKey: playbackStateKey)
            UserDefaults.standard.removeObject(forKey: playbackUIStateKey)
            return
        }
        
        // Determine source identifier
        var sourceIdentifier: String? = nil
        switch playlistManager.currentQueueSource {
        case .folder:
            // Try to find the folder containing the current track
            if let folderId = currentTrack.folderId,
               let folder = libraryManager.folders.first(where: { $0.id == folderId }) {
                sourceIdentifier = folder.url.path
            }
        case .playlist:
            sourceIdentifier = playlistManager.currentPlaylist?.id.uuidString
        default:
            break
        }
        
        let state = PlaybackState(
            currentTrack: currentTrack,
            playbackPosition: audioPlayerManager.effectiveCurrentTime,
            queueVisible: isQueueVisible,
            queue: playlistManager.currentQueue,
            currentQueueIndex: playlistManager.currentQueueIndex,
            queueSource: playlistManager.currentQueueSource,
            sourceIdentifier: sourceIdentifier,
            volume: audioPlayerManager.volume,
            isMuted: audioPlayerManager.volume < 0.01, // Consider very low volume as muted
            shuffleEnabled: playlistManager.isShuffleEnabled,
            repeatMode: playlistManager.repeatMode
        )
        
        if let uiState = state.createUIState(from: currentTrack) {
            if let uiData = try? JSONEncoder().encode(uiState) {
                UserDefaults.standard.set(uiData, forKey: playbackUIStateKey)
            }
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: playbackStateKey)
            print("AppCoordinator: Saved playback state")
        } catch {
            print("AppCoordinator: Failed to save playback state: \(error)")
        }
    }
    
    func restoreUIStateImmediately() {
        // Try to restore UI state immediately
        guard let uiData = UserDefaults.standard.data(forKey: playbackUIStateKey),
              let uiState = try? JSONDecoder().decode(PlaybackUIState.self, from: uiData) else {
            return
        }
        
        // Restore UI immediately
        audioPlayerManager.restoreUIState(uiState)
        isQueueVisible = uiState.queueVisible
        
        print("AppCoordinator: Restored UI state immediately")
    }
    
    func restorePlaybackState() {
        // Don't restore immediately - wait for library to be fully loaded
        // Check if we have tracks loaded
        if libraryManager.tracks.isEmpty {
            print("AppCoordinator: Delaying playback restoration until library is loaded")
            
            // Observe for library changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(libraryDidLoad),
                name: NSNotification.Name("LibraryDidLoad"),
                object: nil
            )
            return
        }
        
        // If library is already loaded, proceed with restoration
        performActualRestoration()
    }
    
    @objc private func libraryDidLoad() {
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("LibraryDidLoad"), object: nil)
        
        // Now perform restoration
        performActualRestoration()
    }

    private func performActualRestoration() {
        guard let data = UserDefaults.standard.data(forKey: playbackStateKey) else {
            print("AppCoordinator: No saved playback state found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let state = try decoder.decode(PlaybackState.self, from: data)
            
            print("AppCoordinator: Restoring playback state from \(state.savedDate)")
            
            // Now perform restoration immediately since library is loaded
            performStateRestoration(state)
        } catch {
            print("AppCoordinator: Failed to restore playback state: \(error)")
            UserDefaults.standard.removeObject(forKey: playbackStateKey)
        }
    }
    
    private func performStateRestoration(_ state: PlaybackState) {
        // Add version check
        if state.version != PlaybackState.currentVersion {
            print("AppCoordinator: State version mismatch (saved: \(state.version), current: \(PlaybackState.currentVersion)), clearing state")
            UserDefaults.standard.removeObject(forKey: playbackStateKey)
            return
        }
        
        // Wrap the entire restoration in a do-catch
        do {
            // Check if the saved state is too old
            let daysSinceSaved = Date().timeIntervalSince(state.savedDate) / (24 * 60 * 60)
            if daysSinceSaved > 7 {
                print("AppCoordinator: Saved state is too old (\(Int(daysSinceSaved)) days), discarding")
                UserDefaults.standard.removeObject(forKey: playbackStateKey)
                return
            }
            
            // Verify we have necessary folders with valid bookmarks
            var hasValidBookmarks = false
            for folder in libraryManager.folders {
                if folder.url.startAccessingSecurityScopedResource() {
                    hasValidBookmarks = true
                    // Don't stop accessing here - let normal cleanup handle it
                }
            }
            
            guard hasValidBookmarks else {
                print("AppCoordinator: No valid security bookmarks available, clearing state")
                UserDefaults.standard.removeObject(forKey: playbackStateKey)
                return
            }
            
            // First, try to restore the queue
            var restoredQueue: [Track] = []
            
            // Try to match tracks by database ID first, then by path
            for (index, trackId) in state.queueTrackIds.enumerated() {
                if let track = libraryManager.tracks.first(where: { $0.trackId == trackId }) {
                    restoredQueue.append(track)
                } else if index < state.queueTrackPaths.count {
                    // Fallback to path matching
                    let path = state.queueTrackPaths[index]
                    if let track = libraryManager.tracks.first(where: { $0.url.path == path }) {
                        restoredQueue.append(track)
                    }
                }
            }
            
            // Check if we restored enough of the queue
            let restorationRatio = Double(restoredQueue.count) / Double(state.queueTrackPaths.count)
            if restorationRatio < 0.5 {
                print("AppCoordinator: Could only restore \(Int(restorationRatio * 100))% of the queue, discarding state")
                UserDefaults.standard.removeObject(forKey: playbackStateKey)
                return
            }
            
            // Only proceed if we found at least some tracks
            guard !restoredQueue.isEmpty else {
                print("AppCoordinator: Could not restore any tracks from saved queue")
                UserDefaults.standard.removeObject(forKey: playbackStateKey)
                return
            }
            
            // Restore playback settings first
            playlistManager.isShuffleEnabled = state.shuffleEnabled
            playlistManager.repeatMode = state.repeatModeEnum
            audioPlayerManager.setVolume(state.isMuted ? 0 : state.volume)
            
            // Set the queue
            playlistManager.currentQueue = restoredQueue
            playlistManager.currentQueueIndex = min(state.currentQueueIndex, restoredQueue.count - 1)
            playlistManager.currentQueueSource = state.queueSourceEnum
            
            // Try to restore the source context
            switch state.queueSourceEnum {
            case .playlist:
                if let playlistId = state.sourceIdentifier,
                   let uuid = UUID(uuidString: playlistId),
                   let playlist = playlistManager.playlists.first(where: { $0.id == uuid }) {
                    playlistManager.currentPlaylist = playlist
                }
            default:
                break
            }
            
            // Restore UI state
            isQueueVisible = state.queueVisible
            
            // Find and prepare the current track
            if let currentTrackId = state.currentTrackId,
               let currentTrack = restoredQueue.first(where: { $0.trackId == currentTrackId }) {
                
                // Verify the file exists and is accessible
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: currentTrack.url.path) else {
                    print("AppCoordinator: Track file no longer exists, clearing state")
                    UserDefaults.standard.removeObject(forKey: playbackStateKey)
                    return
                }
                
                // Try to access the file
                guard fileManager.isReadableFile(atPath: currentTrack.url.path) else {
                    print("AppCoordinator: Track file is not readable, clearing state")
                    UserDefaults.standard.removeObject(forKey: playbackStateKey)
                    return
                }
                
                // Clear the temporary UI track before setting the real one
                audioPlayerManager.restoredUITrack = nil
                
                // Set up the audio player without playing
                audioPlayerManager.playTrack(currentTrack)
                audioPlayerManager.player?.pause()
                audioPlayerManager.isPlaying = false
                
                // Seek to saved position
                if state.playbackPosition > 0 && state.playbackPosition < state.trackDuration {
                    audioPlayerManager.seekTo(time: state.playbackPosition)
                }
                
                print("AppCoordinator: Successfully restored playback state")
            }
        } catch {
            print("AppCoordinator: Error during state restoration: \(error), clearing state")
            UserDefaults.standard.removeObject(forKey: playbackStateKey)
        }
    }
    
    func clearPlaybackStateIfNeeded() {
        let lastVersionKey = "LastLaunchedAppVersion"
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey)
        
        // If this is a different version, consider clearing state
        if lastVersion != currentVersion {
            print("AppCoordinator: App version changed from \(lastVersion ?? "unknown") to \(currentVersion)")
            
            // You can add logic here to clear state for specific version transitions
            // For now, we'll just log it
            
            // Update the stored version
            UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        }
    }
    
    func handleLibraryChanged() {
        // If the library was significantly changed (e.g., folders removed),
        // the saved state might no longer be valid
        if let savedStateData = UserDefaults.standard.data(forKey: playbackStateKey),
           let state = try? JSONDecoder().decode(PlaybackState.self, from: savedStateData) {
            
            // Check if the current track still exists
            if let trackId = state.currentTrackId {
                let trackExists = libraryManager.tracks.contains { $0.trackId == trackId }
                if !trackExists {
                    print("AppCoordinator: Saved track no longer exists in library, clearing state")
                    UserDefaults.standard.removeObject(forKey: playbackStateKey)
                }
            }
            
            // Also check UI state validity
            if let uiData = UserDefaults.standard.data(forKey: playbackUIStateKey),
               let _ = try? JSONDecoder().decode(PlaybackUIState.self, from: uiData) {
                // If the main state is invalid, clear UI state too
                if UserDefaults.standard.data(forKey: playbackStateKey) == nil {
                    UserDefaults.standard.removeObject(forKey: playbackUIStateKey)
                }
            }
        }
    }
}
