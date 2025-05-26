import Foundation
import AppKit

enum PlaylistType: String, Codable {
    case regular = "regular"
    case smart = "smart"
}

// Predefined smart playlist types
enum SmartPlaylistType: String, Codable {
    case favorites = "favorites"
    case mostPlayed = "mostPlayed"
    case recentlyPlayed = "recentlyPlayed"
    case custom = "custom"  // For future user-defined smart playlists
}

// Smart playlist criteria
struct SmartPlaylistCriteria: Codable {
    enum MatchType: String, Codable {
        case all = "all"  // AND
        case any = "any"  // OR
    }
    
    enum Condition: String, Codable {
        case contains = "contains"
        case equals = "equals"
        case startsWith = "startsWith"
        case endsWith = "endsWith"
        case greaterThan = "greaterThan"
        case lessThan = "lessThan"
    }
    
    struct Rule: Codable {
        let field: String  // "artist", "album", "genre", "year", "playCount", etc.
        let condition: Condition
        let value: String
    }
    
    let matchType: MatchType
    let rules: [Rule]
    let limit: Int?  // Track count limit (e.g., 25 for "Top 25")
    let sortBy: String?  // "dateAdded", "lastPlayed", "playCount", etc.
    let sortAscending: Bool
    
    // Default initializer
    init(matchType: MatchType = .all,
         rules: [Rule] = [],
         limit: Int? = nil,
         sortBy: String? = nil,
         sortAscending: Bool = true) {
        self.matchType = matchType
        self.rules = rules
        self.limit = limit
        self.sortBy = sortBy
        self.sortAscending = sortAscending
    }
    
    // Convenience initializers for predefined smart playlists
    static func favoritesPlaylist() -> SmartPlaylistCriteria {
        return SmartPlaylistCriteria(
            rules: [Rule(field: "isFavorite", condition: .equals, value: "true")],
            sortBy: "title",
            sortAscending: true
        )
    }
    
    static func mostPlayedPlaylist(limit: Int = 25) -> SmartPlaylistCriteria {
        return SmartPlaylistCriteria(
            rules: [Rule(field: "playCount", condition: .greaterThan, value: "3")],
            limit: limit,
            sortBy: "playCount",
            sortAscending: false  // Descending to get most played first
        )
    }
    
    static func recentlyPlayedPlaylist(limit: Int = 25, daysBack: Int = 7) -> SmartPlaylistCriteria {
        // In the future, we'll calculate the date properly
        // For now, we'll just store the days back value
        return SmartPlaylistCriteria(
            rules: [Rule(field: "lastPlayedDate", condition: .greaterThan, value: "\(daysBack)days")],
            limit: limit,
            sortBy: "lastPlayedDate",
            sortAscending: false  // Most recent first
        )
    }
}

// Cache manager for playlist artwork
private class PlaylistArtworkCache {
    static let shared = PlaylistArtworkCache()
    private var cache: [UUID: (artwork: Data, trackIDs: [UUID])] = [:]
    
    func getCachedArtwork(for playlistID: UUID, currentTrackIDs: [UUID]) -> Data? {
        guard let cached = cache[playlistID] else { return nil }
        return cached.trackIDs == currentTrackIDs ? cached.artwork : nil
    }
    
    func setCachedArtwork(_ artwork: Data, for playlistID: UUID, trackIDs: [UUID]) {
        cache[playlistID] = (artwork, trackIDs)
    }
    
    func clearCache(for playlistID: UUID) {
        cache.removeValue(forKey: playlistID)
    }
}

