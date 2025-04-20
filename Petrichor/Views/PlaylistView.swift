import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    let playlist: Playlist
    
    var body: some View {
        VStack {
            // Playlist header
            HStack(alignment: .top, spacing: 20) {
                // Playlist artwork
                if let artworkData = playlist.effectiveCoverArtwork,
                   let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .frame(width: 150, height: 150)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("PLAYLIST")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(playlist.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(playlist.tracks.count) songs • \(playlist.formattedTotalDuration)")
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: {
                            // Play the whole playlist
                            if !playlist.tracks.isEmpty {
                                playlistManager.playTrackFromPlaylist(playlist, at: 0)
                            }
                        }) {
                            Text("Play")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(playlist.tracks.isEmpty)
                        
                        Menu {
                            Button("Rename Playlist") {
                                // We'll implement this later
                            }
                            
                            Button("Delete Playlist", role: .destructive) {
                                playlistManager.deletePlaylist(playlist)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .padding(8)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.top, 5)
                }
                
                Spacer()
            }
            .padding([.horizontal, .top])
            
            Divider()
                .padding(.vertical)
            
            // Tracks list
            if playlist.tracks.isEmpty {
                ContentUnavailableView {
                    Label("Empty Playlist", systemImage: "music.note.list")
                } description: {
                    Text("Add some tracks to this playlist")
                }
            } else {
                List {
                    ForEach(playlist.tracks) { track in
                        HStack {
                            // Track number or playing indicator
                            if audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying {
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)
                            } else {
                                Text("\(playlist.tracks.firstIndex(where: { $0.id == track.id })! + 1)")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)
                            }
                            
                            // Use the TrackRow
                            TrackRow(track: track)
                        }
                        .onTapGesture {
                            if let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
                                playlistManager.playTrackFromPlaylist(playlist, at: index)
                                selectedTrackID = track.id
                            }
                        }
                        .background(selectedTrackID == track.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contextMenu {
                            Button("Play") {
                                if let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
                                    playlistManager.playTrackFromPlaylist(playlist, at: index)
                                }
                            }
                            
                            Button("Remove from Playlist", role: .destructive) {
                                playlistManager.removeTrackFromPlaylist(track: track, playlistID: playlist.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
    }
}
