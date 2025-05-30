import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @AppStorage("globalViewType") private var globalViewType: LibraryViewType = .list
    @State private var selectedTab: MainTab = .library
    @State private var showingSettings = false
    @State private var showingQueue = false
    @State private var pendingLibraryFilter: LibraryFilterRequest?
    @State private var windowDelegate = WindowDelegate()
    
    var body: some View {
        VStack(spacing: 0) {
            // Contextual Toolbar - only show when we have music
            if !libraryManager.tracks.isEmpty {
                ContextualToolbar(
                    selectedTab: selectedTab,
                    viewType: $globalViewType
                )
                
                Divider()
            }

            // Main Content Area with Queue
            HSplitView {
                // Main content
                VStack {
                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                            case .library:
                            LibraryView(
                                viewType: globalViewType,
                                pendingFilter: $pendingLibraryFilter
                            )
                            case .folders:
                                FoldersView(viewType: globalViewType)
                            case .playlists:
                                PlaylistsView(viewType: globalViewType)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 400)
                
                // Queue sidebar
                if showingQueue {
                    PlayQueueView()
                        .frame(width: 350)
                }
            }
            
            // Player controls at bottom
            PlayerView(showingQueue: $showingQueue)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .goToLibraryFilter)) { notification in
            if let filterType = notification.userInfo?["filterType"] as? LibraryFilterType,
               let filterValue = notification.userInfo?["filterValue"] as? String {
                // Switch to Library tab
                selectedTab = .library
                // Store the filter request
                pendingLibraryFilter = LibraryFilterRequest(filterType: filterType, value: filterValue)
            }
        }
        .background(WindowAccessor(windowDelegate: windowDelegate))
        .navigationTitle("") // Remove any automatic title
        .toolbar {
            // Center tabs in title bar
            ToolbarItem(placement: .principal) {
                TabbedButtons(items: MainTab.allCases, selection: $selectedTab)
            }
            
            // Right side of title bar
            ToolbarItem(placement: .primaryAction) {
                HStack(alignment: .center, spacing: 8) {
                    // Background scanning indicator with fixed frame
                    ZStack {
                        // Always reserve space for the indicator
                        Color.clear
                            .frame(width: 24, height: 24)
                        
                        if libraryManager.isBackgroundScanning && !libraryManager.folders.isEmpty {
                            BackgroundScanningIndicator()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: libraryManager.isBackgroundScanning)
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24) // Fixed frame to match indicator
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(libraryManager)
        }
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

#Preview {
    ContentView()
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            // Set up library manager to show background scanning
            coordinator.libraryManager.isBackgroundScanning = true
            coordinator.libraryManager.folders = [Folder(url: URL(fileURLWithPath: "/Music"))]
            return coordinator.libraryManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.playlistManager
        }())
}