struct Playlist: Identifiable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var dateCreated: Date
    var dateModified: Date
    var coverArtworkData: Data?
    let type: PlaylistType
    let smartType: SmartPlaylistType?
    var isUserEditable: Bool  // Can user delete/rename this playlist?
    var isContentEditable: Bool  // Can user add/remove tracks?
    var smartCriteria: SmartPlaylistCriteria?  // Criteria for smart playlists
    
    // Regular playlist initializer
    init(name: String, tracks: [Track] = [], coverArtworkData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.tracks = tracks
        self.dateCreated = Date()
        self.dateModified = Date()
        self.coverArtworkData = coverArtworkData
        self.type = .regular
        self.smartType = nil
        self.isUserEditable = true
        self.isContentEditable = true
        self.smartCriteria = nil
    }
    
    // Smart playlist initializer
    init(name: String, smartType: SmartPlaylistType, criteria: SmartPlaylistCriteria, isUserEditable: Bool = false) {
        self.id = UUID()
        self.name = name
        self.tracks = []
        self.dateCreated = Date()
        self.dateModified = Date()
        self.coverArtworkData = nil
        self.type = .smart
        self.smartType = smartType
        self.isUserEditable = isUserEditable
        self.isContentEditable = false  // Smart playlists auto-manage their content
        self.smartCriteria = criteria
    }
    
    // Database restoration initializer
    init(id: UUID, name: String, tracks: [Track], dateCreated: Date, dateModified: Date,
         coverArtworkData: Data?, type: PlaylistType, smartType: SmartPlaylistType?,
         isUserEditable: Bool, isContentEditable: Bool, smartCriteria: SmartPlaylistCriteria?) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.coverArtworkData = coverArtworkData
        self.type = type
        self.smartType = smartType
        self.isUserEditable = isUserEditable
        self.isContentEditable = isContentEditable
        self.smartCriteria = smartCriteria
    }
    
    // Add a track to the playlist (only for regular playlists)
    mutating func addTrack(_ track: Track) {
        guard type == .regular && isContentEditable else { return }
        
        if !tracks.contains(where: { $0.id == track.id }) {
            tracks.append(track)
            dateModified = Date()
            PlaylistArtworkCache.shared.clearCache(for: id) // Add this line
        }
    }
    
    // Remove a track from the playlist (only for regular playlists)
    mutating func removeTrack(_ track: Track) {
        guard type == .regular && isContentEditable else { return }
        
        // Remove by comparing database IDs instead of instance IDs
        if let trackId = track.trackId {
            tracks.removeAll(where: { $0.trackId == trackId })
        } else {
            // Fallback to UUID comparison if no database ID
            tracks.removeAll(where: { $0.id == track.id })
        }
        
        dateModified = Date()
        PlaylistArtworkCache.shared.clearCache(for: id)
    }
    
    // Move a track within the playlist (only for regular playlists)
    mutating func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard type == .regular && isContentEditable else { return }
        
        guard sourceIndex >= 0, sourceIndex < tracks.count,
              destinationIndex >= 0, destinationIndex < tracks.count,
              sourceIndex != destinationIndex else {
            return
        }
        
        let track = tracks.remove(at: sourceIndex)
        tracks.insert(track, at: destinationIndex)
        dateModified = Date()
        // Only clear cache if moving affects the first 4 tracks
        if sourceIndex < 4 || destinationIndex < 4 {
            PlaylistArtworkCache.shared.clearCache(for: id)
        }
    }
    
    // Clear all tracks from the playlist (only for regular playlists)
    mutating func clearTracks() {
        guard type == .regular && isContentEditable else { return }
        
        tracks.removeAll()
        dateModified = Date()
        PlaylistArtworkCache.shared.clearCache(for: id) // Add this line
    }
    
    // Calculate total duration of the playlist
    var totalDuration: Double {
        return tracks.reduce(0) { $0 + $1.duration }
    }

    // Get generated album art of the playlist
    var effectiveCoverArtwork: Data? {
        if let customCover = coverArtworkData {
            return customCover
        }
        
        // For playlists, check cache first
        let currentTrackIDs = tracks.prefix(4).map { $0.id }
        
        if let cachedArtwork = PlaylistArtworkCache.shared.getCachedArtwork(
            for: id,
            currentTrackIDs: currentTrackIDs
        ) {
            return cachedArtwork
        }
        
        // Generate new collage and cache it
        if let newCollage = createCollageArtwork() {
            PlaylistArtworkCache.shared.setCachedArtwork(
                newCollage,
                for: id,
                trackIDs: currentTrackIDs
            )
            return newCollage
        }
        
        return nil
    }
    
    // Get the effective track limit for display
    var trackLimit: Int? {
        return smartCriteria?.limit
    }

    private func createCollageArtwork() -> Data? {
        // Get up to 4 tracks that have artwork
        let tracksWithArtwork = tracks.filter { $0.artworkData != nil }
        guard !tracksWithArtwork.isEmpty else { return nil }
        
        // Randomly select up to 4 tracks
        let selectedTracks = tracksWithArtwork.shuffled().prefix(4)
        let artworkImages = selectedTracks.compactMap { track -> NSImage? in
            guard let data = track.artworkData else { return nil }
            return NSImage(data: data)
        }
        
        guard !artworkImages.isEmpty else { return nil }
        
        // Create a 2x2 collage
        let collageSize: CGFloat = 300 // Size of the final collage
        let tileSize = collageSize / 2
        
        let collageImage = NSImage(size: NSSize(width: collageSize, height: collageSize))
        collageImage.lockFocus()
        
        // Fill with a dark background in case we have fewer than 4 images
        NSColor.darkGray.setFill()
        NSRect(x: 0, y: 0, width: collageSize, height: collageSize).fill()
        
        // Draw up to 4 images in a 2x2 grid
        for (index, image) in artworkImages.prefix(4).enumerated() {
            let row = index / 2
            let col = index % 2
            let x = CGFloat(col) * tileSize
            let y = CGFloat(1 - row) * tileSize // Flip Y coordinate for NSImage
            
            let destRect = NSRect(x: x, y: y, width: tileSize, height: tileSize)
            
            // Draw the image scaled to fill the tile
            image.draw(in: destRect,
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy,
                      fraction: 1.0)
        }
        
        // If we have only 1 image, duplicate it to fill all 4 quadrants
        if artworkImages.count == 1, let image = artworkImages.first {
            for i in 1..<4 {
                let row = i / 2
                let col = i % 2
                let x = CGFloat(col) * tileSize
                let y = CGFloat(1 - row) * tileSize
                
                let destRect = NSRect(x: x, y: y, width: tileSize, height: tileSize)
                
                // Apply a slight tint/opacity variation to make it look intentional
                image.draw(in: destRect,
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .copy,
                          fraction: 0.7 + (CGFloat(i) * 0.1))
            }
        }
        
        collageImage.unlockFocus()
        
        // Convert to PNG data
        guard let tiffData = collageImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData
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

// Extension for creating default smart playlists
extension Playlist {
    static func createDefaultSmartPlaylists() -> [Playlist] {
        return [
            Playlist(
                name: "Favorite Songs",
                smartType: .favorites,
                criteria: SmartPlaylistCriteria.favoritesPlaylist(),
                isUserEditable: false
            ),
            Playlist(
                name: "Top 25 Most Played",
                smartType: .mostPlayed,
                criteria: SmartPlaylistCriteria.mostPlayedPlaylist(limit: 25),
                isUserEditable: false
            ),
            Playlist(
                name: "Top 25 Recently Played",
                smartType: .recentlyPlayed,
                criteria: SmartPlaylistCriteria.recentlyPlayedPlaylist(limit: 25, daysBack: 7),
                isUserEditable: false
            )
        ]
    }
}

// Extension for Equatable & Hashable Conformance
extension Playlist: Equatable, Hashable {
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        // Compare by ID since it's unique
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        // Hash by ID since it's unique
        hasher.combine(id)
    }
}
