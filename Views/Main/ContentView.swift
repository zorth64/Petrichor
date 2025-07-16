import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager

    @AppStorage("globalViewType")
    private var globalViewType: LibraryViewType = .table
    
    @AppStorage("entityViewType")
    private var entityViewType: LibraryViewType = .grid
    
    @AppStorage("rightSidebarSplitPosition")
    private var splitPosition: Double = 200
    
    @AppStorage("showFoldersTab")
    private var showFoldersTab = false
    
    @State private var selectedTab: Sections = .home
    @State private var showingSettings = false
    @State private var settingsInitialTab: SettingsView.SettingsTab = .general
    @State private var showingQueue = false
    @State private var showingTrackDetail = false
    @State private var detailTrack: Track?
    @State private var pendingLibraryFilter: LibraryFilterRequest?
    @State private var windowDelegate = WindowDelegate()
    @State private var isSettingsHovered = false
    @State private var homeShowingEntities: Bool = false
    @State private var secondaryWidth: CGFloat?
    @State private var primaryMaxX: CGFloat?
    @State private var primaryWidth: CGFloat?
    @State private var principalWidth: CGFloat?
    
    private var statusMinWidth: CGFloat? {
        if let primaryMaxX, let primaryWidth, let principalWidth, let secondaryWidth {
            min(secondaryWidth, max(0, primaryMaxX / 2 - principalWidth / 2 - primaryWidth - 30))
        } else {
            nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Main Content Area with Queue
            mainContentArea

            playerControls
                .animation(.easeInOut(duration: 0.3), value: libraryManager.folders.isEmpty)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear(perform: handleOnAppear)
        .contentViewNotificationHandlers(
            showingSettings: $showingSettings,
            selectedTab: $selectedTab,
            libraryManager: libraryManager,
            pendingLibraryFilter: $pendingLibraryFilter,
            showTrackDetail: showTrackDetail
        )
        .onChange(of: playbackManager.currentTrack?.id) { oldId, _ in
            if showingTrackDetail,
               let detailTrack = detailTrack,
               detailTrack.id == oldId,
               let newTrack = playbackManager.currentTrack {
                self.detailTrack = newTrack
            }
        }
        .onChange(of: libraryManager.globalSearchText) { _, newValue in
            if !newValue.isEmpty && selectedTab != .library {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .library
                }
            }
        }
        .onChange(of: showFoldersTab) { _, newValue in
            if !newValue && selectedTab == .folders {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .home
                }
            }
        }
        .background(WindowAccessor(windowDelegate: windowDelegate))
        .navigationTitle("")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(libraryManager)
        }
    }

    // MARK: - View Components

    private var mainContentArea: some View {
        PersistentSplitView(
            main: {
                sectionContent
            },
            right: {
                sidePanel
            },
            rightStorageKey: "rightSidebarSplitPosition"
        )
        .frame(minHeight: 0, maxHeight: .infinity)
    }

    private var sectionContent: some View {
        VStack {
            ZStack {
                HomeView(isShowingEntities: $homeShowingEntities)
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LibraryView(
                    viewType: globalViewType,
                    pendingFilter: $pendingLibraryFilter
                )
                .opacity(selectedTab == .library ? 1 : 0)
                .allowsHitTesting(selectedTab == .library)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PlaylistsView(viewType: globalViewType)
                    .opacity(selectedTab == .playlists ? 1 : 0)
                    .allowsHitTesting(selectedTab == .playlists)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showFoldersTab == true {
                    FoldersView(viewType: globalViewType)
                        .opacity(selectedTab == .folders ? 1 : 0)
                        .allowsHitTesting(selectedTab == .folders)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.none, value: selectedTab)
        }
        .frame(minWidth: 400, minHeight: 200)
    }

    @ViewBuilder
    private var sidePanel: some View {
        if showingQueue {
            PlayQueueView(showingQueue: $showingQueue)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    )
                )
        } else if showingTrackDetail, let track = detailTrack {
            TrackDetailView(track: track, onClose: hideTrackDetail)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    )
                )
        }
    }

    @ViewBuilder
    private var playerControls: some View {
        if !libraryManager.folders.isEmpty && !libraryManager.tracks.isEmpty {
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
            .background(Color(NSColor.windowBackgroundColor))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .secondaryAction) {
            HStack(spacing: 0) {
                // Persistent Contextual Toolbar - always present when we have music
                if !libraryManager.folders.isEmpty && !libraryManager.tracks.isEmpty {
                    ContextualToolbar(
                        viewType: Binding(
                            get: {
                                if selectedTab == .home && homeShowingEntities {
                                    return entityViewType
                                }
                                return globalViewType
                            },
                            set: { newValue in
                                if selectedTab == .home && homeShowingEntities {
                                    entityViewType = newValue
                                } else {
                                    globalViewType = newValue
                                }
                            }
                        ),
                        disableTableView: selectedTab == .home && homeShowingEntities
                    )
                    .frame(height: 40)
                }
            }
            .padding(.trailing, 50)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).width
            } action: { width in
                secondaryWidth = width
            }
        }
        
        ToolbarItem(placement: .principal) {
            TabbedButtons(
                items: Sections.allCases.filter { $0 != .folders || showFoldersTab },
                selection: $selectedTab,
                animation: .transform,
                isDisabled: libraryManager.folders.isEmpty
            )
			.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).width
            } action: { width in
                principalWidth = width
            }
        }
        
        ToolbarItem(placement: .status) {
            Color.clear.frame(minWidth: statusMinWidth, idealWidth: statusMinWidth, maxWidth: statusMinWidth)
        }

        ToolbarItem(placement: .primaryAction) {
            HStack(alignment: .center, spacing: 8) {
                NotificationTray()
                    .frame(width: 24, height: 24)
                searchField
                settingsButton
            }
			.onGeometryChange(for: PrimaryActionMetrics.self) { proxy in
                let frame = proxy.frame(in: .global)
                return PrimaryActionMetrics(maxX: frame.maxX, width: frame.width)
            } action: { metrics in
                primaryMaxX = metrics.maxX
                primaryWidth = metrics.width
            }
        }
    }
	
	// MARK: - Search Input Field
    private var searchField: some View {
        HStack(spacing: 6) {
            // TODO we should ideally replace this with `.searchable`
            // which provides this UX without log of extra code, although
            // it would require titlebar layout changes.
            SearchInputField(
                text: $libraryManager.globalSearchText,
                placeholder: "Search",
                fontSize: 12,
                width: 280
            )
            .frame(width: 280)
        }
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
                .animation(.easeInOut(duration: AnimationDuration.standardDuration), value: isSettingsHovered)
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
        withAnimation(.easeInOut(duration: 0.3)) {
            showingQueue = false
            detailTrack = track
            showingTrackDetail = true
        }
    }

    private func hideTrackDetail() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingTrackDetail = false
            detailTrack = nil
        }
    }
    
    private struct PrimaryActionMetrics: Equatable {
        let maxX: CGFloat
        let width: CGFloat
    }
}

