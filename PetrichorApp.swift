import SwiftUI

@main
struct PetrichorApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("showFoldersTab")
    private var showFoldersTab = false

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
            // Remove the default Preferences menu item
            CommandGroup(replacing: .appSettings) {}
            
            // Replace the default About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About Petrichor") {
                    // Post notification to open Settings with About tab selected
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenSettingsAboutTab"),
                        object: nil
                    )
                }
            }
            
            // Add custom menu items under Petrichor menu
            CommandGroup(after: .appInfo) {
                Button("Settings") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("Play/Pause") {
                    appCoordinator.audioPlayerManager.togglePlayPause()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
            
            // Add to View menu
            CommandGroup(after: .toolbar) {
                Toggle("Folders tab", isOn: $showFoldersTab)
                    .keyboardShortcut("f", modifiers: [.command, .option])
            }
            
            // Customize the Help menu
            CommandGroup(replacing: .help) {
                Button("Petrichor Help") {
                    if let url = URL(string: About.appWiki) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
