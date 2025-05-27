import SwiftUI

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var selectedPlaylist: Playlist?
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            
            Divider()
            
            playlistsList
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            createPlaylistSheet
        }
    }
    
    // MARK: - Sidebar Header
    
    private var sidebarHeader: some View {
        ListHeader {
            Text("Playlists")
                .headerTitleStyle()
            
            Spacer()
            
            createPlaylistButton
        }
    }
    
    private var createPlaylistButton: some View {
        Button(action: { showingCreatePlaylist = true }) {
            Image(systemName: "plus")
                .font(.system(size: 14))
        }
        .buttonStyle(.borderless)
        .help("Create New Playlist")
    }
    
    // MARK: - Playlists List
    
    private var playlistsList: some View {
        List(selection: $selectedPlaylist) {
            smartPlaylistsSection
            regularPlaylistsSection
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var smartPlaylistsSection: some View {
        Section {
            ForEach(smartPlaylists) { playlist in
                PlaylistSidebarRow(playlist: playlist)
                    .tag(playlist)
            }
        }
    }
    
    @ViewBuilder
    private var regularPlaylistsSection: some View {
        if !regularPlaylists.isEmpty {
            Section("My Playlists") {
                ForEach(regularPlaylists) { playlist in
                    EditablePlaylistRow(playlist: playlist)
                        .tag(playlist)
                }
            }
        }
    }
    
    // MARK: - Create Playlist Sheet
    
    private var createPlaylistSheet: some View {
        VStack(spacing: 20) {
            sheetHeader
            
            playlistNameField
            
            sheetButtons
        }
        .padding(30)
        .frame(width: 350)
    }
    
    private var sheetHeader: some View {
        Text("New Playlist")
            .font(.headline)
    }
    
    private var playlistNameField: some View {
        TextField("Playlist Name", text: $newPlaylistName)
            .textFieldStyle(.roundedBorder)
            .frame(width: 250)
    }
    
    private var sheetButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                handleCancelCreatePlaylist()
            }
            .keyboardShortcut(.escape)
            
            Button("Create") {
                handleCreatePlaylist()
            }
            .keyboardShortcut(.return)
            .disabled(newPlaylistName.isEmpty)
        }
    }
    
    // MARK: - Computed Properties
    
    private var smartPlaylists: [Playlist] {
        playlistManager.playlists.filter { $0.type == .smart }
    }
    
    private var regularPlaylists: [Playlist] {
        playlistManager.playlists.filter { $0.type == .regular }
    }
    
    // MARK: - Action Methods
    
    private func handleCreatePlaylist() {
        guard !newPlaylistName.isEmpty else { return }
        
        let newPlaylist = playlistManager.createPlaylist(name: newPlaylistName)
        selectedPlaylist = newPlaylist
        newPlaylistName = ""
        showingCreatePlaylist = false
    }
    
    private func handleCancelCreatePlaylist() {
        newPlaylistName = ""
        showingCreatePlaylist = false
    }
}

// MARK: - Editable Playlist Row

struct EditablePlaylistRow: View {
    let playlist: Playlist
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var isEditing = false
    @State private var editingName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    // Get the current playlist from the manager (this includes updated track count)
    private var currentPlaylist: Playlist? {
        playlistManager.playlists.first { $0.id == playlist.id }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            playlistIcon
            
            if isEditing {
                editingContent
            } else {
                normalContent
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            contextMenuContent
        }
    }
    
    // MARK: - Row Components
    
    private var playlistIcon: some View {
        Image(systemName: playlistIconName)
            .font(.system(size: 16))
            .foregroundColor(iconColor)
            .frame(width: 20)
    }
    
    private var editingContent: some View {
        TextField("Playlist Name", text: $editingName)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($isNameFieldFocused)
            .onSubmit {
                commitRename()
            }
            .onExitCommand {
                cancelEditing()
            }
    }
    