extension View {
    func contentViewNotificationHandlers(
        showingSettings: Binding<Bool>,
        selectedTab: Binding<Sections>,
        libraryManager: LibraryManager,
        pendingLibraryFilter: Binding<LibraryFilterRequest?>,
        showTrackDetail: @escaping (Track) -> Void
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .goToLibraryFilter)) { notification in
                if let filterType = notification.userInfo?["filterType"] as? LibraryFilterType,
                   let filterValue = notification.userInfo?["filterValue"] as? String {
                    withAnimation(.easeInOut(duration: AnimationDuration.standardDuration)) {
                        selectedTab.wrappedValue = .library
                        pendingLibraryFilter.wrappedValue = LibraryFilterRequest(filterType: filterType, value: filterValue)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTrackInfo"))) { notification in
                if let track = notification.userInfo?["track"] as? Track {
                    showTrackDetail(track)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))) { _ in
                showingSettings.wrappedValue = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettingsAboutTab"))) { _ in
                showingSettings.wrappedValue = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SettingsSelectTab"),
                        object: SettingsView.SettingsTab.about
                    )
                }
            }
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
                window.title = ""
                window.isExcludedFromWindowsMenu = true
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
            return coordinator.playbackManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            NotificationManager.shared.isActivityInProgress = true
            coordinator.libraryManager.folders = [Folder(url: URL(fileURLWithPath: "/Music"))]
            return coordinator.libraryManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.playlistManager
        }())
}
