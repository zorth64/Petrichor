import SwiftUI

struct HomeView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedSidebarItem: HomeSidebarItem?
    @State private var selectedTrackID: UUID?
    @AppStorage("globalViewType") private var viewType: LibraryViewType = .table
    @Binding var isShowingEntities: Bool

    var body: some View {
        if libraryManager.folders.isEmpty || libraryManager.tracks.isEmpty {
            NoMusicEmptyStateView(context: .mainWindow)
        } else {
            PersistentSplitView(
                left: {
                    HomeSidebarView(selectedItem: $selectedSidebarItem)
                },
                main: {
                    VStack(spacing: 0) {
                        if let selectedItem = selectedSidebarItem {
                            switch selectedItem.type {
                            case .tracks:
                                tracksView
                            case .artists:
                                artistsView
                            case .albums:
                                albumsView
                            }
                        } else {
                            emptySelectionView
                        }
                    }
                    .navigationTitle(selectedSidebarItem?.title ?? "Home")
                    .navigationSubtitle("")
                    .onChange(of: selectedSidebarItem) { _ in
                        guard let selectedItem = selectedSidebarItem else {
                            isShowingEntities = false
                            return
                        }
                        isShowingEntities = (selectedItem.type == .artists || selectedItem.type == .albums)
                    }
                }
            )
        }
    }

    // MARK: - Tracks View

    private var tracksView: some View {
        VStack(spacing: 0) {
            // Header
            TrackListHeader(
                title: "All Tracks",
                trackCount: libraryManager.tracks.count
            )

            Divider()

            // Track list
            if libraryManager.tracks.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                TrackView(
                    tracks: libraryManager.tracks,
                    viewType: viewType,
                    selectedTrackID: $selectedTrackID,
                    onPlayTrack: { track in
                        playlistManager.playTrack(track, fromTracks: libraryManager.tracks)
                    },
                    contextMenuItems: { track in
                        TrackContextMenu.createMenuItems(
                            for: track,
                            audioPlayerManager: audioPlayerManager,
                            playlistManager: playlistManager,
                            currentContext: .library
                        )
                    }
                )
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }

    // MARK: - Artists View

    private var artistsView: some View {
        VStack(spacing: 0) {
            // Header
            TrackListHeader(
                title: "All Artists",
                trackCount: libraryManager.artistEntities.count
            )

            Divider()

            // Artists list
            if libraryManager.artistEntities.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                EntityView(
                    entities: libraryManager.artistEntities,
                    viewType: viewType == .table ? .list : viewType,
                    onSelectEntity: { artist in
                        // TODO: Show tracks for selected artist
                        print("Selected artist: \(artist.name)")
                    },
                    contextMenuItems: { artist in
                        createArtistContextMenuItems(for: artist)
                    }
                )
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }

    // MARK: - Context Menu

    private func createArtistContextMenuItems(for artist: ArtistEntity) -> [ContextMenuItem] {
        []
    }

    // MARK: - Albums View

    private var albumsView: some View {
        VStack(spacing: 0) {
            // Header
            TrackListHeader(
                title: "All Albums",
                trackCount: libraryManager.albumEntities.count
            )

            Divider()

            // Albums list
            if libraryManager.albumEntities.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                EntityView(
                    entities: libraryManager.albumEntities,
                    viewType: viewType == .table ? .list : viewType,
                    onSelectEntity: { album in
                        // TODO: Show tracks for selected album
                        print("Selected album: \(album.name)")
                    },
                    contextMenuItems: { album in
                        createAlbumContextMenuItems(for: album)
                    }
                )
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }

    // MARK: - Album Context Menu

    private func createAlbumContextMenuItems(for album: AlbumEntity) -> [ContextMenuItem] {
        // TODO: Implement context menu items when we add album detail view
        []
    }

    // MARK: - Empty Selection View

    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Select an item from the sidebar")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

#Preview {
    @State var isShowingEntities = false

    HomeView(isShowingEntities: $isShowingEntities)
        .environmentObject(LibraryManager())
        .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
        .environmentObject(PlaylistManager())
        .frame(width: 800, height: 600)
}
