import SwiftUI

struct DynamicToolbar: View {
    let selectedTab: MainTab
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var viewType: LibraryViewType
    
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
                Button(action: { viewType = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .list ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .list ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("List View")
                
                Button(action: { viewType = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .grid ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .grid ? .white : .primary)
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
                Button(action: { viewType = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .list ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .list ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("List View")
                
                Button(action: { viewType = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .grid ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .grid ? .white : .primary)
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
            Spacer()
            
            // View toggle button (same as library)
            HStack(spacing: 0) {
                Button(action: { viewType = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .list ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .list ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .help("List View")
                
                Button(action: { viewType = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewType == .grid ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(viewType == .grid ? .white : .primary)
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
}

#Preview {
    @State var viewType: LibraryViewType = .list
    let libraryManager = LibraryManager()
    
    VStack(spacing: 0) {
        DynamicToolbar(selectedTab: .library, viewType: $viewType)
        DynamicToolbar(selectedTab: .folders, viewType: $viewType)
        DynamicToolbar(selectedTab: .playlists, viewType: $viewType)
    }
    .environmentObject(libraryManager)
}
