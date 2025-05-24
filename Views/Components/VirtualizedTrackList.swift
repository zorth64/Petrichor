import SwiftUI

struct VirtualizedTrackList: View {
    let tracks: [Track]
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    VirtualizedTrackRow(
                        track: track,
                        isCurrentTrack: audioPlayerManager.currentTrack?.id == track.id,
                        isPlaying: audioPlayerManager.currentTrack?.id == track.id && audioPlayerManager.isPlaying,
                        isSelected: selectedTrackID == track.id,
                        onSelect: {
                            withAnimation(.none) {
                                selectedTrackID = track.id
                            }
                        },
                        onPlay: {
                            onPlayTrack(track)
                            selectedTrackID = track.id
                        },
                        contextMenuItems: {
                            contextMenuItems(track)
                        }
                    )
                    .frame(height: 60)
                    .id(track.id)
                }
            }
            .padding(.vertical, 1) // Small padding to prevent edge clipping
        }

    }
}

// Optimized track row that only loads what's needed
struct VirtualizedTrackRow: View {
    @ObservedObject var track: Track
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    let contextMenuItems: () -> [ContextMenuItem]
    
    @State private var isHovered = false
    @State private var artworkImage: NSImage?
    
    var body: some View {
        HStack(spacing: 0) {
            // Playing indicator
            HStack(spacing: 0) {
                if isPlaying {
                    PlayingIndicator()
                        .frame(width: 16)
                        .padding(.leading, 10)
                } else {
                    Spacer()
                        .frame(width: 20)
                }
            }
            .frame(width: 20)
            
            // Track content
            HStack(spacing: 12) {
                // Album art - lazy load
                Group {
                    if let artworkImage = artworkImage {
                        Image(nsImage: artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .task {
                    loadArtwork()
                }
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: isCurrentTrack ? .medium : .regular))
                        .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if !track.album.isEmpty && track.album != "Unknown Album" {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(track.album)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if !track.year.isEmpty && track.year != "Unknown Year" {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(track.year)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Duration
                Text(formatDuration(track.duration))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onPlay()
        }
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded { _ in
                    onSelect()
                }
        )
        .contextMenu {
            ForEach(contextMenuItems(), id: \.id) { item in
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
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.05)
        } else {
            return Color.clear
        }
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
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    VirtualizedTrackList(
        tracks: [],
        selectedTrackID: .constant(nil),
        onPlayTrack: { _ in },
        contextMenuItems: { _ in [] }
    )
    .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
}
