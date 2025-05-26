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
                    .padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    
                    // Sort button
                    Button(action: { sortAscending.toggle() }) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Sort folders \(sortAscending ? "descending" : "ascending")")
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
                    .background(Color(NSColor.textBackgroundColor))
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
                    .background(Color(NSColor.textBackgroundColor))
                } else {
                    // Simple list with native selection
                    SimpleFolderListView(
                        folders: filteredAndSortedFolders,
                        selectedFolder: $selectedFolder,
                        onRefresh: { folder in
                            refreshFolder(folder)
                        },
                        onRevealInFinder: { folder in
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
                        },
                        onRemove: { folder in
                            folderToRemove = folder
                            showingRemoveFolderAlert = true
                        }
                    )
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
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                
                // Tracks list content
                if let folder = selectedFolder {
                    FolderTracksContainer(folder: folder, viewType: viewType)
                        .id(folder.id) // Force refresh only when folder changes
                        .background(Color(NSColor.textBackgroundColor))
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
                    .background(Color(NSColor.textBackgroundColor))
                }
            }
            .frame(minWidth: 300)
            .background(Color(NSColor.textBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
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
    }
    
    // MARK: - Helper Methods
    
    private func refreshFolder(_ folder: Folder) {
        // Use the new refreshFolder method from LibraryManager
        libraryManager.refreshFolder(folder)
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
