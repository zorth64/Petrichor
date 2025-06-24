import SwiftUI

struct HomeView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @AppStorage("trackListSortAscending") private var trackListSortAscending: Bool = true
    @AppStorage("globalViewType") private var viewType: LibraryViewType = .table
    @AppStorage("entityViewType") private var entityViewType: LibraryViewType = .grid
    @AppStorage("entitySortAscending") private var entitySortAscending: Bool = true
    @State private var selectedSidebarItem: HomeSidebarItem?
    @State private var selectedTrackID: UUID?
    @State private var sortedTracks: [Track] = []
    @State private var sortedArtistEntities: [ArtistEntity] = []
    @State private var sortedAlbumEntities: [AlbumEntity] = []
    @State private var lastArtistCount: Int = 0
    @State private var lastAlbumCount: Int = 0
    @State private var selectedArtistEntity: ArtistEntity?
    @State private var selectedAlbumEntity: AlbumEntity?
    @State private var isShowingEntityDetail = false
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
                    ZStack {
                        // Base content (always rendered)
                        VStack(spacing: 0) {
                            if let selectedItem = selectedSidebarItem {
                                switch selectedItem.source {
                                case .fixed(let type):
                                    switch type {
                                    case .tracks:
                                        tracksView
                                    case .artists:
                                        artistsView
                                    case .albums:
                                        albumsView
                                    }
                                case .pinned:
                                    pinnedItemTracksView
                                }
                            } else {
                                emptySelectionView
                            }
                        }
                        .navigationTitle(selectedSidebarItem?.title ?? "Home")
                        .navigationSubtitle("")
                        
                        // Entity detail overlay
                        if isShowingEntityDetail {
                            Color(NSColor.windowBackgroundColor)
                                .ignoresSafeArea()
                            
                            if let artist = selectedArtistEntity {
                                EntityDetailView(
                                    entity: artist,
                                    viewType: viewType
                                ) {
                                    isShowingEntityDetail = false
                                    selectedArtistEntity = nil
                                }
                                .zIndex(1)
                            } else if let album = selectedAlbumEntity {
                                EntityDetailView(
                                    entity: album,
                                    viewType: viewType
                                ) {
                                    isShowingEntityDetail = false
                                    selectedAlbumEntity = nil
                                }
                                .zIndex(1)
                            }
                        }
                    }
                }
            )
            .onChange(of: selectedSidebarItem) { newItem in
                isShowingEntityDetail = false
                selectedArtistEntity = nil
                selectedAlbumEntity = nil
                
                if let item = newItem {
                    switch item.source {
                    case .fixed(let type):
                        // Handle fixed items
                        isShowingEntities = (type == .artists || type == .albums) && !isShowingEntityDetail
                        
                        // Load appropriate data
                        switch type {
                        case .tracks:
                            sortTracks()
                        case .artists:
                            sortArtistEntities()
                        case .albums:
                            sortAlbumEntities()
                        }
                        
                    case .pinned(let pinnedItem):
                        // Handle pinned items
                        isShowingEntities = false
                        loadTracksForPinnedItem(pinnedItem)
                    }
                } else {
                    isShowingEntities = false
                }
            }
            .onChange(of: isShowingEntityDetail) { _ in
                // When showing entity detail (tracks), we're not showing entities anymore
                if isShowingEntityDetail {
                    isShowingEntities = false
                } else if let item = selectedSidebarItem {
                    // When going back to entity list, check if we should show entities
                    if case .fixed(let type) = item.source {
                        isShowingEntities = (type == .artists || type == .albums)
                    } else {
                        isShowingEntities = false
                    }
                }
            }
        }
    }
    
    // MARK: - Tracks View
    
    private var tracksView: some View {
        VStack(spacing: 0) {
            // Header
            if viewType == .table {
                TrackListHeader(
                    title: "All Tracks",
                    trackCount: libraryManager.tracks.count
                ) {
                    TrackTableColumnMenu()
                }
            } else {
                TrackListHeader(
                    title: "All Tracks",
                    trackCount: libraryManager.tracks.count
                ) {
                    Button(action: {
                        trackListSortAscending.toggle()
                        sortTracks()
                    }) {
                        Image(trackListSortAscending ? "sort.ascending" : "sort.descending")
                            .renderingMode(.template)
                            .scaleEffect(0.8)
                    }
                    .buttonStyle(.borderless)
                    .help("Sort tracks \(trackListSortAscending ? "descending" : "ascending")")
                }
            }
            
            Divider()
            
            // Track list
            if libraryManager.tracks.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                TrackView(
                    tracks: sortedTracks,
                    viewType: viewType,
                    selectedTrackID: $selectedTrackID,
                    onPlayTrack: { track in
                        playlistManager.playTrack(track, fromTracks: sortedTracks)
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
        .onAppear {
            if sortedTracks.isEmpty {
                sortTracks()
            }
        }
        .onChange(of: libraryManager.tracks) { _ in
            sortTracks()
        }
    }
    
    // MARK: - Artists View
    
    private var artistsView: some View {
        VStack(spacing: 0) {
            // Header
            TrackListHeader(
                title: "All Artists",
                trackCount: libraryManager.artistEntities.count
            ) {
                Button(action: {
                    entitySortAscending.toggle()
                    sortEntities()
                }) {
                    Image(trackListSortAscending ? "sort.ascending" : "sort.descending")
                        .renderingMode(.template)
                        .scaleEffect(0.8)
                }
                .buttonStyle(.borderless)
                .help("Sort \(entitySortAscending ? "descending" : "ascending")")
            }
            
            Divider()
            
            // Artists list
            if libraryManager.artistEntities.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                EntityView(
                    entities: sortedArtistEntities,
                    viewType: entityViewType,
                    onSelectEntity: { artist in
                        selectedArtistEntity = artist
                        selectedAlbumEntity = nil
                        isShowingEntityDetail = true
                    },
                    contextMenuItems: { artist in
                        createArtistContextMenuItems(for: artist)
                    }
                )
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .onAppear {
            if sortedArtistEntities.isEmpty {
                sortArtistEntities()
            }
        }
        .onReceive(libraryManager.$cachedArtistEntities) { _ in
            if libraryManager.artistEntities.count != lastArtistCount {
                sortArtistEntities()
            }
        }
    }
    
    // MARK: - Albums View
    
    private var albumsView: some View {
        VStack(spacing: 0) {
            // Header
            TrackListHeader(
                title: "All Albums",
                trackCount: libraryManager.albumEntities.count
            ) {
                Button(action: {
                    entitySortAscending.toggle()
                    sortEntities()
                }) {
                    Image(trackListSortAscending ? "sort.ascending" : "sort.descending")
                        .renderingMode(.template)
                        .scaleEffect(0.8)
                }
                .buttonStyle(.borderless)
                .help("Sort \(entitySortAscending ? "descending" : "ascending")")
            }
            
            Divider()
            
            // Albums list
            if libraryManager.albumEntities.isEmpty {
                NoMusicEmptyStateView(context: .mainWindow)
            } else {
                EntityView(
                    entities: sortedAlbumEntities,
                    viewType: entityViewType,
                    onSelectEntity: { album in
                        selectedAlbumEntity = album
                        selectedArtistEntity = nil
                        isShowingEntityDetail = true
                    },
                    contextMenuItems: { album in
                        createAlbumContextMenuItems(for: album)
                    }
                )
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .onAppear {
            if sortedAlbumEntities.isEmpty {
                sortAlbumEntities()
            }
        }
        .onReceive(libraryManager.$cachedAlbumEntities) { _ in
            if libraryManager.albumEntities.count != lastAlbumCount {
                sortAlbumEntities()
            }
        }
    }
    
    // MARK: - Pinned Item Tracks View

    private var pinnedItemTracksView: some View {
        VStack(spacing: 0) {
            // Header
            if let selectedItem = selectedSidebarItem,
               case .pinned(let pinnedItem) = selectedItem.source {
                if viewType == .table {
                    TrackListHeader(
                        title: pinnedItem.displayName,
                        subtitle: nil,
                        trackCount: sortedTracks.count
                    ) {
                        TrackTableColumnMenu()
                    }
                } else {
                    TrackListHeader(
                        title: pinnedItem.displayName,
                        subtitle: nil,
                        trackCount: sortedTracks.count
                    ) {
                        Button(action: {
                            trackListSortAscending.toggle()
                            sortTracks()
                        }) {
                            Image(trackListSortAscending ? "sort.ascending" : "sort.descending")
                                .renderingMode(.template)
                                .scaleEffect(0.8)
                        }
                        .buttonStyle(.borderless)
                        .help("Sort tracks \(trackListSortAscending ? "descending" : "ascending")")
                    }
                }
            }

            Divider()

            // Track list
            if sortedTracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "pin.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No tracks found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else {
                TrackView(
                    tracks: sortedTracks,
                    viewType: viewType,
                    selectedTrackID: $selectedTrackID,
                    onPlayTrack: { track in
                        playlistManager.playTrack(track, fromTracks: sortedTracks)
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
    
    // MARK: - Helpers
    
    private var navigationTitle: String {
        if isShowingEntityDetail {
            if let artist = selectedArtistEntity {
                return artist.name
            } else if let album = selectedAlbumEntity {
                return album.name
            }
        }
        return selectedSidebarItem?.title ?? "Home"
    }
    
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
    
    private func sortTracks() {
        if let selectedItem = selectedSidebarItem,
           case .pinned(let pinnedItem) = selectedItem.source {
            // If viewing a pinned item, sort those tracks
            loadTracksForPinnedItem(pinnedItem)
        } else {
            // Otherwise sort all library tracks
            sortedTracks = trackListSortAscending
                ? libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                : libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }
    
    private func sortArtistEntities() {
        sortedArtistEntities = entitySortAscending
        ? libraryManager.artistEntities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        : libraryManager.artistEntities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        lastArtistCount = sortedArtistEntities.count
    }
    
    private func sortAlbumEntities() {
        sortedAlbumEntities = entitySortAscending
        ? libraryManager.albumEntities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        : libraryManager.albumEntities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        lastAlbumCount = sortedAlbumEntities.count
    }
    
    private func sortEntities() {
        sortArtistEntities()
        sortAlbumEntities()
    }
    
    private func loadTracksForPinnedItem(_ item: PinnedItem) {
        let tracks: [Track]
        
        switch item.itemType {
        case .library:
            tracks = libraryManager.getTracksForPinnedItem(item)
        case .playlist:
            tracks = playlistManager.getTracksForPinnedPlaylist(item)
        }
        
        sortedTracks = trackListSortAscending
            ? tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            : tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
    }
    
    private func createAlbumContextMenuItems(for album: AlbumEntity) -> [ContextMenuItem] {
        [libraryManager.createPinContextMenuItem(for: album)]
    }

    private func createArtistContextMenuItems(for artist: ArtistEntity) -> [ContextMenuItem] {
        [libraryManager.createPinContextMenuItem(for: artist)]
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
