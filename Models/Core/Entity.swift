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
    let tracks: [Track]
    let trackCount: Int
    let artworkData: Data?

    var subtitle: String? {
        "\(trackCount) \(trackCount == 1 ? "song" : "songs")"
    }

    // Original initializer
    init(name: String, tracks: [Track]) {
        let namespace = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!
        self.id = UUID(name: name.lowercased(), namespace: namespace)
        self.name = name
        self.tracks = tracks
        self.trackCount = tracks.count
        self.artworkData = tracks.first { $0.artworkData != nil }?.artworkData
    }

    // New lightweight initializer
    init(name: String, trackCount: Int, artworkData: Data? = nil) {
        let namespace = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!
        self.id = UUID(name: name.lowercased(), namespace: namespace)
        self.name = name
        self.tracks = []
        self.trackCount = trackCount
        self.artworkData = artworkData
    }
}

// MARK: - Album Entity
struct AlbumEntity: Entity {
    let id: UUID
    let name: String
    let artist: String?
    let tracks: [Track]
    let trackCount: Int
    let artworkData: Data?
    let albumId: Int64?

    var subtitle: String? {
        if let artist = artist {
            return "\(artist) • \(trackCount) \(trackCount == 1 ? "song" : "songs")"
        }
        return "\(trackCount) \(trackCount == 1 ? "song" : "songs")"
    }

    init(name: String, artist: String?, tracks: [Track]) {
        let namespace = UUID(uuidString: "6BA7B811-9DAD-11D1-80B4-00C04FD430C8")!
        let combinedName = "\(name.lowercased())-\(artist?.lowercased() ?? "")"
        self.id = UUID(name: combinedName, namespace: namespace)
        self.name = name
        self.artist = artist
        self.tracks = tracks
        self.trackCount = tracks.count
        self.artworkData = tracks.first { $0.artworkData != nil }?.artworkData
        self.albumId = nil
    }

    init(name: String, artist: String?, trackCount: Int, artworkData: Data? = nil, albumId: Int64? = nil) {
        // If we have an albumId, use it for a truly unique ID
        if let albumId = albumId {
            // Create a deterministic UUID from the album ID
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", albumId)
            self.id = UUID(uuidString: uuidString) ?? UUID()
        } else {
            // Fallback to name-based UUID
            let namespace = UUID(uuidString: "6BA7B811-9DAD-11D1-80B4-00C04FD430C8")!
            let combinedName = "\(name.lowercased())-\(artist?.lowercased() ?? "")"
            self.id = UUID(name: combinedName, namespace: namespace)
        }

        self.name = name
        self.artist = artist
        self.tracks = []
        self.trackCount = trackCount
        self.artworkData = artworkData
        self.albumId = albumId
    }
}

// MARK: - UUID Extension for Name-based UUIDs
extension UUID {
    init(name: String, namespace: UUID) {
        // Use Foundation's UUID(uuidString:) with a hash for now
        // In a real implementation, you'd use proper UUID v5 generation
        let combined = "\(namespace.uuidString)-\(name)"
        let hash = combined.hashValue
        let uuidString = String(
            format: "%08X-%04X-%04X-%04X-%012X",
            UInt32(hash & 0xFFFFFFFF),
            UInt16((hash >> 32) & 0xFFFF),
            UInt16((hash >> 48) & 0x0FFF) | 0x5000,
            UInt16((hash >> 60) & 0x3FFF) | 0x8000,
            UInt64(abs(hash)) & 0xFFFFFFFFFFFF
        )
        self = UUID(uuidString: uuidString)!
    }
}
