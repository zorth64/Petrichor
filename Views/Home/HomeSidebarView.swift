import SwiftUI

struct HomeSidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var selectedItem: HomeSidebarItem?
    
    @State private var allItems: [HomeSidebarItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ListHeader {
                Text("")
                    .headerTitleStyle()
                Spacer()
            }
            
            Divider()
            
            // All items in one list
            SidebarView(
                items: allItems,
                selectedItem: $selectedItem,
                onItemTap: { item in
                    selectedItem = item
                },
                contextMenuItems: { item in
                    if case .pinned(let pinnedItem) = item.source {
                        return [
                            .button(title: "Remove from Home", role: nil) {
                                Task {
                                    await libraryManager.removePinnedItem(pinnedItem)
                                }
                            }
                        ]
                    }
                    return []
                },
                showIcon: true,
                iconColor: .secondary,
                showCount: false
            ) { item in
                    if case .pinned(let pinnedItem) = item.source {
                        return AnyView(
                            Button(action: {
                                Task {
                                    await libraryManager.removePinnedItem(pinnedItem)
                                }
                            }) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(selectedItem?.id == item.id ? .white.opacity(0.8) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from Home")
                        )
                    }
                    return AnyView(EmptyView())
            }
        }
        .onAppear {
            updateAllItems()
            updateSelectedItem()
        }
        .onChange(of: libraryManager.tracks.count) { _ in
            updateAllItems()
            updateSelectedItem()
        }
        .onChange(of: libraryManager.pinnedItems) { _ in
            updateAllItems()
            // Update selection if a pinned item was removed
            if let selected = selectedItem,
               case .pinned(let pinnedItem) = selected.source {
                if !libraryManager.pinnedItems.contains(where: { $0.id == pinnedItem.id }) {
                    selectedItem = allItems.first
                }
            }
        }
        .onChange(of: playlistManager.playlists.map { "\($0.id)-\($0.tracks.count)" }) { _ in
            updateAllItems()
        }
    }

    // MARK: - Update Items Helper
    
    private func updateAllItems() {
        let artistCount = libraryManager.databaseManager.getArtistCount()
        let albumCount = libraryManager.databaseManager.getAlbumCount()
        
        var items: [HomeSidebarItem] = [
            HomeSidebarItem(type: .tracks, trackCount: libraryManager.tracks.count),
            HomeSidebarItem(type: .artists, artistCount: artistCount),
            HomeSidebarItem(type: .albums, albumCount: albumCount)
        ]

        // Add pinned items with track counts
        let pinnedSidebarItems = libraryManager.pinnedItems.map { pinnedItem in
            let trackCount: Int
            switch pinnedItem.itemType {
            case .library:
                trackCount = libraryManager.getTracksForPinnedItem(pinnedItem).count
            case .playlist:
                trackCount = playlistManager.getTracksForPinnedPlaylist(pinnedItem).count
            }
            
            return HomeSidebarItem(pinnedItem: pinnedItem, trackCount: trackCount)
        }
        items.append(contentsOf: pinnedSidebarItems)
        
        // Preserve selection when updating items
        let currentSelectionId = selectedItem?.id
        allItems = items
        
        // Restore selection if it still exists
        if let currentId = currentSelectionId,
           let matchingItem = allItems.first(where: { $0.id == currentId }) {
            selectedItem = matchingItem
        }
    }

    // MARK: - Update Selection Helper

    private func updateSelectedItem() {
        // Select "Tracks" by default if nothing is selected
        if selectedItem == nil {
            selectedItem = allItems.first
        } else if let current = selectedItem {
            // Update the selected item to get the latest count for fixed items
            switch current.source {
            case .fixed(let type):
                selectedItem = allItems.first { item in
                    if case .fixed(let itemType) = item.source {
                        return itemType == type
                    }
                    return false
                }
            case .pinned:
                // Pinned items don't need updates
                break
            }
        }
    }
}

#Preview {
    @State var selectedItem: HomeSidebarItem?

    HomeSidebarView(selectedItem: $selectedItem)
        .environmentObject(LibraryManager())
        .environmentObject(PlaylistManager())
        .frame(width: 250, height: 500)
}
