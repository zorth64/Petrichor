import SwiftUI

struct FilterSidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedFilterType: LibraryFilterType
    @Binding var selectedFilterItem: LibraryFilterItem?
    @State private var searchText = ""
    @State private var selectedItemName: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter type selector
            filterTypeSelector
            
            Divider()
            
            // Search bar
            searchBar
            
            Divider()
            
            // Filter items list
            filterItemsList
        }
        .onChange(of: searchText) { newSearchText in
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
            // Reset selection when filter type changes
            let allItem = LibraryFilterItem.allItem(for: newFilterType, totalCount: libraryManager.tracks.count)
            selectedFilterItem = allItem
            selectedItemName = allItem.name
            searchText = ""
        }
        .onChange(of: selectedFilterItem) { newItem in
            selectedItemName = newItem?.name ?? ""
        }
        .onAppear {
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
    
    // MARK: - Filter Type Selector
    
    private var filterTypeSelector: some View {
        HStack {
            Picker("Filter by", selection: $selectedFilterType) {
                ForEach(LibraryFilterType.allCases, id: \.self) { filterType in
                    HStack {
                        Image(systemName: filterType.icon)
                            .font(.system(size: 12))
                        Text(filterType.rawValue)
                            .font(.system(size: 13))
                    }
                    .tag(filterType)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            TextField("Filter \(selectedFilterType.rawValue.lowercased())...", text: $searchText)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Filter Items List
    
    private var filterItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // "All" item - always show unless we're searching and it doesn't match
                let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                let showAllItem = searchText.isEmpty || allItem.name.localizedCaseInsensitiveContains(searchText)
                
                if showAllItem {
                    FilterItemRow(
                        item: allItem,
                        isSelected: selectedItemName == allItem.name,
                        onTap: {
                            selectedFilterItem = allItem
                            selectedItemName = allItem.name
                            print("Selected: \(allItem.name)")
                        }
                    )
                    
                    // Add divider after "All" item if there are other items
                    if !filteredItems.isEmpty {
                        Divider()
                            .opacity(0.3)
                            .padding(.horizontal, 16)
                    }
                }
                
                // Individual filter items
                if filteredItems.isEmpty && !searchText.isEmpty {
                    // Empty search results
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("No results found")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        FilterItemRow(
                            item: item,
                            isSelected: selectedItemName == item.name,
                            onTap: {
                                selectedFilterItem = item
                                selectedItemName = item.name
                                print("Selected: \(item.name)")
                            }
                        )
                        
                        // Add divider between items (but not after the last item)
                        if index < filteredItems.count - 1 {
                            Divider()
                                .opacity(0.3)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var filteredItems: [LibraryFilterItem] {
        if searchText.isEmpty {
            return getFilterItems(for: selectedFilterType)
        } else {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSearch.isEmpty {
                return getFilterItems(for: selectedFilterType)
            }
            
            // Special handling for artist search to support partial matching
            if selectedFilterType == .artists {
                return getArtistItemsForSearch(trimmedSearch)
            } else {
                // For other filter types, use exact string matching
                let allItems = getFilterItems(for: selectedFilterType)
                return allItems.filter { item in
                    item.name.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilterItems(for filterType: LibraryFilterType) -> [LibraryFilterItem] {
        let tracks = libraryManager.tracks
        
        switch filterType {
        case .artists:
            // For artists, we want to show both individual artists and collaborative entries
            let allArtistStrings = tracks.map { $0.artist }
            let artistCounts = Dictionary(grouping: allArtistStrings, by: { $0 })
                .mapValues { $0.count }
            
            return artistCounts.map { artist, count in
                LibraryFilterItem(name: artist, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .albums:
            let albumCounts = Dictionary(grouping: tracks, by: { $0.album })
                .mapValues { $0.count }
            return albumCounts.map { album, count in
                LibraryFilterItem(name: album, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .genres:
            let genreCounts = Dictionary(grouping: tracks, by: { $0.genre })
                .mapValues { $0.count }
            return genreCounts.map { genre, count in
                LibraryFilterItem(name: genre, count: count, filterType: filterType)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .years:
            let yearCounts = Dictionary(grouping: tracks, by: { $0.year })
                .mapValues { $0.count }
            return yearCounts.map { year, count in
                LibraryFilterItem(name: year, count: count, filterType: filterType)
            }.sorted { year1, year2 in
                // Sort years in descending order (newest first)
                year1.name.localizedStandardCompare(year2.name) == .orderedDescending
            }
        }
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
