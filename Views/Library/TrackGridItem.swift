import SwiftUI

struct TrackGridItem: View {
    @ObservedObject var track: Track
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Album art with play overlay
            ZStack {
                // Album artwork
                Group {
                    if let artworkData = track.artworkData,
                       let nsImage = NSImage(data: artworkData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if track.isMetadataLoaded {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
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
                    .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                
                if track.isMetadataLoaded && !track.album.isEmpty && track.album != "Unknown Album" {
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
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    let sampleURL = URL(fileURLWithPath: "/path/to/sample.mp3")
    let sampleTrack = Track(url: sampleURL)
    sampleTrack.title = "Sample Long Song Title That Might Wrap"
    sampleTrack.artist = "Sample Artist"
    sampleTrack.album = "Sample Album"
    sampleTrack.duration = 180.0
    sampleTrack.isMetadataLoaded = true
    
    return HStack {
        TrackGridItem(
            track: sampleTrack,
            isCurrentTrack: false,
            isPlaying: false,
            isSelected: false,
            onSelect: { print("Selected") },
            onPlay: { print("Play") }
        )
        
        TrackGridItem(
            track: sampleTrack,
            isCurrentTrack: true,
            isPlaying: true,
            isSelected: true,
            onSelect: { print("Selected") },
            onPlay: { print("Play") }
        )
    }
    .padding()
}
