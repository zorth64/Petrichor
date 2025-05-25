import SwiftUI

struct SimpleFolderListView: View {
    let folders: [Folder]
    @Binding var selectedFolder: Folder?
    let onRefresh: (Folder) -> Void
    let onRevealInFinder: (Folder) -> Void
    let onRemove: (Folder) -> Void
    @EnvironmentObject var libraryManager: LibraryManager
    
    var body: some View {
        List(folders, id: \.id, selection: $selectedFolder) { folder in
            SimpleFolderRow(
                folder: folder,
                trackCount: libraryManager.getTracksInFolder(folder).count
            )
            .tag(folder)
            .listRowSeparatorTint(Color(NSColor.separatorColor).opacity(0.3))
            .listRowSeparator(.visible, edges: .bottom)
            .contextMenu {
                Button("Refresh") {
                    onRefresh(folder)
                }
                
                Button("Reveal in Finder") {
                    onRevealInFinder(folder)
                }
                
                Divider()
                
                Button("Remove from Library", role: .destructive) {
                    onRemove(folder)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden) // Hide the default List background
        .background(Color(NSColor.textBackgroundColor)) // Add our custom background
    }
}

struct SimpleFolderRow: View {
    let folder: Folder
    let trackCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text("\(trackCount) tracks")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let sampleFolders = [
        Folder(url: URL(fileURLWithPath: "/Users/test/Music")),
        Folder(url: URL(fileURLWithPath: "/Users/test/Downloads"))
    ]
    
    @State var selectedFolder: Folder? = nil
    
    return SimpleFolderListView(
        folders: sampleFolders,
        selectedFolder: $selectedFolder,
        onRefresh: { _ in print("Refresh") },
        onRevealInFinder: { _ in print("Reveal") },
        onRemove: { _ in print("Remove") }
    )
    .environmentObject({
        let manager = LibraryManager()
        return manager
    }())
    .frame(width: 250, height: 400)
}
