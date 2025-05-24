import SwiftUI

struct VirtualizedTrackGrid: View {
    let tracks: [Track]
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    @State private var gridWidth: CGFloat = 0
    
    // Grid configuration
    private let itemWidth: CGFloat = 180
    private let itemHeight: CGFloat = 240
    private let spacing: CGFloat = 16
    
    private var columns: Int {
        max(1, Int((gridWidth + spacing) / (itemWidth + spacing)))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(tracks) { track in
                        VirtualizedTrackGridItem(
                            track: track,
                            isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                            isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                            isSelected: selectedTrackID == track.id,
                            onSelect: {
                                selectedTrackID = track.id
                            },
                            onPlay: {
                                onPlayTrack(track)
                                selectedTrackID = track.id
                            }
                        )
                        .frame(width: itemWidth, height: itemHeight)
                        .contextMenu {
                            ForEach(contextMenuItems(track), id: \.id) { item in
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
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .onAppear {
                gridWidth = geometry.size.width - 32 // Account for padding
            }
            .onChange(of: geometry.size.width) { newWidth in
                gridWidth = newWidth - 32
            }
        }
    }
}

struct VirtualizedTrackGridItem: View {
    @ObservedObject var track: Track
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    
    @State private var isHovered = false
    @State private var artworkImage: NSImage?
    
    var body: some View {
        VStack(spacing: 8) {
            // Album art with play overlay
            // Album art with play overlay
            // Album art with play overlay
            // Album art with play overlay
            ZStack {
                // Album artwork
                Group {
                    if let artworkImage = artworkImage {
                        Image(nsImage: artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .task {
                    loadArtwork()
                }
                
                // Play overlay
                if isHovered || isCurrentTrack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Button(action: onPlay) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                    )
                            }
                                .buttonStyle(.borderless)
                        )
                        .opacity(isHovered || isCurrentTrack ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                        .animation(.easeInOut(duration: 0.2), value: isCurrentTrack)
                }
                
                // Playing indicator in corner
                if isCurrentTrack && isPlaying {
                    VStack {
                        HStack {
                            Spacer()
                            PlayingIndicator()
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        }
                        Spacer()
                    }
                    .frame(width: 160, height: 160)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 14, weight: isCurrentTrack ? .medium : .regular))
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !track.album.isEmpty && track.album != "Unknown Album" {
                    Text(track.album)
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
                .fill(backgroundColor)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            withAnimation(.none) {
                onSelect()
            }
        }
    }
    
    private var backgroundColor: Color {
        isSelected ? Color.accentColor.opacity(0.1) : Color.clear
    }
    
    private func loadArtwork() {
        guard artworkImage == nil else { return }
        
        Task {
            if let artworkData = track.artworkData,
               let image = NSImage(data: artworkData) {
                await MainActor.run {
                    self.artworkImage = image
                }
            }
        }
    }
}
