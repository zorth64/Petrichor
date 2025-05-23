import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    
    var body: some View {
        VStack {
            if libraryManager.isScanning {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Scanning for music files...")
                        .font(.headline)
                    
                    Text("Found \(libraryManager.tracks.count) tracks so far")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if libraryManager.tracks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No music found")
                        .font(.headline)
                    
                    Text("Click 'Add Folder' to add music to your library")
                        .foregroundColor(.secondary)
                    
                    Button(action: { libraryManager.addFolder() }) {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show tracks list
                List {
                    ForEach(libraryManager.tracks) { track in
                        TrackRowContainer(
                            track: track,
                            isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                            isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                            isSelected: selectedTrackID == track.id,
                            onSelect: {
                                selectedTrackID = track.id
                            },
                            onPlay: {
                                audioPlayerManager.playTrack(track)
                                selectedTrackID = track.id
                            },
                            contextMenuItems: {
                                createLibraryContextMenu(for: track)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Context Menu Helper
    
    private func createLibraryContextMenu(for track: Track) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
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
        
        return items
    }
}

#Preview {
    LibraryView()
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
