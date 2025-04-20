//
//  LibraryManager.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-04-19.
//


import Foundation
import AppKit

class LibraryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tracks: [Track] = []
    @Published var folders: [Folder] = []
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var fileWatcherTimer: Timer?
    
    // MARK: - Initialization
    init() {
        startFileWatcher()
        loadMusicLibrary()
    }
    
    deinit {
        fileWatcherTimer?.invalidate()
    }
    
    // MARK: - Folder Management
    
    func addFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK else { return }
            
            for url in openPanel.urls {
                let folder = Folder(url: url)
                
                // Check if folder already exists
                if !self.folders.contains(where: { $0.url == url }) {
                    self.folders.append(folder)
                    
                    // Start scanning for music files
                    self.scanFolderForMusicFiles(url)
                }
            }
        }
    }
    
    func removeFolder(_ folder: Folder) {
        folders.removeAll(where: { $0.id == folder.id })
        
        // Remove tracks that were in this folder
        let folderPrefix = folder.url.path
        tracks.removeAll(where: { $0.url.path.hasPrefix(folderPrefix) })
        
        saveMusicLibrary()
    }
    
    // MARK: - File Scanning
    
    private func scanFolderForMusicFiles(_ folderURL: URL) {
        // Supported audio formats
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "flac"]
        
        // Use a background thread for scanning
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Recursively enumerate all files
            if let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                var newTracks: [Track] = []
                
                for case let fileURL as URL in enumerator {
                    do {
                        // Check if it's a file
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        guard resourceValues.isRegularFile == true else { continue }
                        
                        // Check if it's a supported audio file
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            // Check if we already have this track
                            if !self.tracks.contains(where: { $0.url == fileURL }) {
                                let track = Track(url: fileURL)
                                newTracks.append(track)
                            }
                        }
                    } catch {
                        print("Error examining \(fileURL): \(error)")
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.tracks.append(contentsOf: newTracks)
                    self.saveMusicLibrary()
                }
            }
        }
    }
    
    // MARK: - File Watching
    
    private func startFileWatcher() {
        // Create a timer that checks for file changes every minute
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Rescan all folders for new files
            for folder in self.folders {
                self.scanFolderForMusicFiles(folder.url)
            }
        }
    }
    
    // MARK: - Data Management
    
    func saveMusicLibrary() {
        // In a real implementation, you'd save the folders list and other user preferences
        print("Saving music library with \(folders.count) folders and \(tracks.count) tracks")
    }
    
    func loadMusicLibrary() {
        // In a real implementation, you'd load saved folders and rescan them
        print("Loading music library")
    }
    
    // MARK: - Track Management
    
    func getTracksInFolder(_ folder: Folder) -> [Track] {
        let folderPrefix = folder.url.path
        return tracks.filter { $0.url.path.hasPrefix(folderPrefix) }
    }
    
    func getTracksByArtist(_ artist: String) -> [Track] {
        return tracks.filter { $0.artist == artist }
    }
    
    func getTracksByAlbum(_ album: String) -> [Track] {
        return tracks.filter { $0.album == album }
    }
    
    func getTracksByGenre(_ genre: String) -> [Track] {
        return tracks.filter { $0.genre == genre }
    }
    
    func getAllArtists() -> [String] {
        return Array(Set(tracks.map { $0.artist })).sorted()
    }
    
    func getAllAlbums() -> [String] {
        return Array(Set(tracks.map { $0.album })).sorted()
    }
    
    func getAllGenres() -> [String] {
        return Array(Set(tracks.map { $0.genre })).sorted()
    }
}
