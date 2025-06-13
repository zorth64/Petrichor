import SwiftUI

struct LibrarySidebarView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedFilterType: LibraryFilterType
    @Binding var selectedFilterItem: LibraryFilterItem?
    @Binding var pendingSearchText: String?
    
    @State private var filteredItems: [LibraryFilterItem] = []
    @State private var selectedSidebarItem: LibrarySidebarItem?
    @State private var searchText = ""
    @State private var localSearchText = ""
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
                totalTracksCount: libraryManager.searchResults.count,
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
        .onChange(of: sortAscending) { _ in
            // Re-sort items when sort order changes
            updateFilteredItems()
        }
        .onChange(of: pendingSearchText) { newValue in
            if let searchValue = newValue {
                // Apply the search
                searchText = searchValue
                localSearchText = searchValue
                // Update filtered items immediately
                updateFilteredItems()
                
                // Clear the pending search
                pendingSearchText = nil
                
                // Wait for the filtered items to update, then select the first match
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Check if we have any filtered items that match exactly
                    if let exactMatch = filteredItems.first(where: { $0.name == searchValue }) {
                        let sidebarItem = LibrarySidebarItem(filterItem: exactMatch)
                        handleItemSelection(sidebarItem)
                    } else if let firstMatch = filteredItems.first {
                        // Select the first match if no exact match
                        let sidebarItem = LibrarySidebarItem(filterItem: firstMatch)
                        handleItemSelection(sidebarItem)
                    } else {
                        // Fallback to "All" if no matches
                        let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                        let sidebarItem = LibrarySidebarItem(allItemFor: selectedFilterType, count: libraryManager.tracks.count)
                        handleItemSelection(sidebarItem)
                        selectedFilterItem = allItem
                    }
                }
            }
        }
        .onChange(of: selectedFilterType) { newType in
            handleFilterTypeChange(newType)
        }
        .onChange(of: libraryManager.searchResults) { _ in
            updateFilteredItems()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ListHeader {
            // Filter type dropdown - now icons-only
            IconOnlyDropdown(
                items: LibraryFilterType.allCases,
                selection: $selectedFilterType,
                iconProvider: { $0.icon },
                tooltipProvider: { $0.rawValue }
            )
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Filter \(selectedFilterType.rawValue.lowercased())...", text: $localSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onChange(of: localSearchText) { newValue in
                        searchText = newValue
                    }
                    .onChange(of: searchText) { newValue in
                        if localSearchText != newValue {
                            localSearchText = newValue
                        }
                        
                        // When search is cleared, select "All"
                        if newValue.isEmpty {
                            let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
                            selectedFilterItem = allItem
                            selectedSidebarItem = LibrarySidebarItem(allItemFor: selectedFilterType, count: libraryManager.tracks.count)
                        }
                    }
                
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
        // Always ensure we have a selection
        if selectedFilterItem == nil {
            let allItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: libraryManager.tracks.count)
            selectedFilterItem = allItem
        }
        
        // Always sync the sidebar selection with the filter selection
        if let filterItem = selectedFilterItem {
            if filterItem.name.hasPrefix("All") {
                selectedSidebarItem = LibrarySidebarItem(allItemFor: selectedFilterType, count: libraryManager.tracks.count)
            } else {
                selectedSidebarItem = LibrarySidebarItem(filterItem: filterItem)
            }
        }
    }
    
    private func handleItemSelection(_ item: LibrarySidebarItem) {
        // Update the selected sidebar item
        selectedSidebarItem = item
        
        if item.filterName.isEmpty {
            // "All" item selected - use appropriate track count based on search state
            let totalCount = libraryManager.searchResults.count
            selectedFilterItem = LibraryFilterItem.allItem(for: selectedFilterType, totalCount: totalCount)
        } else {
            // Regular filter item - calculate actual count based on current search
            let tracksToFilter = libraryManager.searchResults
            let matchingTracks = tracksToFilter.filter { track in
                selectedFilterType.trackMatches(track, filterValue: item.filterName)
            }
            
            selectedFilterItem = LibraryFilterItem(
                name: item.filterName,
                count: matchingTracks.count,
                filterType: selectedFilterType
            )
        }
    }
    
    private func handleFilterTypeChange(_ newType: LibraryFilterType) {
        // Reset selection when filter type changes
        let totalCount = libraryManager.searchResults.count
        let allItem = LibraryFilterItem.allItem(for: newType, totalCount: totalCount)
        selectedFilterItem = allItem
        
        // Create the corresponding sidebar item with the same ID
        selectedSidebarItem = LibrarySidebarItem(allItemFor: newType, count: totalCount)
        
        // Clear local search when switching filter types
        searchText = ""
        localSearchText = ""
        
        updateFilteredItems()
    }
    
    private func updateFilteredItems() {
        // Get items based on centralized search results
        var items: [LibraryFilterItem]
        items = selectedFilterType.getFilterItems(from: libraryManager.searchResults)
        
        // Apply local sidebar search filter if present
        if !searchText.isEmpty {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }
        
        // Apply custom sorting
        filteredItems = sortItemsWithUnknownFirst(items)
    }
    
    private func isValidFilterItem(_ item: LibraryFilterItem) -> Bool {
        // Check if this filter item exists in the current (non-searched) data
        let allItems = getFilterItems(for: selectedFilterType)
        return allItems.contains { $0.name == item.name }
    }
    
    // MARK: - Custom Sorting

    private func sortItemsWithUnknownFirst(_ items: [LibraryFilterItem]) -> [LibraryFilterItem] {
        // Separate items into two groups:
        // 1. "Unknown X" items
        // 2. Regular items
        var unknownItems: [LibraryFilterItem] = []
        var regularItems: [LibraryFilterItem] = []
        
        for item in items {
            if isUnknownItem(item) {
                unknownItems.append(item)
            } else {
                regularItems.append(item)
            }
        }
        
        // Sort regular items based on sortAscending state
        regularItems.sort { item1, item2 in
            let comparison = item1.name.localizedCaseInsensitiveCompare(item2.name)
            return sortAscending ?
                comparison == .orderedAscending :
                comparison == .orderedDescending
        }
        
        // Return with unknown items first, then sorted regular items
        // (The "All" item is added separately in the SidebarView extension)
        return unknownItems + regularItems
    }
    
    private func isUnknownItem(_ item: LibraryFilterItem) -> Bool {
        return item.name == selectedFilterType.unknownPlaceholder
    }
    
    private func getFilterItems(for filterType: LibraryFilterType) -> [LibraryFilterItem] {
        return libraryManager.getLibraryFilterItems(for: filterType)
    }

    private func getArtistItemsForSearch(_ searchTerm: String) -> [LibraryFilterItem] {
        let trimmedSearch = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return getFilterItems(for: .artists) }
        
        var artistTrackMap: [String: Set<Track>] = [:]
        
        for track in libraryManager.tracks {
            let artists = ArtistParser.parse(track.artist)
            for artist in artists {
                if artist.localizedCaseInsensitiveContains(trimmedSearch) {
                    if artistTrackMap[artist] == nil {
                        artistTrackMap[artist] = []
                    }
                    artistTrackMap[artist]?.insert(track)
                }
            }
        }
        
        return artistTrackMap.map { artist, trackSet in
            LibraryFilterItem(name: artist, count: trackSet.count, filterType: .artists)
        }
    }
}

#Preview {
    @State var selectedFilterType: LibraryFilterType = .artists
    @State var selectedFilterItem: LibraryFilterItem? = nil
    @State var pendingSearchText: String? = nil
    
    LibrarySidebarView(
        selectedFilterType: $selectedFilterType,
        selectedFilterItem: $selectedFilterItem,
        pendingSearchText: $pendingSearchText
    )
    .environmentObject(LibraryManager())
    .frame(width: 250, height: 500)
}
