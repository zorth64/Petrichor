import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var selectedFilterType: LibraryFilterType = .artists
    @State private var selectedFilterItem: LibraryFilterItem?
    @State private var showingCreatePlaylistWithTrack = false
    @State private var trackToAddToNewPlaylist: Track?
    @State private var newPlaylistName = ""
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
                .sheet(isPresented: $showingCreatePlaylistWithTrack) {
                    createPlaylistSheet
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
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }
    
    // MARK: - List Content with Virtualization
    
    private var tracksListContent: some View {
        VirtualizedTrackList(
            tracks: filteredTracks,
            selectedTrackID: $selectedTrackID,
            onPlayTrack: { track in
                playlistManager.playTrack(track)
            },
            contextMenuItems: { track in
                createLibraryContextMenu(for: track)
            }
        )
    }
    
    // MARK: - Grid Content with Virtualization
    
    private var tracksGridContent: some View {
        VirtualizedTrackGrid(
            tracks: filteredTracks,
            selectedTrackID: $selectedTrackID,
            onPlayTrack: { track in
                playlistManager.playTrack(track)
            },
            contextMenuItems: { track in
                createLibraryContextMenu(for: track)
            }
        )
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
            return libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        if filterItem.name.hasPrefix("All") {
            return libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        let unsortedTracks: [Track]
        switch selectedFilterType {
        case .artists:
            // For artists, check if the filter item name appears anywhere in the track's artist field
            // This handles both exact matches and collaborations
            unsortedTracks = libraryManager.tracks.filter { track in
                track.artist.localizedCaseInsensitiveContains(filterItem.name) ||
                track.artist == filterItem.name
            }
        case .albums:
            unsortedTracks = libraryManager.getTracksByAlbum(filterItem.name)
        case .genres:
            unsortedTracks = libraryManager.getTracksByGenre(filterItem.name)
        case .years:
            unsortedTracks = libraryManager.getTracksByYear(filterItem.name)
        }
        
        return unsortedTracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
        
        // Get regular playlists (exclude smart playlists)
        let regularPlaylists = playlistManager.playlists.filter { $0.type == .regular }
        
        if !regularPlaylists.isEmpty {
            let playlistItems = regularPlaylists.map { playlist in
                ContextMenuItem.button(title: playlist.name) {
                    playlistManager.addTrackToPlaylist(track: track, playlistID: playlist.id)
                }
            }
            
            var allPlaylistItems = playlistItems
            allPlaylistItems.append(.divider)
            allPlaylistItems.append(.button(title: "New Playlist...") {
                trackToAddToNewPlaylist = track
                showingCreatePlaylistWithTrack = true
            })
            
            items.append(.menu(title: "Add to Playlist", items: allPlaylistItems))
        } else {
            items.append(.button(title: "Create Playlist with This Track") {
                let newPlaylist = playlistManager.createPlaylist(name: "New Playlist", tracks: [track])
                print("Created new playlist with track: \(track.title)")
            })
        }
        
        // Add favorite toggle
        items.append(.divider)
        items.append(.button(title: track.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            playlistManager.toggleFavorite(for: track)
        })
        
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
