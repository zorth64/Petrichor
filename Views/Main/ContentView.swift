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
    @State private var isSettingsHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Contextual Toolbar - only show when we have music
            if !libraryManager.tracks.isEmpty {
                contextualToolbar
                Divider()
            }

            // Main Content Area with Queue
            mainContentArea
            
            // Player controls at bottom
            playerControls
        }
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: .goToLibraryFilter), perform: handleLibraryFilter)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTrackInfo")), perform: handleShowTrackInfo)
        .background(WindowAccessor(windowDelegate: windowDelegate))
        .navigationTitle("")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(libraryManager)
        }
    }
    
    // MARK: - View Components
    
    private var contextualToolbar: some View {
        ContextualToolbar(
            selectedTab: selectedTab,
            viewType: $globalViewType
        )
        .frame(height: 40)
    }
    
    private var mainContentArea: some View {
        HSplitView {
            mainTabContent
            sidePanel
        }
        .frame(minHeight: 0, maxHeight: .infinity)
    }
    
    private var mainTabContent: some View {
        VStack {
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
        .frame(minWidth: 400, minHeight: 200)
    }
    
    @ViewBuilder
    private var sidePanel: some View {
        if showingQueue {
            PlayQueueView()
                .frame(width: 350)
        } else if showingTrackDetail, let track = detailTrack {
            TrackDetailView(track: track, onClose: hideTrackDetail)
                .frame(width: 350)
        }
    }
    
    private var playerControls: some View {
        PlayerView(showingQueue: Binding(
            get: { showingQueue },
            set: { newValue in
                if newValue {
                    showingTrackDetail = false
                    detailTrack = nil
                }
                showingQueue = newValue
                if let coordinator = AppCoordinator.shared {
                    coordinator.isQueueVisible = newValue
                }
            }
        ))
        .frame(height: 90)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TabbedButtons(items: MainTab.allCases, selection: $selectedTab)
        }
        
        ToolbarItem(placement: .primaryAction) {
            HStack(alignment: .center, spacing: 8) {
                backgroundScanningIndicator
                settingsButton
            }
        }
    }
    
    private var backgroundScanningIndicator: some View {
        ZStack {
            Color.clear
                .frame(width: 24, height: 24)
            
            if libraryManager.isBackgroundScanning && !libraryManager.folders.isEmpty {
                BackgroundScanningIndicator()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: libraryManager.isBackgroundScanning)
    }
    
    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gear")
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
                .foregroundColor(isSettingsHovered ? .primary : .secondary)
        }
        .buttonStyle(.borderless)
        .background(
            Circle()
                .fill(Color.gray.opacity(isSettingsHovered ? 0.1 : 0))
                .animation(.easeInOut(duration: 0.15), value: isSettingsHovered)
        )
        .onHover { hovering in
            isSettingsHovered = hovering
        }
        .help("Settings")
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        if let coordinator = AppCoordinator.shared {
            showingQueue = coordinator.isQueueVisible
        }
    }
    
    private func handleLibraryFilter(_ notification: Notification) {
        if let filterType = notification.userInfo?["filterType"] as? LibraryFilterType,
           let filterValue = notification.userInfo?["filterValue"] as? String {
            selectedTab = .library
            pendingLibraryFilter = LibraryFilterRequest(filterType: filterType, value: filterValue)
        }
    }
    
    private func handleShowTrackInfo(_ notification: Notification) {
        if let track = notification.userInfo?["track"] as? Track {
            showTrackDetail(for: track)
        }
    }
    
    // MARK: - Helper Methods
    
    private func showTrackDetail(for track: Track) {
        showingQueue = false
        detailTrack = track
        showingTrackDetail = true
    }

    private func hideTrackDetail() {
        showingTrackDetail = false
        detailTrack = nil
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let windowDelegate: WindowDelegate
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = windowDelegate
                window.identifier = NSUserInterfaceItemIdentifier("MainWindow")
                window.setFrameAutosaveName("MainWindow")
                WindowManager.shared.mainWindow = window
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Window Manager

class WindowManager {
    static let shared = WindowManager()
    weak var mainWindow: NSWindow?
    
    private init() {}
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            coordinator.libraryManager.isBackgroundScanning = true
            coordinator.libraryManager.folders = [Folder(url: URL(fileURLWithPath: "/Music"))]
            return coordinator.libraryManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.playlistManager
        }())
}
