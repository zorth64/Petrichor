import SwiftUI

struct LibrarySidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedFilterType: LibraryFilterType
    @Binding var selectedFilterItem: LibraryFilterItem?
    
    @State private var filteredItems: [LibraryFilterItem] = []
    @State private var selectedSidebarItem: LibrarySidebarItem?
    @State private var searchText = ""
    @State private var sortAscending = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with filter type and search
            headerSection
            
            Divider()
            
            // Sidebar content
            SidebarView(
                filterItems: filteredItems,
                filterType: selectedFilterType,
                totalTracksCount: libraryManager.tracks.count,
                selectedItem: $selectedSidebarItem,
                onItemTap: { item in
                    handleItemSelection(item)
                }
            )
        }
        .onAppear {
            initializeSelection()
            updateFilteredItems()
        }
        .onChange(of: searchText) { _ in
            updateFilteredItems()
        }
        .onChange(of: selectedFilterType) { newType in
            handleFilterTypeChange(newType)
        }
        .onChange(of: libraryManager.tracks) { _ in
            updateFilteredItems()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ListHeader {
            // Filter type dropdown
            Picker("", selection: $selectedFilterType) {
                ForEach(LibraryFilterType.allCases, id: \.self) { filterType in
                    HStack(spacing: 4) {
                        Image(systemName: filterType.icon)
                            .font(.system(size: 11))
                        Text(filterType.rawValue)
                            .font(.system(size: 12))
                    }
                    .tag(filterType)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .labelsHidden()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search...", text: $searchText)
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
            .help("Sort \(sortAscending ? "descending" : "ascending")")
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeSelection() {
        if selectedFilterItem == nil {
            let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
            selectedFilterItem = allItem
            selectedSidebarItem = LibrarySidebarItem(allItemFor: selectedFilterType, count: libraryManager.tracks.count)
        } else if let filterItem = selectedFilterItem {
            selectedSidebarItem = LibrarySidebarItem(filterItem: filterItem)
        }
    }
    
    private func handleItemSelection(_ item: LibrarySidebarItem) {
        // Update the selected sidebar item
        selectedSidebarItem = item
        
        if item.filterName.isEmpty {
            // "All" item selected
            selectedFilterItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
        } else {
            // Regular filter item
            selectedFilterItem = LibraryFilterItem(
                name: item.filterName,
                count: item.count ?? 0,
                filterType: selectedFilterType
            )
        }
    }
    
    private func handleFilterTypeChange(_ newType: LibraryFilterType) {
        // Reset selection when filter type changes
        let allItem = LibraryFilterItem.allItem(for: newType, totalCount: libraryManager.tracks.count)
        selectedFilterItem = allItem
        selectedSidebarItem = LibrarySidebarItem(allItemFor: newType, count: libraryManager.tracks.count)
        searchText = ""
        updateFilteredItems()
    }
    
    private func updateFilteredItems() {
        var items: [LibraryFilterItem]
        
        if searchText.isEmpty {
            items = getFilterItems(for: selectedFilterType)
        } else {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if selectedFilterType == .artists {
                items = getArtistItemsForSearch(trimmedSearch)
            } else {
                let allItems = getFilterItems(for: selectedFilterType)
                items = allItems.filter { item in
                    item.name.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }
        }
        
        // Apply sorting
        filteredItems = items.sorted { item1, item2 in
            if sortAscending {
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            } else {
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedDescending
            }
        }
    }
    
    private func getFilterItems(for filterType: LibraryFilterType) -> [LibraryFilterItem] {
        let tracks = libraryManager.tracks
        
        switch filterType {
        case .artists:
            let artistCounts = Dictionary(grouping: tracks, by: { $0.artist })
                .mapValues { $0.count }
            return artistCounts.map { artist, count in
                LibraryFilterItem(name: artist, count: count, filterType: filterType)
            }
            
        case .albums:
            let albumCounts = Dictionary(grouping: tracks, by: { $0.album })
                .mapValues { $0.count }
            return albumCounts.map { album, count in
                LibraryFilterItem(name: album, count: count, filterType: filterType)
            }
            
        case .genres:
            let genreCounts = Dictionary(grouping: tracks, by: { $0.genre })
                .mapValues { $0.count }
            return genreCounts.map { genre, count in
                LibraryFilterItem(name: genre, count: count, filterType: filterType)
            }
            
        case .years:
            let yearCounts = Dictionary(grouping: tracks, by: { $0.year })
                .mapValues { $0.count }
            return yearCounts.map { year, count in
                LibraryFilterItem(name: year, count: count, filterType: filterType)
            }
        }
    }
    
    private func getArtistItemsForSearch(_ searchTerm: String) -> [LibraryFilterItem] {
        let trimmedSearch = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return getFilterItems(for: .artists) }
        
        let matchingTracks = libraryManager.tracks.filter { track in
            track.artist.localizedCaseInsensitiveContains(trimmedSearch)
        }
        
        let artistCounts = Dictionary(grouping: matchingTracks, by: { $0.artist })
            .mapValues { $0.count }
        
        return artistCounts.map { artist, count in
            LibraryFilterItem(name: artist, count: count, filterType: .artists)
        }
    }
}

#Preview {
    @State var selectedFilterType: LibraryFilterType = .artists
    @State var selectedFilterItem: LibraryFilterItem? = nil
    
    return LibrarySidebarView(
        selectedFilterType: $selectedFilterType,
        selectedFilterItem: $selectedFilterItem
    )
    .environmentObject(LibraryManager())
    .frame(width: 250, height: 500)
}
