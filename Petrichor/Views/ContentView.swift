import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedSidebarItem: String? = "Library"
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                Text("Library").tag("Library")
                Text("Folders").tag("Folders")
                
                Section("Playlists") {
                    if playlistManager.playlists.isEmpty {
                        Text("No playlists yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(playlistManager.playlists) { playlist in
                            Text(playlist.name).tag("Playlist-\(playlist.id)")
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150)
            
            // Main content area
            VStack {
                if let selectedItem = selectedSidebarItem {
                    if selectedItem == "Library" {
                        LibraryView()
                    } else if selectedItem == "Folders" {
                        FoldersView()
                    } else if selectedItem.starts(with: "Playlist-") {
                        if let playlistId = UUID(uuidString: selectedItem.replacingOccurrences(of: "Playlist-", with: "")),
                           let playlist = playlistManager.playlists.first(where: { $0.id == playlistId }) {
                            PlaylistView(playlist: playlist)
                        }
                    }
                }
                
                Divider()
                
                // Player controls at bottom
                PlayerView()
                    .frame(height: 150)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            
            ToolbarItem {
                Button(action: { libraryManager.addFolder() }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
