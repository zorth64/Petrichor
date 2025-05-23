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
        // Any cleanup code can go here
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App finished launching")
    }
}
