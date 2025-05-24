import SwiftUI

struct FolderTracksContainer: View {
    let folder: Folder
    let viewType: LibraryViewType
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var folderTracks: [Track] = []
    @State private var isLoadingTracks = false
    
    var body: some View {
        Group {
            if isLoadingTracks {
                ProgressView("Loading tracks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderTracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Music Files")
                        .font(.headline)
                    
                    Text("No playable music files found in this folder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Group {
                    switch viewType {
                    case .list:
                        VirtualizedTrackList(
                            tracks: folderTracks,
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                playlistManager.setCurrentQueue(fromFolder: folder)
                                audioPlayerManager.playTrack(track)
                                selectedTrackID = track.id
                            },
                            contextMenuItems: { track in
                                createFolderContextMenu(for: track)
                            }
                        )
                    case .grid:
                        VirtualizedTrackGrid(
                            tracks: folderTracks,
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                playlistManager.setCurrentQueue(fromFolder: folder)
                                audioPlayerManager.playTrack(track)
                                selectedTrackID = track.id
                            },
                            contextMenuItems: { track in
                                createFolderContextMenu(for: track)
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            loadTracksIfNeeded()
        }
        .onDisappear {
            // Clear tracks when view disappears to free memory
            folderTracks.removeAll()
            isLoadingTracks = false
        }
    }
    
    private func loadTracksIfNeeded() {
        guard folderTracks.isEmpty else { return }
        
        isLoadingTracks = true
        
        // Load tracks asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let tracks = libraryManager.getTracksInFolder(folder)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.folderTracks = tracks
                self.isLoadingTracks = false
            }
        }
    }
    
    private func createFolderContextMenu(for track: Track) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
            playlistManager.setCurrentQueue(fromFolder: folder)
            audioPlayerManager.playTrack(track)
            selectedTrackID = track.id
        })
        
        if !playlistManager.playlists.isEmpty {
            let playlistItems = playlistManager.playlists.map { playlist in
                ContextMenuItem.button(title: playlist.name) {
                    playlistManager.addTrackToPlaylist(track: track, playlistID: playlist.id)
                }
            }
            
            var allPlaylistItems = playlistItems
            allPlaylistItems.append(.divider)
            allPlaylistItems.append(.button(title: "New Playlist...") {
                // TODO: Implement new playlist creation
            })
            
            items.append(.menu(title: "Add to Playlist", items: allPlaylistItems))
        } else {
            items.append(.button(title: "Create Playlist with This Track") {
                // TODO: Implement playlist creation
            })
        }
        
        items.append(.divider)
        items.append(.button(title: "Show in Finder") {
            NSWorkspace.shared.selectFile(track.url.path, inFileViewerRootedAtPath: folder.url.path)
        })
        
        return items
    }
}

#Preview {
    FolderTracksContainer(
        folder: Folder(url: URL(fileURLWithPath: "/Users/test/Music")),
        viewType: .list
    )
    .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
    .environmentObject(LibraryManager())
    .environmentObject(PlaylistManager())
}
