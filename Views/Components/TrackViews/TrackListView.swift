import SwiftUI

struct TrackListView: View {
    let tracks: [Track]
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @State private var hoveredTrackID: UUID?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackListRow(
                        track: track,
                        isSelected: selectedTrackID == track.id,
                        isHovered: hoveredTrackID == track.id,
                        onSelect: {
                            withAnimation(.none) {
                                selectedTrackID = track.id
                            }
                        },
                        onPlay: {
                            // Only play if it's not already the current track playing
                            let isCurrentTrack = audioPlayerManager.currentTrack?.url.path == track.url.path
                            if !isCurrentTrack {
                                onPlayTrack(track)
                                selectedTrackID = track.id
                            }
                        },
                        onHover: { isHovered in
                            hoveredTrackID = isHovered ? track.id : nil
                        }
                    )
                    .contextMenu {
                        TrackContextMenuContent(items: contextMenuItems(track))
                    }
                    .id(track.id)
                }
            }
            .padding(5)
        }
    }
}

// MARK: - Track List Row
private struct TrackListRow: View {
    @ObservedObject var track: Track
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @State private var lastClickTime = Date()
    @State private var artworkImage: NSImage?
    
    private var isCurrentTrack: Bool {
        guard let currentTrack = audioPlayerManager.currentTrack else { return false }
        return currentTrack.url.path == track.url.path
    }
    
    private var isPlaying: Bool {
        isCurrentTrack && audioPlayerManager.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Playing indicator on the left
            HStack(spacing: 0) {
                if isPlaying {
                    PlayingIndicator()
                        .frame(width: 16)
                        .padding(.leading, 10)
                        .padding(.trailing, 6)
                } else {
                    Spacer()
                        .frame(width: 32)
                }
            }
            
            // Main content
            HStack(spacing: 12) {
                // Album art thumbnail
                Group {
                    if let artworkImage = artworkImage {
                        Image(nsImage: artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else if track.isMetadataLoaded {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            )
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .task {
                    loadArtwork()
                }
                .onDisappear {
                    artworkImage = nil
                }
                
                // Track information
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: isCurrentTrack ? .medium : .regular))
                        .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                        .lineLimit(1)
                        .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                    
                    HStack(spacing: 4) {
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                        
                        if !track.album.isEmpty && track.album != "Unknown Album" {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(track.album)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                        }
                        
                        if track.isMetadataLoaded && !track.year.isEmpty && track.year != "Unknown Year" {
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
                    .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .onTapGesture(count: 1) {
            let now = Date()
            let timeSinceLastClick = now.timeIntervalSince(lastClickTime)
            
            if timeSinceLastClick < 0.3 {
                // Double click detected
                onPlay()
            } else {
                // Single click - just select
                onSelect()
            }
            
            lastClickTime = now
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.25)
        } else if isHovered {
            return Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
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
