import SwiftUI

class AppCoordinator: ObservableObject {
    // MARK: - Managers
    let libraryManager: LibraryManager
    let playlistManager: PlaylistManager
    let audioPlayerManager: AudioPlayerManager
    let nowPlayingManager: NowPlayingManager
    
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
    }
}
