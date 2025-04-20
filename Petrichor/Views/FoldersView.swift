import SwiftUI

struct FoldersView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedFolder: Folder?
    @State private var selectedTrackID: UUID?
    
    var body: some View {
        HSplitView {
            VStack {
                List(selection: $selectedFolder) {
                    ForEach(libraryManager.folders) { folder in
                        Text(folder.name)
                            .tag(folder)
                    }
                }
                
                if libraryManager.folders.isEmpty {
                    ContentUnavailableView {
                        Label("No Folders", systemImage: "folder.badge.questionmark")
                    } description: {
                        Text("Add a folder to see your music here")
                    } actions: {
                        Button("Add Folder") {
                            libraryManager.addFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 200)
            
            // Right side - tracks in selected folder
            VStack {
                if let folder = selectedFolder {
                    let folderTracks = libraryManager.getTracksInFolder(folder)
                    
                    if folderTracks.isEmpty {
                        ContentUnavailableView {
                            Label("No Music Files", systemImage: "music.note.list")
                        } description: {
                            Text("No playable music files found in this folder")
                        }
                    } else {
                        List {
                            ForEach(folderTracks) { track in
                                TrackRow(track: track)
                                    .onTapGesture {
                                        audioPlayerManager.playTrack(track)
                                        selectedTrackID = track.id
                                    }
                                    .background(selectedTrackID == track.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .contextMenu {
                                        Button("Play") {
                                            audioPlayerManager.playTrack(track)
                                        }
                                        
                                        Menu("Add to Playlist") {
                                            ForEach(playlistManager.playlists) { playlist in
                                                Button(playlist.name) {
                                                    playlistManager.addTrackToPlaylist(track: track, playlistID: playlist.id)
                                                }
                                            }
                                            
                                            Divider()
                                            
                                            Button("New Playlist...") {
                                                // We'll implement this later
                                            }
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Folder Selected", systemImage: "folder")
                    } description: {
                        Text("Select a folder to view its contents")
                    }
                }
            }
        }
        .navigationTitle("Folders")
    }
}
