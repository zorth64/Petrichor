import SwiftUI

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var selectedPlaylist: Playlist?
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with create button
            sidebarHeader
            
            Divider()
            
            // Playlists list
            List(selection: $selectedPlaylist) {
                // Smart playlists section - keep as is
                Section {
                    ForEach(smartPlaylists) { playlist in
                        PlaylistSidebarRow(playlist: playlist)
                            .tag(playlist)
                    }
                }
                
                // Regular playlists section - simplified
                if !regularPlaylists.isEmpty {
                    Section("My Playlists") {
                        ForEach(regularPlaylists) { playlist in
                            EditablePlaylistRow(playlist: playlist)
                                .tag(playlist)  // This is what makes it selectable
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            createPlaylistSheet
        }
    }
    
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
                // Icon
                Image(systemName: playlistIcon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                if isEditing {
                    // Edit mode
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
                } else {
                    // Normal mode
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentPlaylist?.name ?? playlist.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        
                        // Use currentPlaylist for track count
                        Text("\((currentPlaylist ?? playlist).tracks.count) songs")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 2)
            .contextMenu {
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
        }
        
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
        
        private var playlistIcon: String {
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
    }
    
    // MARK: - Subviews
    
    private var sidebarHeader: some View {
        HStack {
            Text("Playlists")
                .font(.headline)
            
            Spacer()
            
            Button(action: { showingCreatePlaylist = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Create New Playlist")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var createPlaylistSheet: some View {
        VStack(spacing: 20) {
            Text("New Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $newPlaylistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    newPlaylistName = ""
                    showingCreatePlaylist = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        let newPlaylist = playlistManager.createPlaylist(name: newPlaylistName)
                        selectedPlaylist = newPlaylist
                        newPlaylistName = ""
                        showingCreatePlaylist = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(newPlaylistName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
    
    // MARK: - Computed Properties
    
    private var smartPlaylists: [Playlist] {
        playlistManager.playlists.filter { $0.type == .smart }
    }
    
    private var regularPlaylists: [Playlist] {
        playlistManager.playlists.filter { $0.type == .regular }
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
            // Icon based on playlist type
            Image(systemName: playlistIcon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentPlaylist?.name ?? playlist.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text(trackCountText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
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
    
    private var playlistIcon: String {
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

#Preview {
    @State var selectedPlaylist: Playlist? = nil
    
    return PlaylistSidebarView(selectedPlaylist: $selectedPlaylist)
        .environmentObject({
            let manager = PlaylistManager()
            return manager
        }())
        .frame(width: 250, height: 500)
}
