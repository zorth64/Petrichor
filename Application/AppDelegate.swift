import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Check user preference for background running
        let closeToTray = UserDefaults.standard.bool(forKey: "closeToTray")
        
        // If closeToTray is false, terminate when last window closes
        // If closeToTray is true, keep running in background
        return !closeToTray
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("App is terminating...")
        // Stop audio playback cleanly
        if let coordinator = AppCoordinator.shared {
            coordinator.audioPlayerManager.stop()
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
        // If no windows are visible, show the main window
        if !flag {
            // Create a new window if needed
            if NSApp.windows.isEmpty {
                // The window should be created by SwiftUI, just make it visible
                NSApp.activate(ignoringOtherApps: true)
            } else if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
