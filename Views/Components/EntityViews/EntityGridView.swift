import SwiftUI

struct EntityGridView<T: Entity>: View {
    let entities: [T]
    let onSelectEntity: (T) -> Void
    let contextMenuItems: (T) -> [ContextMenuItem]
    
    @State private var gridWidth: CGFloat = 0
    
    private let itemWidth: CGFloat = 180
    private let itemHeight: CGFloat = 240
    private let spacing: CGFloat = 16
    
    private var columns: Int {
        max(1, Int((gridWidth + spacing) / (itemWidth + spacing)))
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columns)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: spacing) {
                    ForEach(Array(entities.enumerated()), id: \.element.id) { index, entity in
                        EntityGridItem(
                            entity: entity,
                            itemWidth: itemWidth,
                            onSelect: {
                                onSelectEntity(entity)
                            }
                        )
                        .frame(width: itemWidth, height: itemHeight)
                        .contextMenu {
                            ForEach(contextMenuItems(entity), id: \.id) { item in
                                contextMenuItem(item)
                            }
                        }
                        .id(entity.id)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color.clear)
            .onAppear {
                gridWidth = geometry.size.width - 32 // 16 padding on each side
            }
            .onChange(of: geometry.size.width) { newWidth in
                gridWidth = newWidth - 32 // 16 padding on each side
            }
        }
    }
    
    @ViewBuilder
    private func contextMenuItem(_ item: ContextMenuItem) -> some View {
        switch item {
        case .button(let title, let role, let action):
            Button(title, role: role, action: action)
        case .menu(let title, let items):
            Menu(title) {
                ForEach(items, id: \.id) { subItem in
                    if case .button(let subTitle, let subRole, let subAction) = subItem {
                        Button(subTitle, role: subRole, action: subAction)
                    }
                }
            }
        case .divider:
            Divider()
        }
    }
}

// MARK: - Entity Grid Item
private struct EntityGridItem<T: Entity>: View {
    let entity: T
    let itemWidth: CGFloat
    let onSelect: () -> Void
    
    @State private var isHovered = false
    @State private var artworkImage: NSImage?
    @State private var artworkLoadTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 8) {
            // Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: iconForEntity)
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text(entity.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .frame(width: 160, height: 160)
            
            // Text content
            VStack(spacing: 2) {
                Text(entity.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if let subtitle = entity.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadArtworkAsync()
        }
        .onDisappear {
            // Cancel loading task and clear image to free memory
            artworkLoadTask?.cancel()
            artworkLoadTask = nil
            artworkImage = nil
        }
    }
    
    private var iconForEntity: String {
        if entity is ArtistEntity {
            return "person.fill"
        } else if entity is AlbumEntity {
            return "opticaldisc.fill"
        }
        return "music.note"
    }
    
    private func loadArtworkAsync() {
        artworkLoadTask?.cancel()
        
        artworkLoadTask = Task {
            // Small delay to prioritize scrolling
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            guard !Task.isCancelled else { return }
            
            if let data = entity.artworkData,
               let image = NSImage(data: data) {
                // Resize image to appropriate size for grid
                let targetSize = NSSize(width: itemWidth * 2, height: itemWidth * 2) // 2x for retina
                let thumbnailImage = image.resized(to: targetSize)
                
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.artworkImage = thumbnailImage
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Artist Grid") {
    let artists = [
        ArtistEntity(name: "The Beatles", trackCount: 25),
        ArtistEntity(name: "Pink Floyd", trackCount: 18),
        ArtistEntity(name: "Led Zeppelin", trackCount: 22),
        ArtistEntity(name: "Queen", trackCount: 30)
    ]
    
    EntityGridView(
        entities: artists,
        onSelectEntity: { artist in
            print("Selected: \(artist.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 600)
}

#Preview("Album Grid") {
    let albums = [
        AlbumEntity(name: "Abbey Road", artist: "The Beatles", trackCount: 17),
        AlbumEntity(name: "The Dark Side of the Moon", artist: "Pink Floyd", trackCount: 10),
        AlbumEntity(name: "Led Zeppelin IV", artist: "Led Zeppelin", trackCount: 8),
        AlbumEntity(name: "A Night at the Opera", artist: "Queen", trackCount: 12)
    ]
    
    EntityGridView(
        entities: albums,
        onSelectEntity: { album in
            print("Selected: \(album.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 600)
}
