import SwiftUI

struct DynamicToolbar: View {
    let selectedTab: MainTab
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var searchText = ""
    
    var body: some View {
        HStack {
            switch selectedTab {
            case .library:
                libraryToolbar
            case .folders:
                foldersToolbar
            case .playlists:
                playlistsToolbar
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Library Toolbar
    
    private var libraryToolbar: some View {
        HStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search your library...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 350)
            
            Spacer()
            
            // Library stats
            Text("\(libraryManager.tracks.count) tracks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Folders Toolbar
    
    private var foldersToolbar: some View {
        HStack {
            Button(action: { libraryManager.addFolder() }) {
                Label("Add Folder", systemImage: "folder.badge.plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            // Note: Remove folder functionality will be handled through context menu in folder list
            // since we don't have direct access to selected folder here
            
            Spacer()
            
            // Folder stats
            HStack(spacing: 16) {
                Text("\(libraryManager.folders.count) folders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if libraryManager.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Playlists Toolbar
    
    private var playlistsToolbar: some View {
        HStack {
            Button(action: {
                // TODO: Implement create playlist
            }) {
                Label("New Playlist", systemImage: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Spacer()
            
            // Playlist stats (placeholder)
            Text("Coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DynamicToolbar(selectedTab: .library)
        DynamicToolbar(selectedTab: .folders)
        DynamicToolbar(selectedTab: .playlists)
    }
    .environmentObject({
        let manager = LibraryManager()
        return manager
    }())
}
