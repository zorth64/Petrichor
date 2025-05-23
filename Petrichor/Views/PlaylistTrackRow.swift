import SwiftUI

struct PlaylistTrackRow: View {
    @ObservedObject var track: Track
    let trackNumber: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator (for playlist-specific state)
            Group {
                if isCurrentTrack && isPlaying {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                } else if isCurrentTrack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                } else {
                    Text("\(trackNumber)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 24, alignment: .center)
            
            // Album art thumbnail
            Group {
                if let artworkData = track.artworkData,
                   let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else if track.isMetadataLoaded {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.4)
                        )
                }
            }
            
            // Track information
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14))
                    .fontWeight(isCurrentTrack ? .medium : .regular)
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(1)
                    .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                
                HStack {
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
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes entire row clickable
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    let sampleURL = URL(fileURLWithPath: "/path/to/sample.mp3")
    let sampleTrack = Track(url: sampleURL)
    sampleTrack.title = "Sample Song"
    sampleTrack.artist = "Sample Artist"
    sampleTrack.album = "Sample Album"
    sampleTrack.duration = 180.0
    sampleTrack.isMetadataLoaded = true
    
    return VStack {
        PlaylistTrackRow(
            track: sampleTrack,
            trackNumber: 1,
            isCurrentTrack: false,
            isPlaying: false,
            isSelected: false
        )
        
        PlaylistTrackRow(
            track: sampleTrack,
            trackNumber: 2,
            isCurrentTrack: true,
            isPlaying: true,
            isSelected: true
        )
        
        PlaylistTrackRow(
            track: sampleTrack,
            trackNumber: 3,
            isCurrentTrack: true,
            isPlaying: false,
            isSelected: false
        )
    }
    .padding()
}
