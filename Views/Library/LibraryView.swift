import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var selectedFilterType: LibraryFilterType = .artists
    @State private var selectedFilterItem: LibraryFilterItem?
    @AppStorage("libraryViewSplitPosition") private var splitPosition: Double = 250
    
    let viewType: LibraryViewType
    
    var body: some View {
        VStack {
            if libraryManager.isScanning {
                scanningView
            } else if libraryManager.tracks.isEmpty {
                emptyLibraryView
            } else {
                // Main library view with sidebar
                HSplitView {
                    // Left sidebar - Filter view
                    FilterSidebarView(
                        selectedFilterType: $selectedFilterType,
                        selectedFilterItem: $selectedFilterItem
                    )
                    .frame(minWidth: 200, idealWidth: splitPosition, maxWidth: 400)
                    
                    // Right side - Tracks list
                    tracksListView
                        .frame(minWidth: 300)
                }
                .onAppear {
                    // Set initial filter selection
                    if selectedFilterItem == nil {
                        selectedFilterItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                    }
                }
                .onChange(of: libraryManager.tracks) { tracks in
                    // Update filter item when tracks change
                    if let currentItem = selectedFilterItem, currentItem.name.hasPrefix("All") {
                        selectedFilterItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: tracks.count)
                    }
                }
            }
        }
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning for music files...")
                .font(.headline)
            
            Text("Found \(libraryManager.tracks.count) tracks so far")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty Library View
    
    private var emptyLibraryView: some View {
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
    }
    
    // MARK: - Tracks List View
    
    private var tracksListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            tracksListHeader
            
            Divider()
            
            // Tracks list content
            if filteredTracks.isEmpty {
                emptyFilterView
            } else {
                Group {
                    switch viewType {
                    case .list:
                        tracksListContent
                    case .grid:
                        tracksGridContent
                    }
                }
            }
        }
    }
    
    // MARK: - List Content
    
    private var tracksListContent: some View {
        List {
            ForEach(filteredTracks) { track in
                TrackRowContainer(
                    track: track,
                    isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                    isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                    isSelected: selectedTrackID == track.id,
                    onSelect: {
                        selectedTrackID = track.id
                    },
                    onPlay: {
                        // Use the new playTrack method that handles queue creation
                        playlistManager.playTrack(track)
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
    
    // MARK: - Grid Content
    
    private var tracksGridContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 176, maximum: 200), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(filteredTracks) { track in
                    TrackGridItem(
                        track: track,
                        isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                        isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                        isSelected: selectedTrackID == track.id,
                        onSelect: {
                            selectedTrackID = track.id
                        },
                        onPlay: {
                            playlistManager.playTrack(track)
                            selectedTrackID = track.id
                        }
                    )
                    .contextMenu {
                        ForEach(createLibraryContextMenu(for: track), id: \.id) { item in
                            switch item {
                            case .button(let title, let role, let action):
                                Button(title, role: role, action: action)
                            case .menu(let title, let items):
                                Menu(title) {
                                    ForEach(items, id: \.id) { subItem in
                                        if case .button(let subTitle, let subRole, let subAction) = subItem {
                                            Button(subTitle, role: subRole, action: subAction)
                                        }
                                    }
                                }
                            case .divider:
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Tracks List Header
    
    private var tracksListHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let filterItem = selectedFilterItem {
                    if filterItem.name.hasPrefix("All") {
                        Text("All Tracks")
                            .font(.headline)
                    } else {
                        Text(filterItem.name)
                            .font(.headline)
                        
                        Text(selectedFilterType.rawValue.dropLast())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("All Tracks")
                        .font(.headline)
                }
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            
            Spacer()
            
            Text("\(filteredTracks.count) tracks")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 16)
                .padding(.vertical, 10)
        }
    }
    
    // MARK: - Empty Filter View
    
    private var emptyFilterView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Tracks Found")
                .font(.headline)
            
            if let filterItem = selectedFilterItem, !filterItem.name.hasPrefix("All") {
                Text("No tracks found for \"\(filterItem.name)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No tracks match the current filter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var filteredTracks: [Track] {
        guard let filterItem = selectedFilterItem else {
            return libraryManager.tracks
        }
        
        if filterItem.name.hasPrefix("All") {
            return libraryManager.tracks
        }
        
        switch selectedFilterType {
        case .artists:
            // For artists, check if the filter item name appears anywhere in the track's artist field
            // This handles both exact matches and collaborations
            return libraryManager.tracks.filter { track in
                track.artist.localizedCaseInsensitiveContains(filterItem.name) ||
                track.artist == filterItem.name
            }
        case .albums:
            return libraryManager.getTracksByAlbum(filterItem.name)
        case .genres:
            return libraryManager.getTracksByGenre(filterItem.name)
        case .years:
            return libraryManager.getTracksByYear(filterItem.name)
        }
    }
    
    // MARK: - Context Menu Helper
    
    private func createLibraryContextMenu(for track: Track) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
            playlistManager.playTrack(track)
            selectedTrackID = track.id
        })
        
        items.append(.button(title: "Play Next") {
            // For now, just play the track directly
            // In a future update, we could implement proper "play next" functionality
            playlistManager.playTrack(track)
            selectedTrackID = track.id
        })
        
        items.append(.divider)
        
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
        
        // Add filter-specific options
        if let filterItem = selectedFilterItem, !filterItem.name.hasPrefix("All") {
            items.append(.divider)
            
            switch selectedFilterType {
            case .artists:
                items.append(.button(title: "Show All by \(filterItem.name)") {
                    // Already filtered, maybe scroll to top or show info
                })
            case .albums:
                items.append(.button(title: "Show Album: \(filterItem.name)") {
                    // Already filtered, maybe scroll to top or show info
                })
            case .genres:
                items.append(.button(title: "Show All \(filterItem.name)") {
                    // Already filtered, maybe scroll to top or show info
                })
            case .years:
                items.append(.button(title: "Show All from \(filterItem.name)") {
                    // Already filtered, maybe scroll to top or show info
                })
            }
        }
        
        return items
    }
}

#Preview {
    LibraryView(viewType: .list)
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
