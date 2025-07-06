import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Apply color mode very early, before any windows are shown
        let colorMode = UserDefaults.standard.string(forKey: "colorMode") ?? "auto"
        
        switch colorMode {
        case "Light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "Dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default: // "Auto" or any other value
            NSApp.appearance = nil // Follow system
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Check user preference for background running
        let closeToMenubar = UserDefaults.standard.bool(forKey: "closeToMenubar")
        
        // If closeToMenubar is false, terminate when last window closes
        // If closeToMenubar is true, keep running in background
        return !closeToMenubar
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("App is terminating...")
        
        // Stop audio playback gracefully to prevent clicks/pops
        if let coordinator = AppCoordinator.shared {
            coordinator.audioPlayerManager.stopGracefully()
            
            // Save playback state before terminating
            coordinator.savePlaybackState()
            
            // Force a database checkpoint to ensure all data is persisted
            coordinator.libraryManager.databaseManager.checkpoint()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Remove unwanted menus
        DispatchQueue.main.async {
            self.removeUnwantedMenus()
        }
        
        // Ensure main window is visible
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Observe playback changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackChanged),
            name: NSNotification.Name("PlaybackStateChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackChanged),
            name: NSNotification.Name("CurrentTrackChanged"),
            object: nil
        )
        
        print("App finished launching")
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Always restore dock icon when reopening
        NSApp.setActivationPolicy(.regular)
        
        // If we have a stored window reference, use it
        if let window = WindowManager.shared.mainWindow {
            window.makeKeyAndOrderFront(nil)
            return false // We handled it ourselves
        }
        
        // Otherwise let the system handle it
        return true
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Prevent creating new windows when clicking dock icon
        if UserDefaults.standard.bool(forKey: "closeToMenubar") {
            // If we have a window, show it
            if let window = WindowManager.shared.mainWindow {
                NSApp.setActivationPolicy(.regular)
                window.makeKeyAndOrderFront(nil)
            }
            return false
        }
        return true
    }
    
    // MARK: - Dock Menu
    
    @objc
    private func trackChanged() {
        // Force dock menu to update by invalidating the dock tile
        NSApp.dockTile.display()
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        guard let coordinator = AppCoordinator.shared else { return menu }
        let audioPlayerManager = coordinator.audioPlayerManager
        let playlistManager = coordinator.playlistManager
        
        // Now Playing header
        let nowPlayingItem = NSMenuItem(title: "Now Playing", action: nil, keyEquivalent: "")
        nowPlayingItem.isEnabled = false
        menu.addItem(nowPlayingItem)
        
        if let currentTrack = audioPlayerManager.currentTrack {
            // Song title
            let titleItem = NSMenuItem(title: "  \(currentTrack.title)", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            
            // Artist - Album
            var artistAlbumText = "  \(currentTrack.artist)"
            if !currentTrack.album.isEmpty && currentTrack.album != "Unknown Album" {
                artistAlbumText += " – \(currentTrack.album)"
            }
            let artistAlbumItem = NSMenuItem(title: artistAlbumText, action: nil, keyEquivalent: "")
            artistAlbumItem.isEnabled = false
            menu.addItem(artistAlbumItem)
            
            // Favorite action
            let favoriteTitle = currentTrack.isFavorite ? "Remove from Favorites" : "Add to Favorites"
            let favoriteItem = NSMenuItem(
                title: favoriteTitle,
                action: #selector(toggleFavorite),
                keyEquivalent: ""
            )
            favoriteItem.target = self
            menu.addItem(favoriteItem)
        } else {
            // No track playing
            let noTrackItem = NSMenuItem(title: "  No track playing", action: nil, keyEquivalent: "")
            noTrackItem.isEnabled = false
            menu.addItem(noTrackItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Repeat menu
        let repeatMenu = NSMenu()
        repeatMenu.autoenablesItems = false
        
        let repeatOffItem = NSMenuItem(
            title: "Off",
            action: #selector(setRepeatOff),
            keyEquivalent: ""
        )
        repeatOffItem.target = self
        repeatOffItem.state = playlistManager.repeatMode == .off ? .on : .off
        repeatMenu.addItem(repeatOffItem)
        
        let repeatOneItem = NSMenuItem(
            title: "One",
            action: #selector(setRepeatOne),
            keyEquivalent: ""
        )
        repeatOneItem.target = self
        repeatOneItem.state = playlistManager.repeatMode == .one ? .on : .off
        repeatMenu.addItem(repeatOneItem)
        
        let repeatAllItem = NSMenuItem(
            title: "All",
            action: #selector(setRepeatAll),
            keyEquivalent: ""
        )
        repeatAllItem.target = self
        repeatAllItem.state = playlistManager.repeatMode == .all ? .on : .off
        repeatMenu.addItem(repeatAllItem)
        
        let repeatMenuItem = NSMenuItem(title: "Repeat", action: nil, keyEquivalent: "")
        repeatMenuItem.submenu = repeatMenu
        menu.addItem(repeatMenuItem)
        
        // Shuffle toggle
        let shuffleItem = NSMenuItem(
            title: "Shuffle",
            action: #selector(toggleShuffle),
            keyEquivalent: ""
        )
        shuffleItem.target = self
        shuffleItem.state = playlistManager.isShuffleEnabled ? .on : .off
        menu.addItem(shuffleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Playback controls
        let playPauseTitle = audioPlayerManager.isPlaying ? "Pause" : "Play"
        let playPauseItem = NSMenuItem(
            title: playPauseTitle,
            action: #selector(togglePlayPause),
            keyEquivalent: ""
        )
        playPauseItem.target = self
        playPauseItem.isEnabled = audioPlayerManager.currentTrack != nil
        menu.addItem(playPauseItem)
        
        let nextItem = NSMenuItem(
            title: "Next",
            action: #selector(playNext),
            keyEquivalent: ""
        )
        nextItem.target = self
        nextItem.isEnabled = audioPlayerManager.currentTrack != nil
        menu.addItem(nextItem)

        let previousItem = NSMenuItem(
            title: "Previous",
            action: #selector(playPrevious),
            keyEquivalent: ""
        )
        previousItem.target = self
        previousItem.isEnabled = audioPlayerManager.currentTrack != nil
        menu.addItem(previousItem)
        
        return menu
    }
    
    // MARK: - Dock Menu Actions
    
    @objc
    private func toggleFavorite() {
        guard let coordinator = AppCoordinator.shared,
              let track = coordinator.audioPlayerManager.currentTrack else { return }
        
        coordinator.playlistManager.toggleFavorite(for: track)
    }
    
    @objc
    private func setRepeatOff() {
        AppCoordinator.shared?.playlistManager.repeatMode = .off
    }
    
    @objc
    private func setRepeatOne() {
        AppCoordinator.shared?.playlistManager.repeatMode = .one
    }
    
    @objc
    private func setRepeatAll() {
        AppCoordinator.shared?.playlistManager.repeatMode = .all
    }
    
    @objc
    private func toggleShuffle() {
        AppCoordinator.shared?.playlistManager.toggleShuffle()
    }
    
    @objc
    private func togglePlayPause() {
        AppCoordinator.shared?.audioPlayerManager.togglePlayPause()
    }
    
    @objc
    private func playNext() {
        AppCoordinator.shared?.playlistManager.playNextTrack()
    }
    
    @objc
    private func playPrevious() {
        AppCoordinator.shared?.playlistManager.playPreviousTrack()
    }
    
    private func removeUnwantedMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }
        
        // Remove File menu
        if let fileMenu = mainMenu.item(withTitle: "File") {
            mainMenu.removeItem(fileMenu)
        }
        
        // Remove Edit menu
        if let editMenu = mainMenu.item(withTitle: "Edit") {
            mainMenu.removeItem(editMenu)
        }
        
        // Remove Format menu
        if let formatMenu = mainMenu.item(withTitle: "Format") {
            mainMenu.removeItem(formatMenu)
        }
        
        // Modify View menu
        if let viewMenu = mainMenu.item(withTitle: "View"),
           let viewSubmenu = viewMenu.submenu {
            // Remove tab-related items
            if let showTabBar = viewSubmenu.item(withTitle: "Show Tab Bar") {
                viewSubmenu.removeItem(showTabBar)
            }
            if let showAllTabs = viewSubmenu.item(withTitle: "Show All Tabs") {
                viewSubmenu.removeItem(showAllTabs)
            }
        }
    }
}
