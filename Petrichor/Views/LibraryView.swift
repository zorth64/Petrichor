import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    
    var body: some View {
        VStack {
            if libraryManager.tracks.isEmpty {
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
                // Use the simpler List approach instead of Table
                List {
                    ForEach(libraryManager.tracks) { track in
                        TrackRow(track: track)
                            .onTapGesture {
                                audioPlayerManager.playTrack(track)
                                selectedTrackID = track.id
                            }
                            .background(selectedTrackID == track.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            .contextMenu {
                                Button("Play") {
                                    audioPlayerManager.playTrack(track)
                                }
                                
                                Menu("Add to Playlist") {
                                    ForEach(playlistManager.playlists) { playlist in
                                        Button(playlist.name) {
                                            playlistManager.addTrackToPlaylist(track: track, playlistID: playlist.id)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button("New Playlist...") {
                                        // We'll implement this later
                                    }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Library")
    }
}

// Track row for the list
struct TrackRow: View {
    let track: Track
    
    var body: some View {
        HStack {
            // Album art thumbnail if available
            if let artworkData = track.artworkData,
               let nsImage = NSImage(data: artworkData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Track information
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .fontWeight(.medium)
                
                HStack {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(track.album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
