//
//  Playlist.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-04-19.
//


import Foundation

struct Playlist: Identifiable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var dateCreated: Date
    var dateModified: Date
    var coverArtworkData: Data?
    
    init(name: String, tracks: [Track] = [], coverArtworkData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.tracks = tracks
        self.dateCreated = Date()
        self.dateModified = Date()
        self.coverArtworkData = coverArtworkData
    }
    
    // Add a track to the playlist
    mutating func addTrack(_ track: Track) {
        // Check if track is already in playlist
        if !tracks.contains(where: { $0.id == track.id }) {
            tracks.append(track)
            dateModified = Date()
        }
    }
    
    // Remove a track from the playlist
    mutating func removeTrack(_ track: Track) {
        tracks.removeAll(where: { $0.id == track.id })
        dateModified = Date()
    }
    
    // Move a track within the playlist
    mutating func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < tracks.count,
              destinationIndex >= 0, destinationIndex < tracks.count,
              sourceIndex != destinationIndex else {
            return
        }
        
        let track = tracks.remove(at: sourceIndex)
        tracks.insert(track, at: destinationIndex)
        dateModified = Date()
    }
    
    // Clear all tracks from the playlist
    mutating func clearTracks() {
        tracks.removeAll()
        dateModified = Date()
    }
    
    // Calculate total duration of the playlist
    var totalDuration: Double {
        return tracks.reduce(0) { $0 + $1.duration }
    }
    
    // Get the first available artwork to use as playlist cover if none is explicitly set
    var effectiveCoverArtwork: Data? {
        if let customCover = coverArtworkData {
            return customCover
        }
        
        // Use the first track with artwork as the playlist cover
        return tracks.first(where: { $0.artworkData != nil })?.artworkData
    }
}

// Extension to format the duration for display
extension Playlist {
    // Format the total duration as a string (HH:MM:SS)
    var formattedTotalDuration: String {
        let totalSeconds = Int(totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}