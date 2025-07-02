import SwiftUI

// MARK: - SidebarView Wrapper

struct SidebarView<Item: SidebarItem>: View {
    let items: [Item]
    @Binding var selectedItem: Item?
    let onItemTap: (Item) -> Void
    let contextMenuItems: ((Item) -> [ContextMenuItem])?
    let onRename: ((Item, String) -> Void)?
    let trailingContent: ((Item) -> AnyView)?
    
    // Header configuration
    let headerTitle: String?
    let headerControls: AnyView?
    
    // Customization
    let showIcon: Bool
    let iconColor: Color
    let showCount: Bool
    
    init(
        items: [Item],
        selectedItem: Binding<Item?>,
        onItemTap: @escaping (Item) -> Void,
        contextMenuItems: ((Item) -> [ContextMenuItem])? = nil,
        onRename: ((Item, String) -> Void)? = nil,
        headerTitle: String? = nil,
        headerControls: AnyView? = nil,
        showIcon: Bool = true,
        iconColor: Color = .secondary,
        showCount: Bool = false,
        trailingContent: ((Item) -> AnyView)? = nil
    ) {
        self.items = items
        self._selectedItem = selectedItem
        self.onItemTap = onItemTap
        self.contextMenuItems = contextMenuItems
        self.onRename = onRename
        self.headerTitle = headerTitle
        self.headerControls = headerControls
        self.showIcon = showIcon
        self.iconColor = iconColor
        self.showCount = showCount
        self.trailingContent = trailingContent
    }
    
    var body: some View {
        SidebarListView(
            items: items,
            selectedItem: $selectedItem,
            onItemTap: onItemTap,
            contextMenuItems: contextMenuItems,
            onRename: onRename,
            headerTitle: headerTitle,
            headerControls: headerControls,
            showIcon: showIcon,
            iconColor: iconColor,
            showCount: showCount,
            trailingContent: trailingContent
        )
    }
}

// MARK: - Convenience Initializer for Library

extension SidebarView where Item == LibrarySidebarItem {
    init(
        filterItems: [LibraryFilterItem],
        filterType: LibraryFilterType,
        totalTracksCount: Int,
        selectedItem: Binding<LibrarySidebarItem?>,
        onItemTap: @escaping (LibrarySidebarItem) -> Void,
        contextMenuItems: ((LibrarySidebarItem) -> [ContextMenuItem])? = nil
    ) {
        // Use the convenience initializer from SidebarListView
        let listView = SidebarListView(
            filterItems: filterItems,
            filterType: filterType,
            totalTracksCount: totalTracksCount,
            selectedItem: selectedItem,
            onItemTap: onItemTap,
            contextMenuItems: contextMenuItems
        )
        
        // Extract the properties we need
        self.items = listView.items
        self._selectedItem = selectedItem
        self.onItemTap = onItemTap
        self.contextMenuItems = contextMenuItems
        self.onRename = nil
        self.headerTitle = nil
        self.headerControls = nil
        self.showIcon = true
        self.iconColor = .secondary
        self.showCount = false
        self.trailingContent = nil
    }
}
