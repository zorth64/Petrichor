import SwiftUI
import CryptoKit

// MARK: - UUID Extension for Name-based UUIDs
extension UUID {
    init(name: String, namespace: UUID) {
        var nameData = name.data(using: .utf8)!
        var namespaceBytes = [UInt8]()
        
        // Convert namespace UUID to bytes
        let nsUUID = namespace.uuid
        namespaceBytes = [nsUUID.0, nsUUID.1, nsUUID.2, nsUUID.3,
                         nsUUID.4, nsUUID.5, nsUUID.6, nsUUID.7,
                         nsUUID.8, nsUUID.9, nsUUID.10, nsUUID.11,
                         nsUUID.12, nsUUID.13, nsUUID.14, nsUUID.15]
        
        nameData.insert(contentsOf: namespaceBytes, at: 0)
        
        // Create SHA-1 hash
        let hash = Insecure.SHA1.hash(data: nameData)
        let hashBytes = Array(hash)
        
        // Set version (5) and variant bits
        var uuid = hashBytes[0..<16]
        uuid[6] = (uuid[6] & 0x0F) | 0x50  // Version 5
        uuid[8] = (uuid[8] & 0x3F) | 0x80  // Variant 10
        
        self = UUID(uuid: (uuid[0], uuid[1], uuid[2], uuid[3],
                          uuid[4], uuid[5], uuid[6], uuid[7],
                          uuid[8], uuid[9], uuid[10], uuid[11],
                          uuid[12], uuid[13], uuid[14], uuid[15]))
    }
}

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
    let tracks: [Track]     // Associated tracks
    
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

// MARK: - Entity View
struct EntityView<T: Entity>: View {
    let entities: [T]
    let viewType: LibraryViewType
    let onSelectEntity: (T) -> Void
    let contextMenuItems: (T) -> [ContextMenuItem]
    
    var body: some View {
        switch viewType {
        case .list:
            EntityListView(
                entities: entities,
                onSelectEntity: onSelectEntity,
                contextMenuItems: contextMenuItems
            )
        case .grid:
            EntityGridView(
                entities: entities,
                onSelectEntity: onSelectEntity,
                contextMenuItems: contextMenuItems
            )
        case .table:
            // Table view doesn't make sense for artists/albums
            // Fall back to list view
            EntityListView(
                entities: entities,
                onSelectEntity: onSelectEntity,
                contextMenuItems: contextMenuItems
            )
        }
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resized(to size: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        bitmapRep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        let resizedImage = NSImage(size: size)
        resizedImage.addRepresentation(bitmapRep)
        return resizedImage
    }
}

// MARK: - Preview
#Preview("Artist List") {
    let sampleTracks = (0..<10).map { i in
        let track = Track(url: URL(fileURLWithPath: "/path/to/sample\(i).mp3"))
        track.title = "Sample Song \(i)"
        track.artist = "Artist \(i % 3)"
        track.album = "Album \(i % 2)"
        track.isMetadataLoaded = true
        return track
    }
    
    let artists = [
        ArtistEntity(name: "Artist 0", tracks: Array(sampleTracks[0..<4])),
        ArtistEntity(name: "Artist 1", tracks: Array(sampleTracks[4..<7])),
        ArtistEntity(name: "Artist 2", tracks: Array(sampleTracks[7..<10]))
    ]
    
    EntityView(
        entities: artists,
        viewType: .list,
        onSelectEntity: { artist in
            print("Selected: \(artist.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 400)
}

#Preview("Album Grid") {
    let sampleTracks = (0..<12).map { i in
        let track = Track(url: URL(fileURLWithPath: "/path/to/sample\(i).mp3"))
        track.title = "Sample Song \(i)"
        track.artist = "Artist \(i % 3)"
        track.album = "Album \(i % 4)"
        track.isMetadataLoaded = true
        return track
    }
    
    let albums = [
        AlbumEntity(name: "Album 0", artist: "Artist 0", tracks: Array(sampleTracks[0..<3])),
        AlbumEntity(name: "Album 1", artist: "Artist 1", tracks: Array(sampleTracks[3..<6])),
        AlbumEntity(name: "Album 2", artist: "Artist 2", tracks: Array(sampleTracks[6..<9])),
        AlbumEntity(name: "Album 3", artist: "Artist 0", tracks: Array(sampleTracks[9..<12]))
    ]
    
    EntityView(
        entities: albums,
        viewType: .grid,
        onSelectEntity: { album in
            print("Selected: \(album.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 600)
}
