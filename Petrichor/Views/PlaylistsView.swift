import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @State private var selectedPlaylist: Playlist?
    @State private var showingCreatePlaylist = false
    
    var body: some View {
        VStack {
            if playlistManager.playlists.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Playlists")
                        .font(.headline)
                    
                    Text("Create playlists to organize your music")
                        .foregroundColor(.secondary)
                    
                    Button("Create Playlist") {
                        showingCreatePlaylist = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Playlists grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                    ], spacing: 16) {
                        ForEach(playlistManager.playlists) { playlist in
                            PlaylistCard(playlist: playlist) {
                                selectedPlaylist = playlist
                            }
                        }
                        
                        // Add new playlist card
                        Button(action: { showingCreatePlaylist = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                                
                                Text("New Playlist")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistSheet()
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailSheet(playlist: playlist)
        }
    }
}

#Preview {
    PlaylistsView()
        .environmentObject({
            let manager = PlaylistManager()
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
}
