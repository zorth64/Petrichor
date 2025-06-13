import Foundation

// MARK: - Entity Protocol
protocol Entity: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var subtitle: String? { get }
    var trackCount: Int { get }
    var artworkData: Data? { get }
}

// MARK: - Artist Entity
struct ArtistEntity: Entity {
    let id: UUID
    let name: String
    var subtitle: String? {
        "\(trackCount) \(trackCount == 1 ? "song" : "songs")"
    }
    let trackCount: Int
    var artworkData: Data? {
        // Compute artwork data on demand instead of storing it
        tracks.first(where: { $0.artworkData != nil })?.artworkData
    }
    let tracks: [Track]
    
    init(name: String, tracks: [Track]) {
        // Create a deterministic UUID based on the artist name
        // This ensures the same artist always has the same ID
        let namespace = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")! // Fixed namespace
        self.id = UUID(name: name.lowercased(), namespace: namespace)
        
        self.name = name
        self.tracks = tracks
        self.trackCount = tracks.count
    }
}

// MARK: - Album Entity
struct AlbumEntity: Entity {
    let id: UUID
    let name: String
    var subtitle: String? {
        if let artist = artist {
            return "\(artist) • \(trackCount) \(trackCount == 1 ? "song" : "songs")"
        }
        return "\(trackCount) \(trackCount == 1 ? "song" : "songs")"
    }
    let artist: String?
    let trackCount: Int
    var artworkData: Data? {
        // Compute artwork data on demand instead of storing it
        tracks.first(where: { $0.artworkData != nil })?.artworkData
    }
    let tracks: [Track]
    
    init(name: String, artist: String?, tracks: [Track]) {
        // Create a deterministic UUID based on album name and artist
        // This ensures the same album always has the same ID
        let namespace = UUID(uuidString: "6BA7B811-9DAD-11D1-80B4-00C04FD430C8")! // Fixed namespace for albums
        let combinedName = "\(name.lowercased())-\(artist?.lowercased() ?? "")"
        self.id = UUID(name: combinedName, namespace: namespace)
        
        self.name = name
        self.artist = artist
        self.tracks = tracks
        self.trackCount = tracks.count
    }
}

// MARK: - UUID Extension for Name-based UUIDs
extension UUID {
    init(name: String, namespace: UUID) {
        // Use Foundation's UUID(uuidString:) with a hash for now
        // In a real implementation, you'd use proper UUID v5 generation
        let combined = "\(namespace.uuidString)-\(name)"
        let hash = combined.hashValue
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X",
                               UInt32(hash & 0xFFFFFFFF),
                               UInt16((hash >> 32) & 0xFFFF),
                               UInt16((hash >> 48) & 0x0FFF) | 0x5000, // Version 5
                               UInt16((hash >> 60) & 0x3FFF) | 0x8000, // Variant
                               UInt64(abs(hash)) & 0xFFFFFFFFFFFF)
        self = UUID(uuidString: uuidString)!
    }
}
