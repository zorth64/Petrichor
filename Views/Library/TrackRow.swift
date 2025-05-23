import SwiftUI

struct TrackRow: View {
    @ObservedObject var track: Track
    
    var body: some View {
        HStack {
            // Album art thumbnail with loading state
            Group {
                if let artworkData = track.artworkData,
                   let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else if track.isMetadataLoaded {
                    // Show placeholder when metadata is loaded but no artwork
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    // Show loading indicator when metadata is still loading
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Track information
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .fontWeight(.medium)
                    .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                
                HStack {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(track.album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
                    
                    // Show year if available and not "Unknown Year"
                    if track.isMetadataLoaded && !track.year.isEmpty && track.year != "Unknown Year" {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(track.year)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .redacted(reason: track.isMetadataLoaded ? [] : .placeholder)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // This makes the entire row clickable
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
    sampleTrack.year = "2025"
    sampleTrack.duration = 180.0
    sampleTrack.isMetadataLoaded = true
    
    return VStack {
        TrackRow(track: sampleTrack)
        TrackRow(track: sampleTrack)
    }
    .padding()
}