    private var normalContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentPlaylist?.name ?? playlist.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text("\((currentPlaylist ?? playlist).tracks.count) songs")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        if playlist.isUserEditable {
            Button("Rename") {
                startEditing()
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                playlistManager.deletePlaylist(playlist)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var playlistIconName: String {
        switch playlist.smartType {
        case .favorites: return "star.fill"
        case .mostPlayed: return "play.circle.fill"
        case .recentlyPlayed: return "clock.fill"
        case .custom, .none: return "music.note.list"
        }
    }
    
    private var iconColor: Color {
        switch playlist.smartType {
        case .favorites: return .yellow
        case .mostPlayed: return .blue
        case .recentlyPlayed: return .purple
        case .custom, .none: return .secondary
        }
    }
    
    // MARK: - Action Methods
    
    private func startEditing() {
        editingName = currentPlaylist?.name ?? playlist.name
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }
    
    private func commitRename() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != (currentPlaylist?.name ?? playlist.name) {
            playlistManager.renamePlaylist(playlist, newName: trimmedName)
        }
        isEditing = false
    }
    
    private func cancelEditing() {
        isEditing = false
        editingName = currentPlaylist?.name ?? playlist.name
    }
}

// MARK: - Playlist Row Component

struct PlaylistSidebarRow: View {
    let playlist: Playlist
    @EnvironmentObject var playlistManager: PlaylistManager
    
    // Get current playlist from manager
    private var currentPlaylist: Playlist? {
        playlistManager.playlists.first { $0.id == playlist.id }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            playlistIcon
            
            playlistInfo
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private var playlistIcon: some View {
        Image(systemName: playlistIconName)
            .font(.system(size: 16))
            .foregroundColor(iconColor)
            .frame(width: 20)
    }
    
    private var playlistInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(currentPlaylist?.name ?? playlist.name)
                .font(.system(size: 13))
                .lineLimit(1)
            
            Text(trackCountText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var trackCountText: String {
        let actualPlaylist = currentPlaylist ?? playlist
        let count = actualPlaylist.tracks.count
        if let limit = actualPlaylist.trackLimit, actualPlaylist.type == .smart {
            return "\(count) / \(limit) songs"
        } else {
            return "\(count) songs"
        }
    }
    
    private var playlistIconName: String {
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
    
    private var iconColor: Color {
        switch playlist.smartType {
        case .favorites:
            return .yellow
        case .mostPlayed:
            return .blue
        case .recentlyPlayed:
            return .purple
        case .custom, .none:
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview("Playlist Sidebar") {
    @State var selectedPlaylist: Playlist? = nil
    
    let previewManager = {
        let manager = PlaylistManager()
        
        // Create sample playlists
        let smartPlaylists = [
            Playlist(
                name: "Favorite Songs",
                smartType: .favorites,
                criteria: SmartPlaylistCriteria.favoritesPlaylist(),
                isUserEditable: false
            ),
            Playlist(
                name: "Top 25 Most Played",
                smartType: .mostPlayed,
                criteria: SmartPlaylistCriteria.mostPlayedPlaylist(limit: 25),
                isUserEditable: false
            ),
            Playlist(
                name: "Recently Played",
                smartType: .recentlyPlayed,
                criteria: SmartPlaylistCriteria.recentlyPlayedPlaylist(limit: 25, daysBack: 7),
                isUserEditable: false
            )
        ]
        
        // Create sample tracks for regular playlists
        let sampleTrack1 = Track(url: URL(fileURLWithPath: "/sample1.mp3"))
        sampleTrack1.title = "Sample Song 1"
        sampleTrack1.artist = "Artist 1"
        
        let sampleTrack2 = Track(url: URL(fileURLWithPath: "/sample2.mp3"))
        sampleTrack2.title = "Sample Song 2"
        sampleTrack2.artist = "Artist 2"
        
        let regularPlaylists = [
            Playlist(name: "My Favorites", tracks: [sampleTrack1, sampleTrack2]),
            Playlist(name: "Workout Mix", tracks: [sampleTrack1]),
            Playlist(name: "Relaxing Music", tracks: [])
        ]
        
        manager.playlists = smartPlaylists + regularPlaylists
        return manager
    }()
    
    return PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
        .environmentObject(previewManager)
        .frame(width: 250, height: 500)
}

#Preview("Empty Sidebar") {
    @State var selectedPlaylist: Playlist? = nil
    
    let emptyManager = PlaylistManager()
    
    return PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
        .environmentObject(emptyManager)
        .frame(width: 250, height: 500)
}
