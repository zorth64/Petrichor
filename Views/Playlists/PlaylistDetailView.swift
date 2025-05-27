import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: UUID
    let viewType: LibraryViewType
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var showingCreatePlaylistWithTrack = false
    @State private var trackToAddToNewPlaylist: Track?
    @State private var newPlaylistName = ""
    @State private var showingAddSongs = false
    
    // Convenience initializer for when you have a Playlist object
    init(playlist: Playlist, viewType: LibraryViewType) {
        self.playlistID = playlist.id
        self.viewType = viewType
    }
    
    // Standard initializer with playlist ID
    init(playlistID: UUID, viewType: LibraryViewType) {
        self.playlistID = playlistID
        self.viewType = viewType
    }
    
    // Get the current playlist from the manager
    private var playlist: Playlist? {
        playlistManager.playlists.first { $0.id == playlistID }
    }
    
    var body: some View {
        if let playlist = playlist {
            VStack(spacing: 0) {
                playlistHeader
                
                Divider()
                
                playlistContent
            }
            .sheet(isPresented: $showingAddSongs) {
                AddSongsToPlaylistSheet(playlist: playlist)
            }
            .sheet(isPresented: $showingCreatePlaylistWithTrack) {
                createPlaylistSheet
            }
            .onChange(of: playlistID) { _ in
                selectedTrackID = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreatePlaylistWithTrack"))) { notification in
                if let track = notification.userInfo?["track"] as? Track {
                    trackToAddToNewPlaylist = track
                    showingCreatePlaylistWithTrack = true
                }
            }
        } else {
            playlistNotFoundView
        }
    }
    
    // MARK: - Playlist Header
    
    @ViewBuilder
    private var playlistHeader: some View {
        if let playlist = playlist {
            PlaylistHeader {
                HStack(alignment: .top, spacing: 20) {
                    playlistArtwork
                    
                    VStack(alignment: .leading, spacing: 12) {
                        playlistInfo
                        playlistControls
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var playlistArtwork: some View {
        Group {
            if let artworkData = playlist?.effectiveCoverArtwork,
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
    }
    
    private var playlistInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlistTypeText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text(playlist?.name ?? "")
                .font(.title)
                .fontWeight(.bold)
                .lineLimit(2)
            
            if let playlist = playlist {
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
        }
    }
    
    private var playlistControls: some View {
        HStack(spacing: 12) {
            Button(action: playPlaylist) {
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
            .disabled(playlist?.tracks.isEmpty ?? true)
            
            Button(action: shufflePlaylist) {
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
            .disabled(playlist?.tracks.isEmpty ?? true)
            
            if playlist?.type == .regular {
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
    
    // MARK: - Playlist Content
    
    private var playlistContent: some View {
        Group {
            if playlist?.tracks.isEmpty ?? true {
                emptyPlaylistView
            } else {
                Group {
                    switch viewType {
                    case .list:
                        VirtualizedTrackList(
                            tracks: playlist?.tracks ?? [],
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                if let playlist = playlist,
                                   let index = playlist.tracks.firstIndex(of: track) {
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
                            tracks: playlist?.tracks ?? [],
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                if let playlist = playlist,
                                   let index = playlist.tracks.firstIndex(of: track) {
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
    
    // MARK: - Playlist Not Found View
    
    private var playlistNotFoundView: some View {
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
    
    // MARK: - Create Playlist Sheet
    
    private var createPlaylistSheet: some View {
        VStack(spacing: 20) {
            Text("New Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $newPlaylistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            if let track = trackToAddToNewPlaylist {
                Text("Will add: \(track.title)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    newPlaylistName = ""
                    trackToAddToNewPlaylist = nil
                    showingCreatePlaylistWithTrack = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    if !newPlaylistName.isEmpty, let track = trackToAddToNewPlaylist {
                        let newPlaylist = playlistManager.createPlaylist(
                            name: newPlaylistName,
                            tracks: [track]
                        )
                        newPlaylistName = ""
                        trackToAddToNewPlaylist = nil
                        showingCreatePlaylistWithTrack = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(newPlaylistName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 350)
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
    
    // MARK: - Action Methods
    
    private func playPlaylist() {
        guard let playlist = playlist, !playlist.tracks.isEmpty else { return }
        playlistManager.playTrackFromPlaylist(playlist, at: 0)
    }
    
    private func shufflePlaylist() {
        guard let playlist = playlist, !playlist.tracks.isEmpty else { return }
        playlistManager.toggleShuffle()
        playlistManager.playTrackFromPlaylist(playlist, at: 0)
    }
    
    // MARK: - Context Menu
    
    private func createPlaylistContextMenu(for track: Track) -> [ContextMenuItem] {
        guard let playlist = playlist else { return [] }
        
        return TrackContextMenu.createMenuItems(
            for: track,
            audioPlayerManager: audioPlayerManager,
            playlistManager: playlistManager,
            currentContext: .playlist(playlist)
        )
    }
}

// MARK: - Preview

#Preview("Regular Playlist") {
    let samplePlaylist = Playlist(name: "My Favorite Songs", tracks: [])
    
    return PlaylistDetailView(playlist: samplePlaylist, viewType: .list)
        .environmentObject({
            let manager = PlaylistManager()
            manager.playlists = [samplePlaylist]
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .frame(height: 600)
}

#Preview("Smart Playlist") {
    let smartPlaylist = Playlist(
        name: "Favorite Songs",
        smartType: .favorites,
        criteria: SmartPlaylistCriteria.favoritesPlaylist(),
        isUserEditable: false
    )
    
    return PlaylistDetailView(playlist: smartPlaylist, viewType: .grid)
        .environmentObject({
            let manager = PlaylistManager()
            manager.playlists = [smartPlaylist]
            return manager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .frame(height: 600)
}
