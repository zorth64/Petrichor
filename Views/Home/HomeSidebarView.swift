import SwiftUI

struct HomeSidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var selectedItem: HomeSidebarItem?

    private var sidebarItems: [HomeSidebarItem] {
        let artistCount = libraryManager.databaseManager.getArtistCount()
        let albumCount = libraryManager.databaseManager.getAlbumCount()

        return [
            HomeSidebarItem(type: .tracks, trackCount: libraryManager.tracks.count),
            HomeSidebarItem(type: .artists, artistCount: artistCount),
            HomeSidebarItem(type: .albums, albumCount: albumCount)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            Divider()

            // Sidebar items
            itemsList
        }
        .onAppear {
            updateSelectedItem()
        }
        .onChange(of: libraryManager.tracks.count) { _ in
            // Force update when track count changes
            updateSelectedItem()
        }
    }

    // MARK: - Update Selection Helper

    private func updateSelectedItem() {
        // Select "Tracks" by default if nothing is selected
        if selectedItem == nil {
            selectedItem = sidebarItems.first
        } else if let currentType = selectedItem?.type {
            // Update the selected item to get the latest count
            selectedItem = sidebarItems.first { $0.type == currentType }
        }
    }

    // MARK: - Sidebar Header

    private var sidebarHeader: some View {
        ListHeader {
            Text("")
                .headerTitleStyle()

            Spacer()
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        SidebarView(
            items: sidebarItems,
            selectedItem: $selectedItem,
            onItemTap: { item in
                selectedItem = item
            },
            showIcon: true,
            iconColor: .secondary,
            showCount: false  // Set to false since we're using subtitle
        )
    }
}

#Preview {
    @State var selectedItem: HomeSidebarItem?

    HomeSidebarView(selectedItem: $selectedItem)
        .environmentObject(LibraryManager())
        .environmentObject(PlaylistManager())
        .frame(width: 250, height: 500)
}
