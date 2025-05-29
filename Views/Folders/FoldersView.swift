import SwiftUI
import Foundation

struct FoldersView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedFolder: Folder?
    @State private var selectedTrackID: UUID?
    @State private var folderSearchText = ""
    @State private var sortAscending = true
    @State private var showingRemoveFolderAlert = false
    @State private var folderToRemove: Folder?
    @State private var folderTracks: [Track] = []
    @State private var isLoadingTracks = false
    @State private var showingCreatePlaylistWithTrack = false
    @State private var trackToAddToNewPlaylist: Track?
    @State private var newPlaylistName = ""
    @AppStorage("foldersViewSplitPosition") private var splitPosition: Double = 250
    
    let viewType: LibraryViewType
    
    var filteredAndSortedFolders: [Folder] {
        let filtered = libraryManager.folders.filter { folder in
            folderSearchText.isEmpty || folder.name.localizedCaseInsensitiveContains(folderSearchText)
        }
        
        return filtered.sorted { folder1, folder2 in
            if sortAscending {
                return folder1.name.localizedCaseInsensitiveCompare(folder2.name) == .orderedAscending
            } else {
                return folder1.name.localizedCaseInsensitiveCompare(folder2.name) == .orderedDescending
            }
        }
    }
    
    var body: some View {
        if libraryManager.folders.isEmpty {
            // Show unified empty state when no folders exist
            NoMusicEmptyStateView(context: .mainWindow)
        } else {
            HSplitView {
                foldersSidebar
                    .frame(minWidth: 200, idealWidth: splitPosition, maxWidth: 400)
                
                folderTracksView
                    .frame(minWidth: 300)
            }
            .alert("Remove Folder", isPresented: $showingRemoveFolderAlert) {
                Button("Cancel", role: .cancel) {
                    folderToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    if let folder = folderToRemove {
                        libraryManager.removeFolder(folder)
                        folderToRemove = nil
                    }
                }
            } message: {
                if let folder = folderToRemove {
                    Text("Are you sure you want to remove \"\(folder.name)\" from your library? This will remove all tracks from this folder but won't delete the actual files.")
                }
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
    
    // MARK: - Folders Sidebar
    
    private var foldersSidebar: some View {
        FoldersSidebarView(selectedFolder: $selectedFolder)
            .onAppear {
                handleSidebarAppear()
            }
            .onChange(of: libraryManager.folders) { folders in
                handleFoldersChange(folders)
            }
            .onChange(of: selectedFolder) { folder in
                handleFolderSelection(folder)
            }
    }
    
    // MARK: - Folder Tracks View
    
    private var folderTracksView: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderTracksHeader
            
            Divider()
            
            folderTracksContent
        }
    }
    
    private var folderTracksHeader: some View {
        Group {
            if let folder = selectedFolder {
                TrackListHeader(
                    title: folder.name,
                    trackCount: folderTracks.count
                )
            } else {
                TrackListHeader(
                    title: "No Folder Selected",
                    trackCount: 0
                )
            }
        }
    }
    
    private var folderTracksContent: some View {
        Group {
            if selectedFolder != nil {
                if isLoadingTracks {
                    loadingTracksView
                } else if folderTracks.isEmpty {
                    emptyFolderView
                } else {
                    trackListView
                }
            } else {
                noFolderSelectedView
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Content Views
    
    private var loadingTracksView: some View {
        ProgressView("Loading tracks...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyFolderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Music Files")
                .font(.headline)
            
            Text("No playable music files found in this folder")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var trackListView: some View {
        TrackView(
            tracks: folderTracks,
            viewType: viewType,
            selectedTrackID: $selectedTrackID,
            onPlayTrack: { track in
                if let folder = selectedFolder {
                    playlistManager.playTrackFromFolder(track, folder: folder, folderTracks: folderTracks)
                    selectedTrackID = track.id
                }
            },
            contextMenuItems: { track in
                if let folder = selectedFolder {
                    return TrackContextMenu.createMenuItems(
                        for: track,
                        audioPlayerManager: audioPlayerManager,
                        playlistManager: playlistManager,
                        currentContext: .folder(folder)
                    )
                } else {
                    return []
                }
            }
        )
    }
    
    private var noFolderSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Select a Folder")
                .font(.headline)
            
            Text("Choose a folder from the list to view its music files")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
    
    // MARK: - Helper Methods
    
    private func refreshFolder(_ folder: Folder) {
        libraryManager.refreshFolder(folder)
    }
    
    private func handleSidebarAppear() {
        // Select first folder by default if none selected
        if selectedFolder == nil && !libraryManager.folders.isEmpty {
            selectedFolder = libraryManager.folders.first
        }
    }
    
    private func handleFoldersChange(_ folders: [Folder]) {
        // Update selection if current folder was removed
        if let selected = selectedFolder,
           !folders.contains(where: { $0.id == selected.id }) {
            selectedFolder = folders.first
        } else if selectedFolder == nil && !folders.isEmpty {
            selectedFolder = folders.first
        }
    }
    
    private func handleFilteredFoldersChange(_ filteredFolders: [Folder]) {
        // Update selection if current folder is filtered out
        if let selected = selectedFolder,
           !filteredFolders.contains(where: { $0.id == selected.id }),
           !filteredFolders.isEmpty {
            selectedFolder = filteredFolders.first
        }
    }
    
    private func handleFolderSelection(_ folder: Folder?) {
        // Clear previous tracks and load new ones
        folderTracks.removeAll()
        selectedTrackID = nil
        
        guard let folder = folder else { return }
        
        loadTracksForFolder(folder)
    }
    
    private func loadTracksForFolder(_ folder: Folder) {
        isLoadingTracks = true
        
        // Load tracks asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let tracks = libraryManager.getTracksInFolder(folder)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.folderTracks = tracks
                self.isLoadingTracks = false
            }
        }
    }
}

#Preview {
    FoldersView(viewType: .list)
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
        .frame(height: 600)
}
