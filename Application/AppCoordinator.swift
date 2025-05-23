//
//  AppCoordinator.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-04-19.
//


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
        
        // Setup now playing
        nowPlayingManager = NowPlayingManager()
        nowPlayingManager.connectRemoteCommandCenter(audioPlayer: audioPlayerManager, playlistManager: playlistManager)
    }
}