import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var selectedTab: MainTab = .library
    @State private var showingSettings = false
    @State private var showingQueue = false
    @AppStorage("globalViewType") private var globalViewType: LibraryViewType = .list
    
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
                                LibraryView(viewType: globalViewType)
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
        .navigationTitle("") // Remove any automatic title
        .toolbar {
            // Center tabs in title bar
            ToolbarItem(placement: .principal) {
                TitleBarTabs(selectedTab: $selectedTab)
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

// Modern tab component for titlebar
struct TitleBarTabs: View {
    @Binding var selectedTab: MainTab
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                TitleBarTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct TitleBarTabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(Color.white) :
                        isHovered ? AnyShapeStyle(Color.primary) :
                        AnyShapeStyle(Color.secondary)
                    )
                
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isHovered ? .primary :
                        .secondary
                    )
            }
            .frame(width: 90) // Fixed width for all tabs
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? Color.accentColor :
                        isHovered ? Color.primary.opacity(0.06) :
                        Color.clear
                    )
                    .animation(.easeOut(duration: 0.15), value: isSelected)
                    .animation(.easeOut(duration: 0.1), value: isHovered)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
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
