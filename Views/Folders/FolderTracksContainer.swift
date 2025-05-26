import SwiftUI

struct FolderTracksContainer: View {
    let folder: Folder
    let viewType: LibraryViewType
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedTrackID: UUID?
    @State private var folderTracks: [Track] = []
    @State private var isLoadingTracks = false
    @State private var showingCreatePlaylistWithTrack = false
    @State private var trackToAddToNewPlaylist: Track?
    @State private var newPlaylistName = ""
    
    var body: some View {
        Group {
            if isLoadingTracks {
                ProgressView("Loading tracks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderTracks.isEmpty {
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
            } else {
                Group {
                    switch viewType {
                    case .list:
                        VirtualizedTrackList(
                            tracks: folderTracks,
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                playlistManager.playTrackFromFolder(track, folder: folder, folderTracks: folderTracks)
                                selectedTrackID = track.id
                            },
                            contextMenuItems: { track in
                                createFolderContextMenu(for: track)
                            }
                        )
                    case .grid:
                        VirtualizedTrackGrid(
                            tracks: folderTracks,
                            selectedTrackID: $selectedTrackID,
                            onPlayTrack: { track in
                                playlistManager.playTrackFromFolder(track, folder: folder, folderTracks: folderTracks)
                                selectedTrackID = track.id
                            },
                            contextMenuItems: { track in
                                createFolderContextMenu(for: track)
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            loadTracksIfNeeded()
        }
        .onDisappear {
            // Clear tracks when view disappears to free memory
            folderTracks.removeAll()
            isLoadingTracks = false
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
    
    private func loadTracksIfNeeded() {
        guard folderTracks.isEmpty else { return }
        
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
    
    private func createFolderContextMenu(for track: Track) -> [ContextMenuItem] {
        return TrackContextMenu.createMenuItems(
            for: track,
            audioPlayerManager: audioPlayerManager,
            playlistManager: playlistManager,
            currentContext: .folder(folder)
        )
    }
    
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
    FolderTracksContainer(
        folder: Folder(url: URL(fileURLWithPath: "/Users/test/Music")),
        viewType: .list
    )
    .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
    .environmentObject(LibraryManager())
    .environmentObject(PlaylistManager())
}
