import SwiftUI

struct LibraryTabView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var showingRemoveFolderAlert = false
    @State private var showingResetConfirmation = false
    @State private var selectedFolderIDs: Set<Int64> = []
    @State private var isSelectMode: Bool = false
    @State private var folderToRemove: Folder?
    
    var body: some View {
        VStack(spacing: 0) {
            if libraryManager.folders.isEmpty {
                // Empty state
                NoMusicEmptyStateView(context: .settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Library management UI
                libraryManagementContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Remove Folder", isPresented: $showingRemoveFolderAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let folder = folderToRemove {
                    libraryManager.removeFolder(folder)
                    folderToRemove = nil
                }
            }
        } message: {
            if let folder = folderToRemove {
                Text("Are you sure you want to stop watching \"\(folder.name)\"? This will remove all tracks from this folder from your library.")
            }
        }
        .alert("Reset Library Data", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All Data", role: .destructive) {
                resetLibraryData()
            }
        } message: {
            Text("This will permanently remove all library data, including added folders, tracks, and playlists. This action cannot be undone.")
        }
    }
    
    private var libraryManagementContent: some View {
        VStack(spacing: 0) {
            libraryHeader
            foldersList
            libraryFooter
        }
    }
    
    private var libraryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Watched Folders")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(libraryManager.folders.count) folders • \(libraryManager.tracks.count) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { libraryManager.refreshLibrary() }) {
                Label("Refresh Library", systemImage: "arrow.clockwise")
            }
            .disabled(libraryManager.isScanning)
            .help("Scan for new files and update metadata")
            
            Button(action: { libraryManager.addFolder() }) {
                Label("Add Folder", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var foldersList: some View {
        VStack(spacing: 0) {
            // Selection controls bar
            if libraryManager.folders.count > 1 {
                HStack {
                    Button(action: toggleSelectMode) {
                        Text(isSelectMode ? "Done" : "Select")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    if isSelectMode {
                        Text("\(selectedFolderIDs.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    if isSelectMode && !selectedFolderIDs.isEmpty {
                        Button(action: removeSelectedFolders) {
                            Label("Remove Selected", systemImage: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 5)
            }
            
            // Folders list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(libraryManager.folders) { folder in
                        compactFolderRow(for: folder)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 350)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .overlay(refreshOverlay)
        }
        .padding(.horizontal, 35)
    }
    
    @ViewBuilder
    private var refreshOverlay: some View {
        if libraryManager.isScanning || libraryManager.isBackgroundScanning {
            ZStack {
                // Semi-transparent background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.5))
                
                // Content container with background
                VStack(spacing: 20) {
                    // Animated icon (same as NoMusicEmptyStateView)
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                Color.accentColor,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .rotationEffect(.degrees(libraryManager.isScanning || libraryManager.isBackgroundScanning ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: libraryManager.isScanning || libraryManager.isBackgroundScanning)
                        
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Refreshing Library")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if !libraryManager.scanStatusMessage.isEmpty {
                            Text(libraryManager.scanStatusMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 250, height: 32)  // Fixed height for status message
                        } else {
                            // Empty spacer to maintain height when no message
                            Color.clear
                                .frame(width: 250, height: 32)
                        }
                    }
                }
                .frame(width: 300, height: 180)  // Fixed size container
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 10)
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeInOut(duration: 0.2), value: libraryManager.isScanning || libraryManager.isBackgroundScanning)
        }
    }

    private var libraryFooter: some View {
        VStack(spacing: 12) {
            // Action buttons row
            HStack(spacing: 12) {
                Button(action: { libraryManager.cleanupMissingFolders() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                        Text("Clean Up Missing Folders")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: { showingResetConfirmation = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("Reset All Library Data")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Status info
            if let lastScan = UserDefaults.standard.object(forKey: "LastScanDate") as? Date {
                HStack {
                    Text("Last scan: \(lastScan, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Folder Row
    @ViewBuilder
    private func compactFolderRow(for folder: Folder) -> some View {
        let isSelected = selectedFolderIDs.contains(folder.id ?? -1)
        let trackCount = libraryManager.getTracksInFolder(folder).count
        
        CompactFolderRowView(
            folder: folder,
            trackCount: trackCount,
            isSelected: isSelected,
            isSelectMode: isSelectMode,
            onToggleSelection: { toggleFolderSelection(folder) },
            onRefresh: { libraryManager.refreshFolder(folder) },
            onRemove: {
                folderToRemove = folder
                showingRemoveFolderAlert = true
            }
        )
    }

    // MARK: - Helper Methods
    private func toggleSelectMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectMode.toggle()
            if !isSelectMode {
                selectedFolderIDs.removeAll()
            }
        }
    }

    private func toggleFolderSelection(_ folder: Folder) {
        guard let folderId = folder.id else { return }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            if selectedFolderIDs.contains(folderId) {
                selectedFolderIDs.remove(folderId)
            } else {
                selectedFolderIDs.insert(folderId)
            }
        }
    }

    private func removeSelectedFolders() {
        let selectedFolders = libraryManager.folders.filter { folder in
            guard let id = folder.id else { return false }
            return selectedFolderIDs.contains(id)
        }
        
        let alert = NSAlert()
        alert.messageText = "Remove Selected Folders"
        alert.informativeText = "Are you sure you want to remove \(selectedFolders.count) folders? This will remove all tracks from these folders from your library."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            for folder in selectedFolders {
                libraryManager.removeFolder(folder)
            }
            selectedFolderIDs.removeAll()
            isSelectMode = false
        }
    }
    
    private func resetLibraryData() {
        // Stop any current playback
        if let coordinator = AppCoordinator.shared {
            coordinator.audioPlayerManager.stop()
            coordinator.playlistManager.clearQueue()
        }

        // Clear UserDefaults settings
        UserDefaults.standard.removeObject(forKey: "SavedMusicFolders")
        UserDefaults.standard.removeObject(forKey: "SavedMusicTracks")
        UserDefaults.standard.removeObject(forKey: "SecurityBookmarks")
        UserDefaults.standard.removeObject(forKey: "LastScanDate")
        
        // Clear playback state
        UserDefaults.standard.removeObject(forKey: "SavedPlaybackState")
        UserDefaults.standard.removeObject(forKey: "SavedPlaybackUIState")
        
        Task {
            do {
                try await libraryManager.resetAllData()
                print("All library data has been reset")
            } catch {
                print("Failed to reset library data: \(error)")
            }
        }
    }
}

private struct CompactFolderRowView: View {
    let folder: Folder
    let trackCount: Int
    let isSelected: Bool
    let isSelectMode: Bool
    let onToggleSelection: () -> Void
    let onRefresh: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (only in select mode)
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .onTapGesture {
                        onToggleSelection()
                    }
            }
            
            // Folder icon
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
            
            // Folder info
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(folder.url.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Text("\(trackCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    +
                    Text(" tracks")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Individual actions (when not in select mode)
            if !isSelectMode {
                HStack(spacing: 4) {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh this folder")
                    
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this folder")
                }
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected && isSelectMode ?
                    Color.accentColor.opacity(0.1) :
                    (isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color.clear)
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if isSelectMode {
                onToggleSelection()
            }
        }
    }
}

#Preview {
    LibraryTabView()
        .environmentObject(LibraryManager())
        .frame(width: 600, height: 500)
}
