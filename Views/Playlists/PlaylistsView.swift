import SwiftUI

struct PlaylistsView: View {
    let viewType: LibraryViewType

    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedPlaylist: Playlist?
    @AppStorage("playlistSplitPosition") private var splitPosition: Double = 250
    
    var body: some View {
        if libraryManager.tracks.isEmpty {
            // Show unified empty state when no music exists
            NoMusicEmptyStateView(context: .mainWindow)
        } else {
            HSplitView {
                // Left sidebar - Playlists list
                PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
                    .frame(minWidth: 200, idealWidth: splitPosition, maxWidth: 400)
                
                // Right side - Playlist content
                VStack(spacing: 0) {
                    if let playlist = selectedPlaylist {
                        PlaylistDetailView(playlistID: playlist.id, viewType: viewType)
                    } else {
                        emptySelectionView
                    }
                }
                .frame(minWidth: 400)
            }
            .onAppear {
                // Select first playlist by default if none selected
                if selectedPlaylist == nil && !playlistManager.playlists.isEmpty {
                    selectedPlaylist = playlistManager.playlists.first
                }
            }
            .onChange(of: playlistManager.playlists.count) { _ in
                // Update selection if current playlist was removed
                if let selected = selectedPlaylist,
                   !playlistManager.playlists.contains(where: { $0.id == selected.id }) {
                    selectedPlaylist = playlistManager.playlists.first
                }
            }
        }
    }
    
    // MARK: - Empty Selection View
    
    private var emptySelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Select a Playlist")
                .font(.headline)
            
            Text("Choose a playlist from the sidebar to view its contents")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

#Preview("List View") {
    PlaylistsView(viewType: .list)
        .environmentObject({
            let manager = PlaylistManager()
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .environmentObject(LibraryManager())
        .frame(width: 800, height: 600)
}

#Preview("Grid View") {
    PlaylistsView(viewType: .grid)
        .environmentObject({
            let manager = PlaylistManager()
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .environmentObject(LibraryManager())
        .frame(width: 800, height: 600)
}
