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
            .overlay(alignment: .bottomTrailing) {
                if viewType == .table {
                    TrackTableColumnMenu()
                        .padding([.bottom, .trailing], 12)
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

                    if !playlist.tracks.isEmpty {
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
        let buttonWidth: CGFloat = 90
        let verticalPadding: CGFloat = 6
        let iconSize: CGFloat = 12
        let textSize: CGFloat = 13
        let buttonSpacing: CGFloat = 10
        let iconTextSpacing: CGFloat = 4

        return HStack(spacing: buttonSpacing) {
            Button(action: playPlaylist) {
                HStack(spacing: iconTextSpacing) {
                    Image(systemName: "play.fill")
                        .font(.system(size: iconSize))
                    Text("Play")
                        .font(.system(size: textSize, weight: .medium))
                }
                .frame(width: buttonWidth)
                .padding(.vertical, verticalPadding)
            }
            .buttonStyle(.borderedProminent)
            .disabled(playlist?.tracks.isEmpty ?? true)

            Button(action: shufflePlaylist) {
                HStack(spacing: iconTextSpacing) {
                    Image(systemName: "shuffle")
                        .font(.system(size: iconSize))
                    Text("Shuffle")
                        .font(.system(size: textSize, weight: .medium))
                }
                .frame(width: buttonWidth)
                .padding(.vertical, verticalPadding)
            }
            .buttonStyle(.bordered)
            .disabled(playlist?.tracks.isEmpty ?? true)

            if playlist?.type == .regular {
                Button(action: { showingAddSongs = true }) {
                    HStack(spacing: iconTextSpacing) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: iconSize))
                        Text("Add Songs")
                            .font(.system(size: textSize, weight: .medium))
                    }
                    .frame(width: buttonWidth)
                    .padding(.vertical, verticalPadding)
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
                TrackView(
                    tracks: playlist?.tracks ?? [],
                    viewType: viewType,
                    selectedTrackID: $selectedTrackID,
                    onPlayTrack: { track in
                        if let playlist = playlist,
                           let index = playlist.tracks.firstIndex(of: track) {
                            playlistManager.playTrackFromPlaylist(playlist, at: index)
                            selectedTrackID = track.id
                        }
                    },
                    contextMenuItems: { track in
                        if let playlist = playlist {
                            return TrackContextMenu.createMenuItems(
                                for: track,
                                audioPlayerManager: audioPlayerManager,
                                playlistManager: playlistManager,
                                currentContext: .playlist(playlist)
                            )
                        } else {
                            return []
                        }
                    }
                )
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

        if playlist.type == .smart && !playlist.isUserEditable {
            switch playlist.name {
            case "Favorites":
                return "star.fill"
            case "Top 25 Most Played":
                return "play.circle.fill"
            case "Top 25 Recently Played":
                return "clock.fill"
            default:
                return "music.note.list"
            }
        }
        return "music.note.list"
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

        if playlist.type == .smart && !playlist.isUserEditable {
            switch playlist.name {
            case "Favorites":
                return "No Favorite Songs"
            case "Top 25 Most Played":
                return "No Frequently Played Songs"
            case "Top 25 Recently Played":
                return "No Recently Played Songs"
            default:
                return "Empty Smart Playlist"
            }
        }
        return "Empty Playlist"
    }

    private var emptyStateMessage: String {
        guard let playlist = playlist else { return "" }

        if playlist.type == .smart && !playlist.isUserEditable {
            switch playlist.name {
            case "Favorites":
                return "Mark songs as favorites to see them here"
            case "Top 25 Most Played":
                return "Songs played more than 5 times will appear here"
            case "Top 25 Recently Played":
                return "Songs played in the last week will appear here"
            default:
                return "This smart playlist will update automatically based on its criteria"
            }
        }
        return "Add some tracks to this playlist to get started"
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
        name: "Favorites",
        criteria: SmartPlaylistCriteria(
            rules: [SmartPlaylistCriteria.Rule(
                field: "isFavorite",
                condition: .equals,
                value: "true"
            )],
            sortBy: "title",
            sortAscending: true
        ),
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
