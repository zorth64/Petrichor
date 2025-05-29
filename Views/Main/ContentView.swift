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
