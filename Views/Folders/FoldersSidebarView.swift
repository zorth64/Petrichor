import SwiftUI

struct FoldersSidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedFolder: Folder?
    
    @State private var selectedSidebarItem: FolderSidebarItem?
    @State private var searchText = ""
    @State private var sortAscending = true
    @State private var folderTrackCounts: [Int64: Int] = [:]
    
    var filteredFolders: [Folder] {
        let filtered = libraryManager.folders.filter { folder in
            searchText.isEmpty || folder.name.localizedCaseInsensitiveContains(searchText)
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
        VStack(spacing: 0) {
            // Header with search
            headerSection
            
            Divider()
            
            // Sidebar content
            if libraryManager.folders.isEmpty {
                emptyFoldersView
            } else if filteredFolders.isEmpty {
                noSearchResultsView
            } else {
                SidebarView(
                    folders: filteredFolders,
                    trackCounts: folderTrackCounts,
                    selectedItem: $selectedSidebarItem,
                    onItemTap: { item in
                        selectedFolder = item.folder
                    },
                    contextMenuItems: { item in
                        createContextMenuItems(for: item.folder)
                    }
                )
            }
        }
        .onAppear {
            updateTrackCounts()
            handleSidebarAppear()
        }
        .onChange(of: libraryManager.folders) { _ in
            updateTrackCounts()
            handleFoldersChange()
        }
        .onChange(of: filteredFolders) { _ in
            handleFilteredFoldersChange()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ListHeader {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Filter folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
    }
    
    // MARK: - Empty States
    
    private var emptyFoldersView: some View {
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
    }
    
    private var noSearchResultsView: some View {
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
    }
    
    // MARK: - Helper Methods
    
    private func updateTrackCounts() {
        folderTrackCounts.removeAll()
        for folder in libraryManager.folders {
            if let folderId = folder.id {
                folderTrackCounts[folderId] = libraryManager.getTrackCountForFolder(folder)
            }
        }
    }
    
    private func handleSidebarAppear() {
        // Select first folder if none selected
        if selectedFolder == nil && !libraryManager.folders.isEmpty {
            selectedFolder = libraryManager.folders.first
            if let folder = selectedFolder {
                selectedSidebarItem = FolderSidebarItem(
                    folder: folder,
                    trackCount: folderTrackCounts[folder.id ?? -1] ?? 0
                )
            }
        }
    }
    
    private func handleFoldersChange() {
        // Update selection if current folder was removed
        if let selected = selectedFolder,
           !libraryManager.folders.contains(where: { $0.id == selected.id }) {
            selectedFolder = libraryManager.folders.first
            if let folder = selectedFolder {
                selectedSidebarItem = FolderSidebarItem(
                    folder: folder,
                    trackCount: folderTrackCounts[folder.id ?? -1] ?? 0
                )
            }
        } else if selectedFolder == nil && !libraryManager.folders.isEmpty {
            selectedFolder = libraryManager.folders.first
            if let folder = selectedFolder {
                selectedSidebarItem = FolderSidebarItem(
                    folder: folder,
                    trackCount: folderTrackCounts[folder.id ?? -1] ?? 0
                )
            }
        }
    }
    
    private func handleFilteredFoldersChange() {
        // Update selection if current folder is filtered out
        if let selected = selectedFolder,
           !filteredFolders.contains(where: { $0.id == selected.id }),
           !filteredFolders.isEmpty {
            selectedFolder = filteredFolders.first
            if let folder = selectedFolder {
                selectedSidebarItem = FolderSidebarItem(
                    folder: folder,
                    trackCount: folderTrackCounts[folder.id ?? -1] ?? 0
                )
            }
        }
    }
    
    private func createContextMenuItems(for folder: Folder) -> [ContextMenuItem] {
        return [
            .button(title: "Refresh", action: {
                libraryManager.refreshFolder(folder)
            }),
            .button(title: "Reveal in Finder", action: {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
            }),
            .divider,
            .button(title: "Remove from Library", role: .destructive, action: {
                libraryManager.removeFolder(folder)
            })
        ]
    }
}

#Preview {
    @State var selectedFolder: Folder? = nil
    
    return FoldersSidebarView(selectedFolder: $selectedFolder)
        .environmentObject(LibraryManager())
        .frame(width: 250, height: 500)
}
