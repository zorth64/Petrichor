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
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "main"))
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

            CommandGroup(replacing: .appTermination) {
                Button("Quit Petrichor") {
                    // Ensure database is saved before quitting
                    if let coordinator = AppCoordinator.shared {
                        coordinator.libraryManager.databaseManager.checkpoint()
                    }
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
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
