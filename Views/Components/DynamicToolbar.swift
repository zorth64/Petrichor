import SwiftUI

struct DynamicToolbar: View {
    let selectedTab: MainTab
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var libraryViewType: LibraryViewType
    
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
            Spacer()
            
            // View toggle button (Finder-style)
            HStack(spacing: 0) {
                Button(action: { libraryViewType = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(libraryViewType == .list ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(libraryViewType == .list ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("List View")
                
                Button(action: { libraryViewType = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(libraryViewType == .grid ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(libraryViewType == .grid ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("Grid View")
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
            
            Spacer()
        }
    }
    
    // MARK: - Folders Toolbar
    
    private var foldersToolbar: some View {
        HStack {
            Spacer()
            
            // View toggle button (same as library)
            HStack(spacing: 0) {
                Button(action: { libraryViewType = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(libraryViewType == .list ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(libraryViewType == .list ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("List View")
                
                Button(action: { libraryViewType = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(libraryViewType == .grid ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(libraryViewType == .grid ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("Grid View")
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
            
            Spacer()
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
    @State var libraryViewType: LibraryViewType = .list
    
    return VStack(spacing: 0) {
        DynamicToolbar(selectedTab: .library, libraryViewType: $libraryViewType)
        DynamicToolbar(selectedTab: .folders, libraryViewType: $libraryViewType)
        DynamicToolbar(selectedTab: .playlists, libraryViewType: $libraryViewType)
    }
    .environmentObject({
        let manager = LibraryManager()
        return manager
    }())
}
