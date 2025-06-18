import SwiftUI

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
    let artists = [
        ArtistEntity(name: "Artist 0", trackCount: 4),
        ArtistEntity(name: "Artist 1", trackCount: 7),
        ArtistEntity(name: "Artist 2", trackCount: 3)
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
    let albums = [
        AlbumEntity(name: "Album 0", artist: "Artist 0", trackCount: 3),
        AlbumEntity(name: "Album 1", artist: "Artist 1", trackCount: 6),
        AlbumEntity(name: "Album 2", artist: "Artist 2", trackCount: 9),
        AlbumEntity(name: "Album 3", artist: "Artist 0", trackCount: 12)
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
