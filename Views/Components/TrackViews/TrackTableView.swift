import SwiftUI
import AppKit
import Combine

class ContextMenuTableView: NSTableView {
    var contextMenuHandler: ((NSEvent) -> NSMenu?)?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        return contextMenuHandler?(event)
    }
}

struct TrackTableView: NSViewRepresentable {
    let tracks: [Track]
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @StateObject private var columnManager = ColumnVisibilityManager.shared
    
    @State private var sortOrder: [NSSortDescriptor] = []
    @AppStorage("trackTableSortOrder") private var sortOrderData: Data = Data()
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = ContextMenuTableView()
        let headerView = NSTableHeaderView()
        
        tableView.contextMenuHandler = { event in
            context.coordinator.handleContextMenu(for: event, in: tableView)
        }
        
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(Coordinator.doubleClick(_:))
        tableView.target = context.coordinator
        context.coordinator.setTableView(tableView)
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = []
        
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.style = .fullWidth
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = NSColor.controlBackgroundColor
        
        // Add these settings for better column behavior
        tableView.allowsColumnReordering = true
        tableView.allowsColumnSelection = false
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        headerView.tableView = tableView
        tableView.headerView = headerView
        
        // Set up columns
        setupColumns(tableView: tableView)
        
        if let savedSort = UserDefaults.standard.dictionary(forKey: "trackTableSortOrder"),
           let key = savedSort["key"] as? String,
           let ascending = savedSort["ascending"] as? Bool {
            tableView.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        }
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        
        DispatchQueue.main.async {
            self.redistributeColumnWidths(tableView: tableView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        
        // Store the current playing track info before updates
        let previousPlayingPath = context.coordinator.audioPlayerManager.currentTrack?.url.path
        
        // Only update if tracks actually changed (by count or IDs)
        let tracksChanged = context.coordinator.tracks.count != tracks.count ||
                           !zip(context.coordinator.tracks, tracks).allSatisfy { $0.id == $1.id }
        
        if tracksChanged {
            context.coordinator.tracks = tracks
            context.coordinator.sortedTracks = tracks
            
            // Apply any existing sort descriptors to the new tracks
            if !tableView.sortDescriptors.isEmpty {
                context.coordinator.tableView(tableView, sortDescriptorsDidChange: [])
            } else {
                tableView.reloadData()
            }
        }
        
        // Always update these properties
        if context.coordinator.selectedTrackID != selectedTrackID {
            DispatchQueue.main.async {
                context.coordinator.selectedTrackID = selectedTrackID
            }
        }
        context.coordinator.columnVisibility = columnManager.columnVisibility
        context.coordinator.audioPlayerManager = audioPlayerManager
        
        // Update column visibility
        updateColumnVisibility(tableView: tableView)
        
        // Update selection if needed
        if let selectedID = selectedTrackID,
           let index = context.coordinator.sortedTracks.firstIndex(where: { $0.id == selectedID }) {
            if !tableView.selectedRowIndexes.contains(index) {
                DispatchQueue.main.async {
                    tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            }
        }
        
        // Only update playing indicator if the playing track changed
        let currentPlayingPath = audioPlayerManager.currentTrack?.url.path
        let isCurrentlyPlaying = audioPlayerManager.isPlaying
        let wasPlaying = context.coordinator.isPlaying
        let playbackStateChanged = wasPlaying != isCurrentlyPlaying

        // Update playing indicator if track or playback state changed
        if previousPlayingPath != currentPlayingPath || playbackStateChanged || !tracksChanged {
            // Update the previous playing track row (to remove indicator)
            if let oldPath = previousPlayingPath,
               let oldIndex = context.coordinator.sortedTracks.firstIndex(where: { $0.url.path == oldPath }) {
                updateRowView(at: oldIndex, in: tableView)
            }
            
            // Update the current playing track row (to show/hide indicator based on play state)
            if let newPath = currentPlayingPath,
               let newIndex = context.coordinator.sortedTracks.firstIndex(where: { $0.url.path == newPath }) {
                updateRowView(at: newIndex, in: tableView)
            }
        }
        // Store the current playing state
        context.coordinator.isPlaying = isCurrentlyPlaying
    }

    private func updateRowView(at row: Int, in tableView: NSTableView) {
        let titleColumnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("title"))
        guard titleColumnIndex >= 0 else { return }
        
        // This will trigger a redraw of just this specific cell
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet(integer: titleColumnIndex))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            tracks: tracks,
            selectedTrackID: $selectedTrackID,
            onPlayTrack: onPlayTrack,
            audioPlayerManager: audioPlayerManager,
            contextMenuItems: contextMenuItems,
            columnVisibility: columnManager.columnVisibility
        )
    }
    
    private func setupColumns(tableView: NSTableView) {
        // Remove any existing columns first
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        
        for column in TrackTableColumn.allColumns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.identifier))
            tableColumn.title = column.displayName
            
            // Set resizing mask to allow user resizing
            tableColumn.resizingMask = .userResizingMask
            
            // Add sort descriptor
            switch column {
            case .special(.title):
                tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: "title", ascending: true)
                tableColumn.width = 300
                tableColumn.minWidth = 150
                
            case .special(.duration):
                tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: "duration", ascending: true)
                tableColumn.width = 70
                tableColumn.minWidth = 50
                
            case .libraryFilter(let filterType):
                let sortKey = filterType.databaseColumn
                tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: sortKey, ascending: true)
                
                switch filterType {
                case .artists, .albums:
                    tableColumn.width = 200
                    tableColumn.minWidth = 100
                case .albumArtists, .composers:
                    tableColumn.width = 150
                    tableColumn.minWidth = 100
                case .genres:
                    tableColumn.width = 120
                    tableColumn.minWidth = 80
                case .years:
                    tableColumn.width = 60
                    tableColumn.minWidth = 50
                }
            }
            
            tableColumn.isHidden = !columnManager.columnVisibility.isVisible(column)
            tableView.addTableColumn(tableColumn)
        }
    }
    
    private func updateColumnVisibility(tableView: NSTableView) {
        for column in TrackTableColumn.allColumns {
            if let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column.identifier)) {
                tableColumn.isHidden = !columnManager.columnVisibility.isVisible(column)
            }
        }
        
        DispatchQueue.main.async {
            self.redistributeColumnWidths(tableView: tableView)
        }
    }
    
    private func redistributeColumnWidths(tableView: NSTableView) {
        let visibleColumns = tableView.tableColumns.filter { !$0.isHidden }
        guard !visibleColumns.isEmpty else { return }
        
        // Get the table view's visible width
        let scrollView = tableView.enclosingScrollView
        let availableWidth = scrollView?.documentVisibleRect.width ?? tableView.bounds.width
        
        // Calculate current total width of visible columns
        let currentTotalWidth = visibleColumns.reduce(0) { $0 + $1.width }
        
        // If columns don't fill the space, distribute the difference
        if currentTotalWidth < availableWidth - 20 { // 20px margin for scrollbar
            let difference = availableWidth - currentTotalWidth - 20
            let additionalWidthPerColumn = difference / CGFloat(visibleColumns.count)
            
            for column in visibleColumns {
                column.width = column.width + additionalWidthPerColumn
            }
        }
    }
    
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var tracks: [Track]
        var sortedTracks: [Track] = []
        @Binding var selectedTrackID: UUID?
        var hoveredRow: Int? = nil
        var isPlaying: Bool = false
        let onPlayTrack: (Track) -> Void
        var audioPlayerManager: AudioPlayerManager
        let contextMenuItems: (Track) -> [ContextMenuItem]
        var columnVisibility: TrackTableColumnVisibility
        var sortOrder: [NSSortDescriptor] = []
        var currentlyPlayingTrackPath: String? = nil
        
        private var reloadTimer: Timer?
        private var pendingReload = false
        private var cancellables = Set<AnyCancellable>()
        private weak var hostTableView: NSTableView?
        
        init(tracks: [Track],
             selectedTrackID: Binding<UUID?>,
             onPlayTrack: @escaping (Track) -> Void,
             audioPlayerManager: AudioPlayerManager,
             contextMenuItems: @escaping (Track) -> [ContextMenuItem],
             columnVisibility: TrackTableColumnVisibility) {
            self.tracks = tracks
            self.sortedTracks = tracks
            self._selectedTrackID = selectedTrackID
            self.onPlayTrack = onPlayTrack
            self.audioPlayerManager = audioPlayerManager
            self.contextMenuItems = contextMenuItems
            self.columnVisibility = columnVisibility
            
            super.init()
            
            // Observe playback state changes
            audioPlayerManager.$isPlaying
                .sink { [weak self] _ in
                    self?.updatePlayingIndicator()
                }
                .store(in: &cancellables)
            
            audioPlayerManager.$currentTrack
                .sink { [weak self] _ in
                    self?.updatePlayingIndicator()
                }
                .store(in: &cancellables)
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            sortedTracks.count
        }
        
        func setTableView(_ tableView: NSTableView) {
            self.hostTableView = tableView
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < sortedTracks.count else { return nil }
            let track = sortedTracks[row]
            
            guard let columnID = tableColumn?.identifier.rawValue,
                  let column = TrackTableColumn.allColumns.first(where: { $0.identifier == columnID }) else {
                return nil
            }
            
            switch column {
            case .special(.title):
                // Keep NSHostingView for title since it's complex
                let identifier = NSUserInterfaceItemIdentifier("TitleCell")
                if let hostingView = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<TrackTableTitleCell> {
                    // Update the existing hosting view's content
                    hostingView.rootView = TrackTableTitleCell(
                        track: track,
                        isSelected: selectedTrackID == track.id,
                        audioPlayerManager: audioPlayerManager
                    )
                    return hostingView
                } else {
                    let hostingView = NSHostingView(rootView: TrackTableTitleCell(
                        track: track,
                        isSelected: selectedTrackID == track.id,
                        audioPlayerManager: audioPlayerManager
                    ))
                    hostingView.identifier = identifier
                    return hostingView
                }
                
            case .special(.duration):
                let text = formatDuration(track.duration)
                return makeOrReuseTextCell(
                    in: tableView,
                    column: tableColumn,
                    row: row,
                    text: text,
                    font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                    color: NSColor.secondaryLabelColor,
                    alignment: .right
                )
                
            case .libraryFilter(let filterType):
                let value = filterType.getValue(from: track)
                return makeOrReuseTextCell(
                    in: tableView,
                    column: tableColumn,
                    row: row,
                    text: value,
                    font: NSFont.systemFont(ofSize: 13),
                    color: NSColor.labelColor
                )
            }
        }
        
        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first,
                  let key = descriptor.key else {
                sortedTracks = tracks
                tableView.reloadData()
                return
            }
            
            // Only sort if the descriptors actually changed
            if oldDescriptors.first?.key == key &&
               oldDescriptors.first?.ascending == descriptor.ascending {
                return
            }
            
            // Use a more efficient sorting approach for large datasets
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let sorted = self.tracks.sorted { track1, track2 in
                    let ascending = descriptor.ascending
                    var result: ComparisonResult = .orderedSame
                    
                    switch key {
                    case "title":
                        result = track1.title.localizedCaseInsensitiveCompare(track2.title)
                    case "artist":
                        result = track1.artist.localizedCaseInsensitiveCompare(track2.artist)
                    case "album":
                        result = track1.album.localizedCaseInsensitiveCompare(track2.album)
                    case "album_artist":
                        let albumArtist1 = track1.albumArtist ?? ""
                        let albumArtist2 = track2.albumArtist ?? ""
                        result = albumArtist1.localizedCaseInsensitiveCompare(albumArtist2)
                    case "composer":
                        result = track1.composer.localizedCaseInsensitiveCompare(track2.composer)
                    case "genre":
                        result = track1.genre.localizedCaseInsensitiveCompare(track2.genre)
                    case "year":
                        result = track1.year.localizedCaseInsensitiveCompare(track2.year)
                    case "duration":
                        result = track1.duration < track2.duration ? .orderedAscending :
                                 track1.duration > track2.duration ? .orderedDescending : .orderedSame
                    default:
                        result = .orderedSame
                    }
                    
                    return ascending ? result == .orderedAscending : result == .orderedDescending
                }
                
                DispatchQueue.main.async {
                    self.sortedTracks = sorted
                    tableView.reloadData()
                    self.saveSortOrder(key: key, ascending: descriptor.ascending)
                }
            }
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = HoverableTableRowView()
            rowView.coordinator = self
            rowView.row = row
            return rowView
        }
        
        func tableView(_ tableView: NSTableView, menuFor event: NSEvent) -> NSMenu? {
            print("Context menu requested") // Debug
            
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            
            print("Row clicked: \(row)") // Debug
            
            guard row >= 0, row < sortedTracks.count else { return nil }
            
            let track = sortedTracks[row]
            let menuItems = contextMenuItems(track)
            
            print("Menu items count: \(menuItems.count)") // Debug
            
            // If the clicked row isn't selected, select it
            if !tableView.selectedRowIndexes.contains(row) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                selectedTrackID = track.id
            }
            
            // Create NSMenu from ContextMenuItem array
            return createNSMenu(from: menuItems, track: track)
        }
        
        func handleContextMenu(for event: NSEvent, in tableView: NSTableView) -> NSMenu? {
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            
            guard row >= 0, row < sortedTracks.count else { return nil }
            
            let track = sortedTracks[row]
            let menuItems = contextMenuItems(track)
            
            // If the clicked row isn't selected, select it
            if !tableView.selectedRowIndexes.contains(row) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                selectedTrackID = track.id
            }
            
            // Create NSMenu from ContextMenuItem array
            return createNSMenu(from: menuItems, track: track)
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            
            if let selectedRow = tableView.selectedRowIndexes.first,
               selectedRow < sortedTracks.count {
                selectedTrackID = sortedTracks[selectedRow].id
            }
        }
        
        @objc func doubleClick(_ sender: NSTableView) {
            let clickedRow = sender.clickedRow
            guard clickedRow >= 0, clickedRow < tracks.count else { return }
            
            let track = sortedTracks[clickedRow]
            onPlayTrack(track)
        }

        private func createNSMenu(from items: [ContextMenuItem], track: Track) -> NSMenu {
            let menu = NSMenu()
            
            for item in items {
                switch item {
                case .button(let title, let role, let action):
                    let menuItem = NSMenuItem(title: title, action: #selector(contextMenuAction(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.representedObject = ContextMenuAction(action: action, track: track)
                    
                    // Set attributes for destructive role
                    if role == .destructive {
                        menuItem.attributedTitle = NSAttributedString(
                            string: title,
                            attributes: [.foregroundColor: NSColor.systemRed]
                        )
                    }
                    
                    menu.addItem(menuItem)
                    
                case .menu(let title, let subItems):
                    let submenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    let submenu = createNSMenu(from: subItems, track: track)
                    submenu.title = title
                    submenuItem.submenu = submenu
                    menu.addItem(submenuItem)
                    
                case .divider:
                    menu.addItem(NSMenuItem.separator())
                }
            }
            
            return menu
        }

        // Helper class to store the action closure
        private class ContextMenuAction {
            let action: () -> Void
            let track: Track
            
            init(action: @escaping () -> Void, track: Track) {
                self.action = action
                self.track = track
            }
        }
        
        private func saveSortOrder(key: String, ascending: Bool) {
            let storage = ["key": key, "ascending": ascending] as [String : Any]
            UserDefaults.standard.set(storage, forKey: "trackTableSortOrder")
        }
        
        private func formatDuration(_ seconds: Double) -> String {
            let totalSeconds = Int(max(0, seconds))
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
        
        @objc private func contextMenuAction(_ sender: NSMenuItem) {
            guard let action = sender.representedObject as? ContextMenuAction else { return }
            action.action()
        }
        
        private func updatePlayingIndicator() {
            guard let tableView = hostTableView else { return }
            
            // Find and update the currently playing track row
            if let currentTrack = audioPlayerManager.currentTrack,
               let index = sortedTracks.firstIndex(where: { $0.url.path == currentTrack.url.path }) {
                let titleColumnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("title"))
                if titleColumnIndex >= 0 {
                    tableView.reloadData(forRowIndexes: IndexSet(integer: index),
                                        columnIndexes: IndexSet(integer: titleColumnIndex))
                }
            }
        }
        
        private func makeOrReuseTextCell(in tableView: NSTableView, column: NSTableColumn?, row: Int, text: String, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> NSTableCellView {
            let identifier = NSUserInterfaceItemIdentifier("TextCell")
            
            let cellView: NSTableCellView
            if let reusedCell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
                cellView = reusedCell
                // Update existing text field
                if let textField = cellView.textField {
                    textField.stringValue = text
                    textField.font = font
                    textField.textColor = color
                    textField.alignment = alignment
                }
            } else {
                // Create new cell
                cellView = NSTableCellView()
                let textField = NSTextField(labelWithString: text)
                textField.font = font
                textField.textColor = color
                textField.alignment = alignment
                textField.lineBreakMode = .byTruncatingTail
                textField.translatesAutoresizingMaskIntoConstraints = false
                
                cellView.addSubview(textField)
                cellView.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
            }
            
            return cellView
        }
        
        private func scheduleReload(for tableView: NSTableView) {
            pendingReload = true
            
            // Cancel existing timer
            reloadTimer?.invalidate()
            
            // Schedule new reload after a short delay
            reloadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                guard let self = self, self.pendingReload else { return }
                self.pendingReload = false
                tableView.reloadData()
            }
        }
    }
    
    class HoverableTableRowView: NSTableRowView {
        weak var coordinator: TrackTableView.Coordinator?
        var row: Int = -1
        private var trackingArea: NSTrackingArea?
        private var backgroundLayer: CALayer?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupBackgroundLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupBackgroundLayer()
        }
        
        private func setupBackgroundLayer() {
            wantsLayer = true
            
            // Create a background layer for smooth animations
            backgroundLayer = CALayer()
            backgroundLayer?.frame = bounds
            backgroundLayer?.backgroundColor = NSColor.clear.cgColor
            layer?.insertSublayer(backgroundLayer!, at: 0)
        }
        
        override func layout() {
            super.layout()
            backgroundLayer?.frame = bounds
        }
        
        override func drawBackground(in dirtyRect: NSRect) {
            // Don't draw anything here - we'll use the layer instead
        }
        
        private func updateBackgroundColor(animated: Bool = true) {
            let color: NSColor
            
            if isSelected {
                color = NSColor.controlAccentColor.withAlphaComponent(0.25)
            } else if coordinator?.hoveredRow == row {
                color = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15)
            } else {
                color = NSColor.clear
            }
            
            if animated {
                CATransaction.begin()
                CATransaction.setAnimationDuration(coordinator?.hoveredRow == row ? 0.1 : 0.15)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                backgroundLayer?.backgroundColor = color.cgColor
                CATransaction.commit()
            } else {
                backgroundLayer?.backgroundColor = color.cgColor
            }
        }
        
        override var isSelected: Bool {
            didSet {
                updateBackgroundColor(animated: true)
            }
        }
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
            trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
        
        override func mouseEntered(with event: NSEvent) {
            coordinator?.hoveredRow = row
            updateBackgroundColor(animated: true)

            if let tableView = superview as? NSTableView {
                tableView.enumerateAvailableRowViews { rowView, _ in
                    if let hoverableRow = rowView as? HoverableTableRowView, hoverableRow != self {
                        hoverableRow.updateBackgroundColor(animated: true)
                    }
                }
            }
        }
        
        override func mouseExited(with event: NSEvent) {
            if coordinator?.hoveredRow == row {
                coordinator?.hoveredRow = nil
            }
            updateBackgroundColor(animated: true)
        }
    }
}

// Native version of title cell
struct TrackTableTitleCell: View {
    let track: Track
    let isSelected: Bool
    let audioPlayerManager: AudioPlayerManager
    
    // Use the track's existing artwork data directly
    private var artworkImage: NSImage? {
        if let data = track.artworkData {
            return NSImage(data: data)
        }
        return nil
    }
    
    private var isCurrentTrack: Bool {
        guard let currentTrack = audioPlayerManager.currentTrack else { return false }
        return currentTrack.url.path == track.url.path
    }
    
    private var isPlaying: Bool {
        isCurrentTrack && audioPlayerManager.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Album artwork
            ZStack {
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        )
                }
                
                if isPlaying {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .overlay(
                            PlayingIndicator()
                                .frame(width: 16)
                        )
                }
            }
            
            Text(track.title)
                .font(.system(size: 13, weight: isCurrentTrack ? .medium : .regular))
                .foregroundColor(isCurrentTrack ? Color.primary.opacity(0.9) : .primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}
