import SwiftUI

struct SettingsView: View {
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("closeToTray") private var closeToTray = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoScanInterval") private var autoScanInterval = 60.0
    
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var showingAddFolderSheet = false
    @State private var showingRemoveFolderAlert = false
    @State private var folderToRemove: Folder?
    
    var body: some View {
        TabView {
            // General Settings Tab
            generalSettingsView
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // Library Management Tab
            libraryManagementView
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            
            // About Tab
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500) // Fixed size
        .padding(20) // Add padding around the entire view
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
            Section(header: Text("Application")) {
                Toggle("Start at login", isOn: $startAtLogin)
                Toggle("Keep running when window is closed", isOn: $closeToTray)
                Toggle("Show notifications for new tracks", isOn: $showNotifications)
            }
            
            Section(header: Text("Library Scanning")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-scan interval")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $autoScanInterval, in: 1...120, step: 1) {
                            Text("Scan Interval")
                        }
                        
                        Text("\(Int(autoScanInterval)) min")
                            .frame(width: 50)
                            .font(.caption)
                    }
                    
                    Text("How often to check watched folders for new music files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                Divider()
                
                HStack {
                    Button("Refresh Library Now") {
                        libraryManager.refreshLibrary()
                    }
                    .disabled(libraryManager.isScanning)
                    
                    Spacer()
                    
                    if libraryManager.isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning...")
                                .font(.caption)
                        }
                    }
                }
            }
            
            Section(header: Text("Maintenance")) {
                Button("Clean Up Missing Folders") {
                    libraryManager.cleanupMissingFolders()
                }
                
                Button("Reset All Library Data", role: .destructive) {
                    resetLibraryData()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
    }
    
    // MARK: - Library Management
    
    private var libraryManagementView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Watched Folders")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Folders that Petrichor monitors for music files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { libraryManager.addFolder() }) {
                    Label("Add Folder", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Divider()
            
            // Folders List
            if libraryManager.folders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No folders being watched")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add folders containing your music to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { libraryManager.addFolder() }) {
                        Label("Add Your First Folder", systemImage: "folder.badge.plus")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(libraryManager.folders) { folder in
                        FolderRowView(
                            folder: folder,
                            trackCount: libraryManager.getTracksInFolder(folder).count,
                            onRemove: {
                                folderToRemove = folder
                                showingRemoveFolderAlert = true
                            }
                        )
                    }
                }
                .frame(maxHeight: .infinity) // Take remaining space
            }
            
            // Footer Info
            if !libraryManager.folders.isEmpty {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
    }
    
    // MARK: - About
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            // Use the app icon from Assets
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Fallback to drop icon if app icon isn't found
                Image(systemName: "drop.fill")
                    .font(.system(size: 64))
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
            
            Spacer()
            
            // Library stats
            if !libraryManager.tracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Library Statistics")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(libraryManager.folders.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Folders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("\(libraryManager.tracks.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(libraryManager.getAllArtists().count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Artists")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            VStack(spacing: 12) {
                Text("Built with Swift and SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Named after the pleasant smell of earth after rain")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
    }
    
    // MARK: - Helper Methods
    
    private func resetLibraryData() {
        // Clear all saved data
        UserDefaults.standard.removeObject(forKey: "SavedMusicFolders")
        UserDefaults.standard.removeObject(forKey: "SavedMusicTracks")
        UserDefaults.standard.removeObject(forKey: "SecurityBookmarks")
        UserDefaults.standard.removeObject(forKey: "LastScanDate")
        
        // Clear in-memory data
        libraryManager.folders.removeAll()
        libraryManager.tracks.removeAll()
        
        print("All library data has been reset")
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let manager = LibraryManager()
            return manager
        }())
}
