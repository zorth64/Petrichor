import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: UUID
    let viewType: LibraryViewType
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var showingAddSongs = false
    
    // Get the current playlist from the manager
    private var playlist: Playlist? {
        playlistManager.playlists.first { $0.id == playlistID }
    }
    
    var body: some View {
        if let playlist = playlist {
            VStack(spacing: 0) {
                // Playlist header
                playlistHeader
                
                Divider()
                
                // Tracks content
                if playlist.tracks.isEmpty {
                    emptyPlaylistView
                } else {
                    Group {
                        switch viewType {
                        case .list:
                            VirtualizedTrackList(
                                tracks: playlist.tracks,
                                selectedTrackID: $selectedTrackID,
                                onPlayTrack: { track in
                                    if let index = playlist.tracks.firstIndex(of: track) {
                                        playlistManager.playTrackFromPlaylist(playlist, at: index)
                                        selectedTrackID = track.id
                                    }
                                },
                                contextMenuItems: { track in
                                    createPlaylistContextMenu(for: track)
                                }
                            )
                        case .grid:
                            VirtualizedTrackGrid(
                                tracks: playlist.tracks,
                                selectedTrackID: $selectedTrackID,
                                onPlayTrack: { track in
                                    if let index = playlist.tracks.firstIndex(of: track) {
                                        playlistManager.playTrackFromPlaylist(playlist, at: index)
                                        selectedTrackID = track.id
                                    }
                                },
                                contextMenuItems: { track in
                                    createPlaylistContextMenu(for: track)
                                }
                            )
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                }
            }
            .sheet(isPresented: $showingAddSongs) {
                AddSongsToPlaylistSheet(playlist: playlist)
            }
            .onChange(of: playlistID) { _ in
                // Reset selection when playlist changes
                selectedTrackID = nil
            }
        } else {
            // Playlist not found
            VStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("Playlist not found")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }
    
    // MARK: - Playlist Header
    
    @ViewBuilder
    private var playlistHeader: some View {
        if let playlist = playlist {
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
                                Image(systemName: playlistIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                // Playlist info and controls
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlistTypeText)
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
                        
                        // Add songs button for regular playlists
                        if playlist.type == .regular {
                            Button(action: { showingAddSongs = true }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                    Text("Add Songs")
                                    .font(.system(size: 14))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
    
    // MARK: - Empty Playlist View
    
    @ViewBuilder
    private var emptyPlaylistView: some View {
        if let playlist = playlist {
            VStack(spacing: 20) {
                Image(systemName: playlistIcon)
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text(emptyStateTitle)
                    .font(.headline)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                
                if playlist.type == .regular {
                    Button("Add Songs") {
                        showingAddSongs = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(NSColor.textBackgroundColor))
        }
    }
    
    // MARK: - Helper Properties
    
    private var playlistIcon: String {
        guard let playlist = playlist else { return "music.note.list" }
        
        switch playlist.smartType {
        case .favorites:
            return "star.fill"
        case .mostPlayed:
            return "play.circle.fill"
        case .recentlyPlayed:
            return "clock.fill"
        case .custom, .none:
            return "music.note.list"
        }
    }
    
    private var playlistTypeText: String {
        guard let playlist = playlist else { return "" }
        
        switch playlist.type {
        case .smart:
            return "SMART PLAYLIST"
        case .regular:
            return "PLAYLIST"
        }
    }
    
    private var emptyStateTitle: String {
        guard let playlist = playlist else { return "Empty Playlist" }
        
        switch playlist.smartType {
        case .favorites:
            return "No Favorite Songs"
        case .mostPlayed:
            return "No Frequently Played Songs"
        case .recentlyPlayed:
            return "No Recently Played Songs"
        case .custom, .none:
            return "Empty Playlist"
        }
    }
    
    private var emptyStateMessage: String {
        guard let playlist = playlist else { return "" }
        
        switch playlist.smartType {
        case .favorites:
            return "Mark songs as favorites to see them here"
        case .mostPlayed:
            return "Songs played 3 or more times will appear here"
        case .recentlyPlayed:
            return "Songs played in the last week will appear here"
        case .custom, .none:
            return "Add some tracks to this playlist to get started"
        }
    }
    
    // MARK: - Context Menu
    
    private func createPlaylistContextMenu(for track: Track) -> [ContextMenuItem] {
        guard let playlist = playlist else { return [] }
        
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
            if let index = playlist.tracks.firstIndex(of: track) {
                playlistManager.playTrackFromPlaylist(playlist, at: index)
                selectedTrackID = track.id
            }
        })
        
        items.append(.button(title: "Play Next") {
            // TODO: Implement play next functionality
        })
        
        items.append(.divider)
        
        // Add to other playlists
        let otherPlaylists = playlistManager.playlists.filter {
            $0.id != playlist.id && $0.type == .regular
        }
        
        if !otherPlaylists.isEmpty {
            let playlistItems = otherPlaylists.map { otherPlaylist in
                ContextMenuItem.button(title: otherPlaylist.name) {
                    playlistManager.addTrackToPlaylist(track: track, playlistID: otherPlaylist.id)
                }
            }
            
            items.append(.menu(title: "Add to Playlist", items: playlistItems))
        }
        
        // Remove from playlist (only for regular playlists)
        if playlist.type == .regular {
            items.append(.divider)
            items.append(.button(title: "Remove from Playlist", role: .destructive) {
                playlistManager.removeTrackFromPlaylist(track: track, playlistID: playlist.id)
            })
        }
        
        return items
    }
}

#Preview {
    // Create a sample playlist
    let samplePlaylist = Playlist(name: "My Favorite Songs", tracks: [])
    
    return PlaylistDetailView(playlistID: samplePlaylist.id, viewType: .list)
        .environmentObject({
            let manager = PlaylistManager()
            // Add the sample playlist to the manager
            manager.playlists = [samplePlaylist]
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .frame(height: 600)
}
