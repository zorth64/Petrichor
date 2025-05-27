import SwiftUI

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var selectedPlaylist: Playlist?
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var selectedSidebarItem: PlaylistSidebarItem?
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            
            Divider()
            
            playlistsList
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            createPlaylistSheet
        }
        .onAppear {
            updateSelectedSidebarItem()
        }
        .onChange(of: selectedPlaylist) { _ in
            updateSelectedSidebarItem()
        }
    }
    
    // MARK: - Update Selection Helper
    
    private func updateSelectedSidebarItem() {
        if let playlist = selectedPlaylist {
            selectedSidebarItem = PlaylistSidebarItem(playlist: playlist)
        }
    }
    
    // MARK: - Sidebar Header
    
    private var sidebarHeader: some View {
        ListHeader {
            Text("Playlists")
                .headerTitleStyle()
            
            Spacer()
            
            Button(action: { showingCreatePlaylist = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Create New Playlist")
        }
    }
    
    // MARK: - Playlists List
    
    private var playlistsList: some View {
        SidebarView(
            items: allPlaylistItems,
            selectedItem: $selectedSidebarItem,
            onItemTap: { item in
                selectedPlaylist = item.playlist
            },
            contextMenuItems: { item in
                createContextMenuItems(for: item.playlist)
            },
            onRename: { item, newName in
                playlistManager.renamePlaylist(item.playlist, newName: newName)
            },
            showIcon: true,
            iconColor: .secondary,
            showCount: false
        )
    }
    
    private var allPlaylistItems: [PlaylistSidebarItem] {
        playlistManager.playlists.map { PlaylistSidebarItem(playlist: $0) }
    }
    
    // MARK: - Context Menu
    
    private func createContextMenuItems(for playlist: Playlist) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        if playlist.isUserEditable {
            items.append(.button(title: "Rename", action: {})) // Action handled by SidebarView
            items.append(.divider)
            items.append(.button(title: "Delete", role: .destructive, action: {
                playlistManager.deletePlaylist(playlist)
            }))
        }
        
        return items
    }
    
    // MARK: - Create Playlist Sheet
    
    private var createPlaylistSheet: some View {
        VStack(spacing: 20) {
            Text("New Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $newPlaylistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    newPlaylistName = ""
                    showingCreatePlaylist = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        let newPlaylist = playlistManager.createPlaylist(name: newPlaylistName)
                        selectedPlaylist = newPlaylist
                        newPlaylistName = ""
                        showingCreatePlaylist = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(newPlaylistName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
}

// MARK: - Preview

#Preview("Playlist Sidebar") {
    @State var selectedPlaylist: Playlist? = nil
    
    let previewManager = {
        let manager = PlaylistManager()
        
        // Create sample playlists
        let smartPlaylists = [
            Playlist(
                name: "Favorite Songs",
                smartType: .favorites,
                criteria: SmartPlaylistCriteria.favoritesPlaylist(),
                isUserEditable: false
            ),
            Playlist(
                name: "Top 25 Most Played",
                smartType: .mostPlayed,
                criteria: SmartPlaylistCriteria.mostPlayedPlaylist(limit: 25),
                isUserEditable: false
            ),
            Playlist(
                name: "Recently Played",
                smartType: .recentlyPlayed,
                criteria: SmartPlaylistCriteria.recentlyPlayedPlaylist(limit: 25, daysBack: 7),
                isUserEditable: false
            )
        ]
        
        // Create sample tracks for regular playlists
        let sampleTrack1 = Track(url: URL(fileURLWithPath: "/sample1.mp3"))
        sampleTrack1.title = "Sample Song 1"
        sampleTrack1.artist = "Artist 1"
        
        let sampleTrack2 = Track(url: URL(fileURLWithPath: "/sample2.mp3"))
        sampleTrack2.title = "Sample Song 2"
        sampleTrack2.artist = "Artist 2"
        
        let regularPlaylists = [
            Playlist(name: "My Favorites", tracks: [sampleTrack1, sampleTrack2]),
            Playlist(name: "Workout Mix", tracks: [sampleTrack1]),
            Playlist(name: "Relaxing Music", tracks: [])
        ]
        
        manager.playlists = smartPlaylists + regularPlaylists
        return manager
    }()
    
    return PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
        .environmentObject(previewManager)
        .frame(width: 250, height: 500)
}

#Preview("Empty Sidebar") {
    @State var selectedPlaylist: Playlist? = nil
    
    let emptyManager = PlaylistManager()
    
    return PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
        .environmentObject(emptyManager)
        .frame(width: 250, height: 500)
}
