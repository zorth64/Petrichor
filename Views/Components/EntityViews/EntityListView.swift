import SwiftUI

struct EntityListView<T: Entity>: View {
    let entities: [T]
    let onSelectEntity: (T) -> Void
    let contextMenuItems: (T) -> [ContextMenuItem]

    @State private var hoveredEntityID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(entities) { entity in
                    EntityListRow(
                        entity: entity,
                        isHovered: hoveredEntityID == entity.id,
                        onSelect: {
                            onSelectEntity(entity)
                        },
                        onHover: { isHovered in
                            hoveredEntityID = isHovered ? entity.id : nil
                        }
                    )
                    .contextMenu {
                        ForEach(contextMenuItems(entity), id: \.id) { item in
                            contextMenuItem(item)
                        }
                    }
                    .id(entity.id)
                }
            }
            .padding(5)
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

// MARK: - Entity List Row
private struct EntityListRow<T: Entity>: View {
    let entity: T
    let isHovered: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void

    @State private var artworkImage: NSImage?
    @State private var artworkLoadTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 48, height: 48)

                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Image(systemName: iconForEntity)
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = entity.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Chevron on hover
            if isHovered {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover(perform: onHover)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color.clear)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
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
                // Resize image to thumbnail size to save memory
                let thumbnailImage = image.resized(to: NSSize(width: 96, height: 96))

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.artworkImage = thumbnailImage
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Artist List") {
    let artists = [
        ArtistEntity(name: "Radiohead", trackCount: 15),
        ArtistEntity(name: "Arcade Fire", trackCount: 12),
        ArtistEntity(name: "The National", trackCount: 20)
    ]

    EntityListView(
        entities: artists,
        onSelectEntity: { artist in
            print("Selected: \(artist.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 400)
}

#Preview("Album List") {
    let albums = [
        AlbumEntity(name: "OK Computer", artist: "Radiohead", trackCount: 12),
        AlbumEntity(name: "The Suburbs", artist: "Arcade Fire", trackCount: 16),
        AlbumEntity(name: "Sleep Well Beast", artist: "The National", trackCount: 12),
        AlbumEntity(name: "In Rainbows", artist: "Radiohead", trackCount: 10)
    ]

    EntityListView(
        entities: albums,
        onSelectEntity: { album in
            print("Selected: \(album.name)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 400)
}
