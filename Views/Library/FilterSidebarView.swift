import SwiftUI

struct FilterSidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedFilterType: LibraryFilterType
    @Binding var selectedFilterItem: LibraryFilterItem?
    @State private var filteredItems: [LibraryFilterItem] = []
    @State private var cachedFilterItems: [LibraryFilterType: [LibraryFilterItem]] = [:]
    @State private var searchText = ""
    @State private var selectedItemName: String = ""
    @State private var sortAscending = true
    
    var body: some View {
        VStack(spacing: 0) {
            filterSidebarHeader
            
            Divider()
            
            // Filter items list
            filterItemsList
        }
        .onChange(of: searchText) { newSearchText in
            updateFilteredItems()
            
            // If we have a search and the currently selected item is no longer visible,
            // reset to "All" item
            if !newSearchText.isEmpty {
                let currentFilteredItems = getFilterItems(for: selectedFilterType).filter { item in
                    item.name.localizedCaseInsensitiveContains(newSearchText)
                }
                
                // Check if current selection is still visible
                let isCurrentSelectionVisible = currentFilteredItems.contains { item in
                    item.name == selectedItemName
                }
                
                // If current selection is not visible and it's not the "All" item, reset to "All"
                if !isCurrentSelectionVisible && !selectedItemName.hasPrefix("All") {
                    let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                    selectedFilterItem = allItem
                    selectedItemName = allItem.name
                }
            }
        }
        .onChange(of: selectedFilterType) { newFilterType in
            updateFilteredItems()
            
            // Reset selection when filter type changes
            let allItem = LibraryFilterItem.allItem(for: newFilterType, totalCount: libraryManager.tracks.count)
            selectedFilterItem = allItem
            selectedItemName = allItem.name
            searchText = ""
        }
        .onChange(of: selectedFilterItem) { newItem in
            selectedItemName = newItem?.name ?? ""
        }
        .onChange(of: libraryManager.tracks) { _ in
            cachedFilterItems.removeAll()
            updateFilteredItems()
        }
        .onAppear {
            updateFilteredItems()
            
            // Initialize selection if not set
            if selectedFilterItem == nil {
                let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                selectedFilterItem = allItem
                selectedItemName = allItem.name
            } else {
                selectedItemName = selectedFilterItem?.name ?? ""
            }
        }
    }
    
    // MARK: - Filter Sidebar Header
    
    private var filterSidebarHeader: some View {
        HStack(spacing: 8) {
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
            
            // Search bar with sort button (matching Folders view exactly)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        // When clearing search, reset to "All" if current selection is not visible
                        let allItems = getFilterItems(for: selectedFilterType)
                        let isCurrentSelectionStillVisible = allItems.contains { item in
                            item.name == selectedItemName
                        }
                        
                        if !isCurrentSelectionStillVisible && !selectedItemName.hasPrefix("All") {
                            let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                            selectedFilterItem = allItem
                            selectedItemName = allItem.name
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(4)
            
            // Sort button (matching Folders view style)
            Button(action: {
                sortAscending.toggle()
                updateFilteredItems()
            }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Sort \(sortAscending ? "descending" : "ascending")")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Filter Items List
    
    private var filterItemsList: some View {
        List(selection: $selectedFilterItem) {  // Bind directly to selectedFilterItem
            // "All" item
            let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
            let showAllItem = searchText.isEmpty || allItem.name.localizedCaseInsensitiveContains(searchText)
            
            if showAllItem {
                Text(allItem.name)
                    .font(.system(size: 13))
                    .tag(allItem)  // Use the item itself as the tag
            }
            
            // Filter items
            ForEach(filteredItems) { item in
                Text(item.name)
                    .font(.system(size: 13))
                    .tag(item)  // Use the item itself as the tag
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func updateFilteredItems() {
        var items: [LibraryFilterItem]
        
        if searchText.isEmpty {
            items = getFilterItems(for: selectedFilterType)
        } else {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSearch.isEmpty {
                items = getFilterItems(for: selectedFilterType)
            } else if selectedFilterType == .artists {
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
        // Check cache first
        if let cached = cachedFilterItems[filterType] {
            return cached
        }
        
        // Compute items
        let items: [LibraryFilterItem]
        let tracks = libraryManager.tracks
        
        switch filterType {
        case .artists:
            let allArtistStrings = tracks.map { $0.artist }
            let artistCounts = Dictionary(grouping: allArtistStrings, by: { $0 })
                .mapValues { $0.count }
            
            items = artistCounts.map { artist, count in
                LibraryFilterItem(name: artist, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .albums:
            let albumCounts = Dictionary(grouping: tracks, by: { $0.album })
                .mapValues { $0.count }
            items = albumCounts.map { album, count in
                LibraryFilterItem(name: album, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .genres:
            let genreCounts = Dictionary(grouping: tracks, by: { $0.genre })
                .mapValues { $0.count }
            items = genreCounts.map { genre, count in
                LibraryFilterItem(name: genre, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .years:
            let yearCounts = Dictionary(grouping: tracks, by: { $0.year })
                .mapValues { $0.count }
            items = yearCounts.map { year, count in
                LibraryFilterItem(name: year, count: count, filterType: filterType)
            }.sorted { year1, year2 in
                year1.name.localizedStandardCompare(year2.name) == .orderedDescending
            }
        }
        
        // Cache the result
        cachedFilterItems[filterType] = items
        return items
    }
    
    private func getFilteredTracksForArtistSearch(_ searchTerm: String) -> [Track] {
        let trimmedSearch = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return libraryManager.tracks }
        
        return libraryManager.tracks.filter { track in
            // Check if the search term appears anywhere in the artist field
            track.artist.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
    
    private func getArtistItemsForSearch(_ searchTerm: String) -> [LibraryFilterItem] {
        let trimmedSearch = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return getFilterItems(for: .artists) }
        
        // Get all tracks that contain the searched artist
        let matchingTracks = getFilteredTracksForArtistSearch(trimmedSearch)
        
        // Group by exact artist string (preserving collaborations)
        let artistCounts = Dictionary(grouping: matchingTracks, by: { $0.artist })
            .mapValues { $0.count }
        
        return artistCounts.map { artist, count in
            LibraryFilterItem(name: artist, count: count, filterType: .artists)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

#Preview {
    @State var selectedFilterType: LibraryFilterType = .artists
    @State var selectedFilterItem: LibraryFilterItem? = nil
    
    return FilterSidebarView(
        selectedFilterType: $selectedFilterType,
        selectedFilterItem: $selectedFilterItem
    )
    .environmentObject({
        let manager = LibraryManager()
        return manager
    }())
    .frame(width: 250, height: 500)
}
