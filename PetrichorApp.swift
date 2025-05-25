import SwiftUI

@main
struct PetrichorApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var windowDelegate = WindowDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator.audioPlayerManager)
                .environmentObject(appCoordinator.libraryManager)
                .environmentObject(appCoordinator.playlistManager)
                .background(WindowAccessor(windowDelegate: windowDelegate))
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)
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
        }
        
#if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appCoordinator.libraryManager)
        }
#endif
    }
}

// Helper to access the window
struct WindowAccessor: NSViewRepresentable {
    let windowDelegate: WindowDelegate
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = windowDelegate
                // Enable window restoration
                window.identifier = NSUserInterfaceItemIdentifier("MainWindow")
                window.setFrameAutosaveName("MainWindow")
                
                // Store window reference for reuse
                WindowManager.shared.mainWindow = window
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Window manager to track our main window
class WindowManager {
    static let shared = WindowManager()
    weak var mainWindow: NSWindow?
    
    private init() {}
}
