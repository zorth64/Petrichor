import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    let playlist: Playlist
    
    var body: some View {
        VStack(spacing: 0) {
            // Playlist header
            playlistHeader
            
            Divider()
            
            // Tracks list
            if playlist.tracks.isEmpty {
                emptyPlaylistView
            } else {
                tracksListView
            }
        }
    }
    
    // MARK: - Playlist Header
    
    private var playlistHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            // Playlist artwork
            Group {
                if let artworkData = playlist.effectiveCoverArtwork,
                   let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            // Playlist info and controls
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAYLIST")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(playlist.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(playlist.tracks.count) songs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if playlist.tracks.count > 0 {
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(playlist.formattedTotalDuration)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Control buttons
                HStack(spacing: 12) {
                    Button(action: {
                        // Play the whole playlist
                        if !playlist.tracks.isEmpty {
                            playlistManager.playTrackFromPlaylist(playlist, at: 0)
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Play")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(playlist.tracks.isEmpty)
                    
                    Button(action: {
                        // Shuffle play
                        if !playlist.tracks.isEmpty {
                            playlistManager.toggleShuffle()
                            playlistManager.playTrackFromPlaylist(playlist, at: 0)
                        }
                    }) {
                        HStack {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14))
                            Text("Shuffle")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playlist.tracks.isEmpty)
                    
                    Menu {
                        Button("Rename Playlist") {
                            // TODO: Implement rename functionality
                        }
                        
                        Button("Export Playlist...") {
                            // TODO: Implement export functionality
                        }
                        
                        Divider()
                        
                        Button("Delete Playlist", role: .destructive) {
                            playlistManager.deletePlaylist(playlist)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .padding(8)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Empty Playlist View
    
    private var emptyPlaylistView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Empty Playlist")
                .font(.headline)
            
            Text("Add some tracks to this playlist to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Browse Library") {
                // TODO: Switch to library view or implement track picker
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Tracks List View
    
    private var tracksListView: some View {
        List {
            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                TrackRowContainer(
                    track: track,
                    trackNumber: index + 1,
                    isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                    isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                    isSelected: selectedTrackID == track.id,
                    onSelect: {
                        selectedTrackID = track.id
                    },
                    onPlay: {
                        playlistManager.playTrackFromPlaylist(playlist, at: index)
                        selectedTrackID = track.id
                    },
                    contextMenuItems: {
                        createPlaylistContextMenu(for: track, at: index)
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Context Menu Helper
    
    private func createPlaylistContextMenu(for track: Track, at index: Int) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
            playlistManager.playTrackFromPlaylist(playlist, at: index)
            selectedTrackID = track.id
        })
        
        items.append(.button(title: "Play Next") {
            // TODO: Implement play next functionality
        })
        
        items.append(.divider)
        
        // Add to other playlists
        let otherPlaylists = playlistManager.playlists.filter { $0.id != playlist.id }
        if !otherPlaylists.isEmpty {
            let playlistItems = otherPlaylists.map { otherPlaylist in
                ContextMenuItem.button(title: otherPlaylist.name) {
                    playlistManager.addTrackToPlaylist(track: track, playlistID: otherPlaylist.id)
                }
            }
            
            var allPlaylistItems = playlistItems
            allPlaylistItems.append(.divider)
            allPlaylistItems.append(.button(title: "New Playlist...") {
                // TODO: Implement new playlist creation
            })
            
            items.append(.menu(title: "Add to Playlist", items: allPlaylistItems))
            items.append(.divider)
        }
        
        // Track reordering
        items.append(.button(title: "Move Up") {
            if index > 0 {
                var updatedPlaylist = playlist
                updatedPlaylist.moveTrack(from: index, to: index - 1)
                playlistManager.updatePlaylist(updatedPlaylist)
            }
        })
        
        items.append(.button(title: "Move Down") {
            if index < playlist.tracks.count - 1 {
                var updatedPlaylist = playlist
                updatedPlaylist.moveTrack(from: index, to: index + 1)
                playlistManager.updatePlaylist(updatedPlaylist)
            }
        })
        
        items.append(.divider)
        items.append(.button(title: "Remove from Playlist", role: .destructive) {
            playlistManager.removeTrackFromPlaylist(track: track, playlistID: playlist.id)
        })
        
        return items
    }
}

#Preview {
    let samplePlaylist = Playlist(name: "My Favorite Songs", tracks: [])
    
    return PlaylistView(playlist: samplePlaylist)
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.playlistManager
        }())
        .frame(height: 600)
}
