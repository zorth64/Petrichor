import SwiftUI

@main
struct PetrichorApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator.audioPlayerManager)
                .environmentObject(appCoordinator.libraryManager)
                .environmentObject(appCoordinator.playlistManager)
                .onAppear {
                    // Ensure window is visible on launch
                    if let window = NSApp.mainWindow {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("Add Folder") {
                    appCoordinator.libraryManager.addFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Play/Pause") {
                    appCoordinator.audioPlayerManager.togglePlayPause()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
        
#if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appCoordinator.libraryManager)
        }
#endif
    }
}
