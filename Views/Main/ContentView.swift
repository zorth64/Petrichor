import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @AppStorage("globalViewType") private var globalViewType: LibraryViewType = .table
    @State private var selectedTab: MainTab = .library
    @State private var showingSettings = false
    @State private var showingQueue = false
    @State private var showingTrackDetail = false
    @State private var detailTrack: Track?
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
                .frame(height: 40) // Fixed height for toolbar
                
                Divider()
            }

            // Main Content Area with Queue - make this the flexible part
            HSplitView {
                // Main content
                VStack {
                    // Content based on selected tab
                    ZStack {
                        LibraryView(
                            viewType: globalViewType,
                            pendingFilter: $pendingLibraryFilter
                        )
                        .opacity(selectedTab == .library ? 1 : 0)
                        .allowsHitTesting(selectedTab == .library)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        FoldersView(viewType: globalViewType)
                            .opacity(selectedTab == .folders ? 1 : 0)
                            .allowsHitTesting(selectedTab == .folders)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        PlaylistsView(viewType: globalViewType)
                            .opacity(selectedTab == .playlists ? 1 : 0)
                            .allowsHitTesting(selectedTab == .playlists)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 400, minHeight: 200) // Add minimum height for content
                
                // Queue/Track Detail sidebar
                if showingQueue {
                    PlayQueueView()
                        .frame(width: 350)
                } else if showingTrackDetail, let track = detailTrack {
                    TrackDetailView(track: track, onClose: hideTrackDetail)
                        .frame(width: 350)
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity) // Allow this to shrink
            
            // Player controls at bottom - keep this fixed
            PlayerView(showingQueue: Binding(
                get: { showingQueue },
                set: { newValue in
                    if newValue {
                        // If showing queue, hide track detail
                        showingTrackDetail = false
                        detailTrack = nil
                    }
                    showingQueue = newValue
                    // Sync with AppCoordinator when changed
                    if let coordinator = AppCoordinator.shared {
                        coordinator.isQueueVisible = newValue
                    }
                }
            ))
            .frame(height: 90) // Fixed height
        }
        .frame(minWidth: 1000, minHeight: 600) // Reduce minimum height
        .onAppear {
            // Restore queue visibility from AppCoordinator
            if let coordinator = AppCoordinator.shared {
                showingQueue = coordinator.isQueueVisible
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToLibraryFilter)) { notification in
            if let filterType = notification.userInfo?["filterType"] as? LibraryFilterType,
               let filterValue = notification.userInfo?["filterValue"] as? String {
                // Switch to Library tab
                selectedTab = .library
                // Store the filter request
                pendingLibraryFilter = LibraryFilterRequest(filterType: filterType, value: filterValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTrackInfo"))) { notification in
            if let track = notification.userInfo?["track"] as? Track {
                showTrackDetail(for: track)
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
    
    // MARK: - Track Detail Methods

    private func showTrackDetail(for track: Track) {
        // Close queue if open
        showingQueue = false
        
        // Show track detail
        detailTrack = track
        showingTrackDetail = true
    }

    private func hideTrackDetail() {
        showingTrackDetail = false
        detailTrack = nil
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
