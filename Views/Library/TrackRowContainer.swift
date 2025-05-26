import SwiftUI
import Foundation

struct TrackRowContainer: View {
    let track: Track
    let trackNumber: Int?
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    let contextMenuItems: () -> [ContextMenuItem]
    
    @State private var clickCount = 0
    @State private var clickTimer: Timer?
    
    init(
        track: Track,
        trackNumber: Int? = nil,
        isCurrentTrack: Bool = false,
        isPlaying: Bool = false,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        contextMenuItems: @escaping () -> [ContextMenuItem] = { [] }
    ) {
        self.track = track
        self.trackNumber = trackNumber
        self.isCurrentTrack = isCurrentTrack
        self.isPlaying = isPlaying
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onPlay = onPlay
        self.contextMenuItems = contextMenuItems
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Playing indicator
            if isPlaying {
                PlayingIndicator()
                    .frame(width: 16)
            } else {
                // Empty space to maintain alignment
                Spacer()
                    .frame(width: 20)
            }
            
            // Track content
            Group {
                if let trackNumber = trackNumber {
                    PlaylistTrackRow(
                        track: track,
                        trackNumber: trackNumber,
                        isCurrentTrack: isCurrentTrack,
                        isPlaying: isPlaying,
                        isSelected: isSelected
                    )
                } else {
                    TrackRow(track: track)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleClick()
        }
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
    
    private func handleClick() {
        clickCount += 1
        
        if clickCount == 1 {
            // Set up timer for single click
            clickTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                if clickCount == 1 {
                    // Single click - select
                    onSelect()
                }
                resetClickState()
            }
        } else if clickCount == 2 {
            // Double click - play and cancel single click timer
            clickTimer?.invalidate()
            onPlay()
            resetClickState()
        }
    }
    
    private func resetClickState() {
        clickCount = 0
        clickTimer?.invalidate()
        clickTimer = nil
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
        TrackRowContainer(
            track: sampleTrack,
            isSelected: false,
            onSelect: { print("Selected") },
            onPlay: { print("Play") }
        )
        
        TrackRowContainer(
            track: sampleTrack,
            isPlaying: false,
            isSelected: false,
            onSelect: { print("Selected") },
            onPlay: { print("Play") }
        )
        
        TrackRowContainer(
            track: sampleTrack,
            trackNumber: 1,
            isCurrentTrack: true,
            isPlaying: true,
            isSelected: true,
            onSelect: { print("Selected") },
            onPlay: { print("Play") }
        )
    }
    .padding()
}
