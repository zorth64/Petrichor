import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var selectedTab: MainTab = .library
    @State private var showingSettings = false
    @AppStorage("libraryViewType") private var libraryViewType: LibraryViewType = .list
    
    var body: some View {
        VStack(spacing: 0) {
            // Dynamic Toolbar based on selected tab
            DynamicToolbar(
                selectedTab: selectedTab,
                libraryViewType: $libraryViewType
            )
            
            Divider()
            
            // Main Content Area
            VStack {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                        case .library:
                            LibraryView(viewType: libraryViewType)
                        case .folders:
                            FoldersView(viewType: libraryViewType)
                        case .playlists:
                            PlaylistsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Player controls at bottom
                PlayerView()
            }
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
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
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
            return coordinator.libraryManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.playlistManager
        }())
}
