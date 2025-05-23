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
    @AppStorage("foldersViewSplitPosition") private var splitPosition: Double = 250
    
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
        HSplitView {
            // Left side - Folders List
            VStack(alignment: .leading, spacing: 0) {
                // Folders toolbar
                HStack(spacing: 8) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        
                        TextField("Filter folders...", text: $folderSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        
                        if !folderSearchText.isEmpty {
                            Button(action: { folderSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    
                    // Sort button
                    Button(action: { sortAscending.toggle() }) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Sort folders \(sortAscending ? "descending" : "ascending")")
                    
                    Spacer()
                    
                    // Folder count
                    Text("\(filteredAndSortedFolders.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Folders list
                if libraryManager.folders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("No Folders")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Add folders to see your music organized by location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Add Folder") {
                            libraryManager.addFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if filteredAndSortedFolders.isEmpty {
                    // No folders match search
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("No Results")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("No folders match your search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Custom list without selection binding to avoid blue highlighting
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredAndSortedFolders) { folder in
                                FolderListRow(
                                    folder: folder,
                                    trackCount: libraryManager.getTracksInFolder(folder).count,
                                    isSelected: selectedFolder?.id == folder.id,
                                    onTap: { selectedFolder = folder },
                                    onRemove: { libraryManager.removeFolder(folder) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(minWidth: 200, idealWidth: splitPosition, maxWidth: 400)
            .onAppear {
                // Select first folder by default if none selected
                if selectedFolder == nil && !libraryManager.folders.isEmpty {
                    selectedFolder = libraryManager.folders.first
                }
            }
            .onChange(of: libraryManager.folders) { folders in
                // Update selection if current folder was removed
                if let selected = selectedFolder,
                   !folders.contains(where: { $0.id == selected.id }) {
                    selectedFolder = folders.first
                } else if selectedFolder == nil && !folders.isEmpty {
                    selectedFolder = folders.first
                }
            }
            .onChange(of: filteredAndSortedFolders) { filteredFolders in
                // Update selection if current folder is filtered out
                if let selected = selectedFolder,
                   !filteredFolders.contains(where: { $0.id == selected.id }),
                   !filteredFolders.isEmpty {
                    selectedFolder = filteredFolders.first
                }
            }
            
            // Right side - Tracks in selected folder
            VStack(alignment: .leading, spacing: 0) {
                // Tracks list header
                HStack {
                    if let folder = selectedFolder {
                        Text(folder.name)
                            .font(.headline)
                            .padding(.leading, 16)
                            .padding(10)
                        
                        Spacer()
                        
                        let trackCount = libraryManager.getTracksInFolder(folder).count
                        Text("\(trackCount) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 16)
                            .padding(10)
                    } else {
                        Text("No Folder Selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                            .padding(10)
                        
                        Spacer()
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Tracks list content
                if let folder = selectedFolder {
                    let folderTracks = libraryManager.getTracksInFolder(folder)
                    
                    if folderTracks.isEmpty {
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
                        List {
                            ForEach(folderTracks) { track in
                                TrackRowContainer(
                                    track: track,
                                    isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                                    isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                                    isSelected: selectedTrackID == track.id,
                                    onSelect: {
                                        selectedTrackID = track.id
                                    },
                                    onPlay: {
                                        audioPlayerManager.playTrack(track)
                                        selectedTrackID = track.id
                                    },
                                    contextMenuItems: {
                                        createFolderContextMenu(for: track, in: folder)
                                    }
                                )
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
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
            }
            .frame(minWidth: 300)
        }
    }
    
    // MARK: - Context Menu Helper
    
    private func createFolderContextMenu(for track: Track, in folder: Folder) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(.button(title: "Play") {
            audioPlayerManager.playTrack(track)
            selectedTrackID = track.id
        })
        
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
        
        items.append(.divider)
        items.append(.button(title: "Show in Finder") {
            NSWorkspace.shared.selectFile(track.url.path, inFileViewerRootedAtPath: folder.url.path)
        })
        
        return items
    }
}

#Preview {
    FoldersView()
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
