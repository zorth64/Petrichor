import SwiftUI

class AppCoordinator: ObservableObject {
    // MARK: - Managers
    static var shared: AppCoordinator?
    let libraryManager: LibraryManager
    let playlistManager: PlaylistManager
    let audioPlayerManager: AudioPlayerManager
    let nowPlayingManager: NowPlayingManager
    let menuBarManager: MenuBarManager
    
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
    }
}
