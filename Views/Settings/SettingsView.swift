import SwiftUI

struct SettingsView: View {
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("closeToMenubar") private var closeToMenubar = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoScanInterval") private var autoScanInterval: AutoScanInterval = .every60Minutes
    
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var showingAddFolderSheet = false
    @State private var showingRemoveFolderAlert = false
    @State private var showingResetConfirmation = false
    @State private var folderToRemove: Folder?
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case library = "Library"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .library: return "music.note.list"
            case .about: return "info.circle"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .general: return "gear"
            case .library: return "music.note.list"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            SettingsTabBar(selectedTab: $selectedTab)
                .padding()
            
            Divider()
            
            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    generalSettingsView
                case .library:
                    libraryManagementView
                case .about:
                    aboutView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
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
    }
    
    // MARK: - General Settings
    
    private var generalSettingsView: some View {
        Form {
            Section("Application") {
                Toggle("Start at login", isOn: $startAtLogin)
                Toggle("Keep running in menubar on close", isOn: $closeToMenubar)
                Toggle("Show notifications for new tracks", isOn: $showNotifications)
            }
            
            Section("Library Scanning") {
                HStack {
                    Picker("Auto-scan library every", selection: $autoScanInterval) {
                        ForEach(AutoScanInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .padding()
    }
    
    // MARK: - Library Management
    
    private var libraryManagementView: some View {
        VStack(spacing: 0) {
            if libraryManager.folders.isEmpty {
                // Show our unified empty state when no folders exist
                NoMusicEmptyStateView(context: .settings)
            } else {
                // Show the normal library management UI
                libraryManagementContent
            }
        }
        .padding(10)
    }
    
    private var libraryManagementContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watched Folders")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Folders that Petrichor monitors for music files")
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
            .padding()
            .background(Color.clear)
            
            Divider()
            
            // Folders List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(libraryManager.folders) { folder in
                        VStack(spacing: 0) {
                            SettingsFolderRow(
                                folder: folder,
                                trackCount: libraryManager.getTracksInFolder(folder).count,
                                onRemove: {
                                    folderToRemove = folder
                                    showingRemoveFolderAlert = true
                                }
                            )
                            .padding()
                            
                            if folder.id != libraryManager.folders.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 12) {
                Button(action: { libraryManager.cleanupMissingFolders() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintbrush")
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
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
            }
            .alert("Reset Library Data", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset All Data", role: .destructive) {
                    resetLibraryData()
                }
            } message: {
                Text("This will permanently remove all library data, including added folders, tracks, and settings. This action cannot be undone.")
            }
            .padding(.horizontal, 20)
            Spacer()
            
            // Footer Info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(libraryManager.folders.count) folders monitored")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(libraryManager.tracks.count) total tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastScan = UserDefaults.standard.object(forKey: "LastScanDate") as? Date {
                    Text("Last scan: \(lastScan, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if libraryManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundColor(Color.clear)
                }
            }
            .padding()
            .background(Color.clear)
        }
    }
    
    // MARK: - About
    
    private var aboutView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                // App Icon and Info
                VStack(spacing: 16) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Petrichor Music Player")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("A beautiful music player for macOS")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Library Statistics
                if !libraryManager.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Library Statistics")
                            .font(.headline)
                        
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("\(libraryManager.folders.count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Folders")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(libraryManager.tracks.count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(libraryManager.getAllArtists().count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Artists")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                
                // Footer Info
                VStack(spacing: 8) {
                    Text("Built with Swift and SwiftUI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Named after the pleasant smell of earth after rain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .multilineTextAlignment(.center)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .scrollDisabled(libraryManager.tracks.isEmpty)
        .background(Color.clear)
    }
    
    // MARK: - Helper Methods
    
    private func resetLibraryData() {
        // Clear UserDefaults settings
        UserDefaults.standard.removeObject(forKey: "SavedMusicFolders")
        UserDefaults.standard.removeObject(forKey: "SavedMusicTracks")
        UserDefaults.standard.removeObject(forKey: "SecurityBookmarks")
        UserDefaults.standard.removeObject(forKey: "LastScanDate")
        
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

// MARK: - Settings Tab Bar

struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsView.SettingsTab
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(SettingsView.SettingsTab.allCases, id: \.self) { tab in
                SettingsTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(Color.white) :
                        isHovered ? AnyShapeStyle(Color.primary) :
                        AnyShapeStyle(Color.secondary)
                    )
                
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isHovered ? .primary :
                        .secondary
                    )
            }
            .frame(width: 85) // Fixed width for all tabs
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? Color.accentColor :
                        isHovered ? Color.primary.opacity(0.06) :
                        Color.clear
                    )
                    .animation(.easeOut(duration: 0.15), value: isSelected)
                    .animation(.easeOut(duration: 0.1), value: isHovered)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)  // Disable focus ring
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Folder Row Component

struct SettingsFolderRow: View {
    let folder: Folder
    let trackCount: Int
    let onRemove: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Folder icon
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack {
                        Text(folder.url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(trackCount) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 8) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    
                    HStack {
                        Text("Full Path:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(folder.url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    HStack {
                        Text("Added:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Recently") // You could store this date if needed
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if trackCount > 0 {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    } else {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text("No tracks found")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let manager = LibraryManager()
            return manager
        }())
}
