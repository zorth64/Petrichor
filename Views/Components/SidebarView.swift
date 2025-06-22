import SwiftUI

// MARK: - Sidebar Item Protocol
protocol SidebarItem: Identifiable, Equatable {
    var id: UUID { get }
    var title: String { get }
    var subtitle: String? { get }
    var icon: String? { get }
    var count: Int? { get }
    var isEditable: Bool { get }
}

// Default implementation for backwards compatibility
extension SidebarItem {
    var isEditable: Bool { false }
}

// MARK: - Sidebar View
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

    @State private var hoveredItemID: UUID?
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFieldFocused: Bool
    @State private var lastClickTime = Date()
    @State private var lastClickedItemID: UUID?

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
        VStack(spacing: 0) {
            // Header
            if headerTitle != nil || headerControls != nil {
                sidebarHeader
                    .background(Color(NSColor.controlBackgroundColor))
                Divider()
                    .background(Color(NSColor.separatorColor))
            }

            // Items list
            if items.isEmpty {
                emptyView
            } else {
                itemsList
            }
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack {
            if let title = headerTitle {
                Text(title)
                    .headerTitleStyle()
            }

            Spacer()

            if let controls = headerControls {
                controls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Items List

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(items) { item in
                    SidebarItemRow(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        isHovered: hoveredItemID == item.id,
                        isEditing: editingItemID == item.id,
                        editingText: $editingText,
                        isEditingFieldFocused: _isEditingFieldFocused,
                        showIcon: showIcon,
                        iconColor: iconColor,
                        showCount: showCount,
                        trailingContent: trailingContent,
                        onTap: {
                            // Handled by onTapGesture below
                        },
                        onHover: { isHovered in
                            hoveredItemID = isHovered ? item.id : nil
                        },
                        onStartEditing: {
                            // Handled by onTapGesture below
                        },
                        onCommitEditing: {
                            let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && trimmed != item.title {
                                onRename?(item, trimmed)
                            }
                            editingItemID = nil
                        },
                        onCancelEditing: {
                            editingItemID = nil
                            editingText = ""
                        }
                    )
                    .contextMenu {
                        if let menuItems = contextMenuItems?(item) {
                            ForEach(menuItems, id: \.id) { menuItem in
                                contextMenuItem(menuItem)
                            }
                        }
                    }
                    .onTapGesture {
                        if editingItemID != item.id {
                            let now = Date()
                            let timeSinceLastClick = now.timeIntervalSince(lastClickTime)

                            // Check for double-click on the same item
                            if timeSinceLastClick < 0.3 && lastClickedItemID == item.id && item.isEditable {
                                editingItemID = item.id
                                editingText = item.title
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isEditingFieldFocused = true
                                }
                            } else {
                                selectedItem = item
                                onItemTap(item)
                            }

                            lastClickTime = now
                            lastClickedItemID = item.id
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.gray)

            Text("No Items")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Context Menu Helper

    @ViewBuilder
    private func contextMenuItem(_ item: ContextMenuItem) -> some View {
        switch item {
        case .button(let title, let role, let action):
            if title == "Rename" {
                // Special handling for rename action
                Button(title, role: role) {
                    if let selectedItem = selectedItem, selectedItem.isEditable {
                        editingItemID = selectedItem.id
                        editingText = selectedItem.title
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isEditingFieldFocused = true
                        }
                    }
                }
            } else {
                Button(title, role: role, action: action)
            }
        case .menu(let title, let items):
            Menu(title) {
                ForEach(items, id: \.id) { subItem in
                    if case .button(let subTitle, let subRole, let subAction) = subItem {
                        Button(subTitle, role: subRole, action: subAction)
                    }
                }
            }
        case .divider:
            Divider()
        }
    }
}

// MARK: - Sidebar Item Row
private struct SidebarItemRow<Item: SidebarItem>: View {
    let item: Item
    let isSelected: Bool
    let isHovered: Bool
    let isEditing: Bool
    @Binding var editingText: String
    @FocusState var isEditingFieldFocused: Bool
    let showIcon: Bool
    let iconColor: Color
    let showCount: Bool
    let trailingContent: ((Item) -> AnyView)?
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let onStartEditing: () -> Void
    let onCommitEditing: () -> Void
    let onCancelEditing: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            if showIcon, let icon = item.icon {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : iconColor)
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
            }

            // Content
            if isEditing {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .focused($isEditingFieldFocused)
                    .onSubmit {
                        onCommitEditing()
                    }
                    .onExitCommand {
                        onCancelEditing()
                    }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Trailing content (pin icon, etc.)
            if let trailing = trailingContent?(item) {
                trailing
            } else if showCount, let count = item.count, count > 0 {
                // Default count badge if no trailing content
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white : Color.secondary.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            if !isEditing {
                onHover(hovering)
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Concrete Item Types

// Home Sidebar Item
struct HomeSidebarItem: SidebarItem {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String?
    var count: Int?
    let isEditable: Bool = false
    let type: HomeItemType?
    
    // Item source
    enum ItemSource {
        case fixed(HomeItemType)
        case pinned(PinnedItem)
    }
    let source: ItemSource

    enum HomeItemType: CaseIterable {
        case tracks
        case artists
        case albums

        var stableID: UUID {
            switch self {
            case .tracks:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            case .artists:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            case .albums:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            }
        }

        var title: String {
            switch self {
            case .tracks: return "Tracks"
            case .artists: return "Artists"
            case .albums: return "Albums"
            }
        }

        var icon: String {
            switch self {
            case .tracks: return "music.note"
            case .artists: return "person.2.fill"
            case .albums: return "opticaldisc.fill"
            }
        }
    }

    // Init for fixed items
    init(type: HomeItemType, trackCount: Int? = nil, artistCount: Int? = nil, albumCount: Int? = nil) {
        self.id = type.stableID
        self.type = type
        self.source = .fixed(type)
        self.title = type.title
        self.icon = type.icon

        // Set subtitle based on type
        switch type {
        case .tracks:
            if let count = trackCount {
                self.subtitle = "\(count) songs"
            } else {
                self.subtitle = "0 songs"
            }
        case .artists:
            if let count = artistCount {
                self.subtitle = "\(count) artists"
            } else {
                self.subtitle = "0 artists"
            }
        case .albums:
            if let count = albumCount {
                self.subtitle = "\(count) albums"
            } else {
                self.subtitle = "0 albums"
            }
        }
    }
    
    // Init for pinned items
    init(pinnedItem: PinnedItem) {
        self.id = UUID(uuidString: "pinned-\(pinnedItem.id ?? 0)") ?? UUID()
        self.type = nil
        self.source = .pinned(pinnedItem)
        self.title = pinnedItem.displayName
        self.subtitle = nil
        self.icon = pinnedItem.iconName
    }
}

// MARK: - Equatable Conformance
extension HomeSidebarItem: Equatable {
    static func == (lhs: HomeSidebarItem, rhs: HomeSidebarItem) -> Bool {
        // Compare by ID first (most common case)
        if lhs.id != rhs.id {
            return false
        }
        
        // Then compare by source
        switch (lhs.source, rhs.source) {
        case (.fixed(let lhsType), .fixed(let rhsType)):
            return lhsType == rhsType
        case (.pinned(let lhsItem), .pinned(let rhsItem)):
            return lhsItem.id == rhsItem.id
        default:
            return false
        }
    }
}

// Library Filter Item
struct LibrarySidebarItem: SidebarItem {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String?
    let count: Int?
    let filterType: LibraryFilterType
    let filterName: String
    let isEditable: Bool = false // Library items are not editable

    init(filterItem: LibraryFilterItem) {
        self.id = filterItem.id  // Use the stable ID from filterItem
        self.title = filterItem.name
        self.subtitle = nil
        // Use the appropriate icon based on filter type
        self.icon = Self.getIcon(for: filterItem.filterType, isAllItem: false)
        self.count = filterItem.count
        self.filterType = filterItem.filterType
        self.filterName = filterItem.name
    }

    // Special "All" item
    init(allItemFor filterType: LibraryFilterType, count: Int) {
        self.id = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", filterType.stableIndex))") ?? UUID()
        self.title = "All \(filterType.rawValue)"
        self.subtitle = nil
        // Use a different icon for "All" items
        self.icon = Self.getIcon(for: filterType, isAllItem: true)
        self.count = count
        self.filterType = filterType
        self.filterName = ""
    }

    private static func getIcon(for filterType: LibraryFilterType, isAllItem: Bool) -> String {
        isAllItem ? filterType.allItemIcon : filterType.icon
    }
}

// Playlist Item
struct PlaylistSidebarItem: SidebarItem {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String?
    let count: Int?
    let playlist: Playlist
    let isEditable: Bool

    init(playlist: Playlist) {
        self.id = playlist.id
        self.title = playlist.name
        self.icon = Self.getIcon(for: playlist)
        self.playlist = playlist
        self.isEditable = playlist.isUserEditable

        // Set subtitle and count based on playlist type
        if playlist.type == .smart {
            let trackCount = playlist.tracks.count
            if let limit = playlist.trackLimit {
                self.subtitle = "\(trackCount) / \(limit) songs"
            } else {
                self.subtitle = "\(trackCount) songs"
            }
            self.count = nil
        } else {
            self.subtitle = "\(playlist.tracks.count) songs"
            self.count = nil
        }
    }

    private static func getIcon(for playlist: Playlist) -> String {
        switch playlist.smartType {
        case .favorites:
            return "star.fill"
        case .mostPlayed:
            return "play.circle.fill"
        case .recentlyPlayed:
            return "clock.fill"
        case .custom, .none:
            return "music.note.list"
        }
    }
}

// Folder Node Item
struct FolderNodeSidebarItem: SidebarItem {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String?
    let count: Int?
    let folderNode: FolderNode
    let isEditable: Bool = false

    init(folderNode: FolderNode) {
        self.id = folderNode.id
        self.title = folderNode.name
        self.folderNode = folderNode

        if folderNode.children.isEmpty {
            self.icon = "folder.fill"
        } else {
            self.icon = folderNode.isExpanded ? "folder.fill.badge.minus" : "folder.fill.badge.plus"
        }

        if folderNode.immediateFolderCount > 0 && folderNode.immediateTrackCount > 0 {
            self.subtitle = "\(folderNode.immediateFolderCount) folders, \(folderNode.immediateTrackCount) tracks"
        } else if folderNode.immediateFolderCount > 0 {
            self.subtitle = "\(folderNode.immediateFolderCount) folders"
        } else if folderNode.immediateTrackCount > 0 {
            self.subtitle = "\(folderNode.immediateTrackCount) tracks"
        } else {
            self.subtitle = nil
        }

        self.count = nil
    }
}

// MARK: - Convenience Extensions

extension SidebarView where Item == LibrarySidebarItem {
    init(
        filterItems: [LibraryFilterItem],
        filterType: LibraryFilterType,
        totalTracksCount: Int,
        selectedItem: Binding<LibrarySidebarItem?>,
        onItemTap: @escaping (LibrarySidebarItem) -> Void,
        contextMenuItems: ((LibrarySidebarItem) -> [ContextMenuItem])? = nil
    ) {
        // Create items list
        var items: [LibrarySidebarItem] = []

        // Add "All" item first
        let allItem = LibrarySidebarItem(allItemFor: filterType, count: totalTracksCount)
        items.append(allItem)

        // Add filter items (which should already be sorted with Unknown first)
        items.append(contentsOf: filterItems.map { LibrarySidebarItem(filterItem: $0) })

        self.init(
            items: items,
            selectedItem: selectedItem,
            onItemTap: onItemTap,
            contextMenuItems: contextMenuItems,
            showIcon: true,
            iconColor: .secondary,
            showCount: true
        )
    }
}
