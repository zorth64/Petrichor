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
    @State private var cachedFilteredTracks: [Track] = []
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
                    LibrarySidebarView(
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
                    updateFilteredTracks()
                }
                .onChange(of: libraryManager.tracks) { tracks in
                    // Update filter item when tracks change
                    if let currentItem = selectedFilterItem, currentItem.name.hasPrefix("All") {
                        selectedFilterItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: tracks.count)
                    }
                }
                .onChange(of: selectedFilterItem) { _ in
                    updateFilteredTracks()
                }
                .onChange(of: selectedFilterType) { _ in
                    updateFilteredTracks()
                }
                .onChange(of: libraryManager.tracks.count) { _ in
                    // Only update if the number of tracks changed (tracks added/removed)
                    updateFilteredTracks()
                }
                .sheet(isPresented: $showingCreatePlaylistWithTrack) {
                    createPlaylistSheet
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreatePlaylistWithTrack"))) { notification in
                    if let track = notification.userInfo?["track"] as? Track {
                        trackToAddToNewPlaylist = track
                        showingCreatePlaylistWithTrack = true
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
            if cachedFilteredTracks.isEmpty {
                emptyFilterView
            } else {
                TrackView(
                    tracks: cachedFilteredTracks,
                    viewType: viewType,
                    selectedTrackID: $selectedTrackID,
                    onPlayTrack: { track in
                        playlistManager.playTrack(track, fromTracks: cachedFilteredTracks)
                        playlistManager.currentQueueSource = .library
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
    
    // MARK: - Tracks List Header
    
    private var tracksListHeader: some View {
        TrackListHeader(
            title: headerTitle,
            trackCount: cachedFilteredTracks.count
        )
    }

    private var headerTitle: String {
        if let filterItem = selectedFilterItem {
            if filterItem.name.hasPrefix("All") {
                return "All Tracks"
            } else {
                return filterItem.name
            }
        } else {
            return "All Tracks"
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
    
    // MARK: - Filtering Tracks Helper
    
    private func updateFilteredTracks() {
        guard let filterItem = selectedFilterItem else {
            cachedFilteredTracks = libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return
        }
        
        if filterItem.name.hasPrefix("All") {
            cachedFilteredTracks = libraryManager.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return
        }
        
        let unsortedTracks: [Track]
        switch selectedFilterType {
        case .artists:
            // For artists, we need to check if the selected artist appears anywhere in the artist field
            if filterItem.name == "Unknown Artist" {
                unsortedTracks = libraryManager.tracks.filter { track in
                    track.artist.isEmpty || track.artist == "Unknown Artist"
                }
            } else {
                // Use the shared parser to check if artist appears in track
                unsortedTracks = libraryManager.tracks.filter { track in
                    ArtistParser.trackContainsArtist(track, artistName: filterItem.name)
                }
            }
            
        case .albums:
            // Handle "Unknown Album" case
            if filterItem.name == "Unknown Album" {
                unsortedTracks = libraryManager.tracks.filter { track in
                    track.album.isEmpty || track.album == "Unknown Album"
                }
            } else {
                unsortedTracks = libraryManager.getTracksByAlbum(filterItem.name)
            }

        case .composers:
            // Handle "Unknown Composer" case
            if filterItem.name == "Unknown Composer" {
                unsortedTracks = libraryManager.tracks.filter { track in
                    track.composer.isEmpty || track.composer == "Unknown Composer"
                }
            } else {
                unsortedTracks = libraryManager.getTracksByComposer(filterItem.name)
            }

        case .genres:
            // Handle "Unknown Genre" case
            if filterItem.name == "Unknown Genre" {
                unsortedTracks = libraryManager.tracks.filter { track in
                    track.genre.isEmpty || track.genre == "Unknown Genre"
                }
            } else {
                unsortedTracks = libraryManager.getTracksByGenre(filterItem.name)
            }
            
        case .years:
            // Handle "Unknown Year" case
            if filterItem.name == "Unknown Year" {
                unsortedTracks = libraryManager.tracks.filter { track in
                    track.year.isEmpty || track.year == "Unknown Year"
                }
            } else {
                unsortedTracks = libraryManager.getTracksByYear(filterItem.name)
            }
        }
        
        cachedFilteredTracks = unsortedTracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    // MARK: - Context Menu Helper
    
    private func createLibraryContextMenu(for track: Track) -> [ContextMenuItem] {
        return TrackContextMenu.createMenuItems(
            for: track,
            audioPlayerManager: audioPlayerManager,
            playlistManager: playlistManager,
            currentContext: .library
        )
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
