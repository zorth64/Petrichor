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
        print("App finished launching")
        
        // Ensure main window is visible
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
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
}
