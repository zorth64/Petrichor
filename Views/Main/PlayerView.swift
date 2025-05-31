import SwiftUI
import Foundation

struct PlayerView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var showingQueue: Bool
    
    @State private var isDraggingProgress = false
    @State private var tempProgressValue: Double = 0
    @State private var currentTrackId: UUID? = nil
    @State private var cachedArtworkImage: NSImage? = nil
    @State private var hoveredOverProgress = false
    @State private var playButtonPressed = false
    @State private var isMuted = false
    @State private var previousVolume: Float = 0.7
    
    var body: some View {
        HStack(spacing: 20) {
            // Left section: Album art and track info
            leftSection
            
            Spacer()
            
            // Center section: Playback controls and progress
            centerSection
            
            Spacer()
            
            // Right section: Volume and queue controls
            rightSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - View Sections
    
    private var leftSection: some View {
        HStack(spacing: 16) {
            albumArtwork
            trackDetails
        }
        .frame(width: 240, alignment: .leading)
    }
    
    private var centerSection: some View {
        VStack(spacing: 8) {
            playbackControls
            progressBar
        }
        .frame(maxWidth: 500)
    }
    
    private var rightSection: some View {
        HStack(spacing: 12) {
            volumeControl
            queueButton
        }
        .frame(width: 240, alignment: .trailing)
    }
    
    // MARK: - Left Section Components
    
    private var albumArtwork: some View {
        let trackArtworkInfo = audioPlayerManager.currentTrack.map { track in
            TrackArtworkInfo(id: track.id, artworkData: track.artworkData)
        }
        
        return PlayerAlbumArtView(trackInfo: trackArtworkInfo, onTap: {
            if let currentTrack = audioPlayerManager.currentTrack {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowTrackInfo"),
                    object: nil,
                    userInfo: ["track": currentTrack]
                )
            }
        })
        .equatable()
    }
    
    private var trackDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row with favorite button
            HStack(alignment: .center, spacing: 8) {
                Text(audioPlayerManager.currentTrack?.title ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                favoriteButton
            }
            
            Text(audioPlayerManager.currentTrack?.artist ?? "")
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            Text(audioPlayerManager.currentTrack?.album ?? "")
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    private var favoriteButton: some View {
        Group {
            if let track = audioPlayerManager.currentTrack {
                Button(action: {
                    playlistManager.toggleFavorite(for: track)
                }) {
                    Image(systemName: track.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(track.isFavorite ? .yellow : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: track.isFavorite)
                }
                .buttonStyle(.plain)
                .help(track.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }
        }
    }
    
    // MARK: - Center Section Components
    
    private var playbackControls: some View {
        HStack(spacing: 12) {
            shuffleButton
            previousButton
            playPauseButton
            nextButton
            repeatButton
        }
    }
    
    private var shuffleButton: some View {
        Button(action: {
            playlistManager.toggleShuffle()
        }) {
            Image(systemName: "shuffle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(playlistManager.isShuffleEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(ControlButtonStyle())
        .disabled(audioPlayerManager.currentTrack == nil)
    }
    
    private var previousButton: some View {
        Button(action: {
            playlistManager.playPreviousTrack()
        }) {
            Image(systemName: "backward.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(ControlButtonStyle())
        .disabled(audioPlayerManager.currentTrack == nil)
    }
    
    private var playPauseButton: some View {
        Button(action: {
            audioPlayerManager.togglePlayPause()
        }) {
            Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(playButtonPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                playButtonPressed = pressing
            }
        }, perform: {})
        .disabled(audioPlayerManager.currentTrack == nil)
    }
    
    private var nextButton: some View {
        Button(action: {
            playlistManager.playNextTrack()
        }) {
            Image(systemName: "forward.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(ControlButtonStyle())
        .disabled(audioPlayerManager.currentTrack == nil)
    }
    
    private var repeatButton: some View {
        Button(action: {
            playlistManager.toggleRepeatMode()
        }) {
            Image(systemName: repeatImageName(for: playlistManager.repeatMode))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(playlistManager.repeatMode != .off ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(ControlButtonStyle())
        .disabled(audioPlayerManager.currentTrack == nil)
    }
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            // Current time
            Text(formatDuration(isDraggingProgress ? tempProgressValue : audioPlayerManager.currentTime))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
            
            // Progress slider
            progressSlider
            
            // Total duration
            Text(formatDuration(audioPlayerManager.currentTrack?.duration ?? 0))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
        }
    }
    
    private var progressSlider: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 4
                        )
                    
                    // Drag handle
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .opacity(isDraggingProgress || hoveredOverProgress ? 1.0 : 0.0)
                        .offset(x: (geometry.size.width * progressPercentage) - 6)
                        .animation(.easeInOut(duration: 0.15), value: hoveredOverProgress)
                        .animation(.easeInOut(duration: 0.15), value: isDraggingProgress)
                }
                .contentShape(Rectangle())
                .gesture(progressDragGesture(in: geometry))
                .onTapGesture { value in
                    handleProgressTap(at: value.x, in: geometry.size.width)
                }
                .onHover { hovering in
                    hoveredOverProgress = hovering
                }
            }
        }
        .frame(height: 10)
        .frame(maxWidth: 400)
    }
    
    // MARK: - Right Section Components
    
    private var volumeControl: some View {
        HStack(spacing: 8) {
            volumeButton
            volumeSlider
        }
    }
    
    private var volumeButton: some View {
        Button(action: toggleMute) {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isMuted ? "Unmute" : "Mute")
    }
    
    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { audioPlayerManager.volume },
                set: { newVolume in
                    audioPlayerManager.setVolume(newVolume)
                    // If user moves slider, unmute
                    if isMuted && newVolume > 0 {
                        isMuted = false
                    }
                }
            ),
            in: 0...1
        )
        .frame(width: 100)
        .controlSize(.small)
        .disabled(isMuted)
    }
    
    private var queueButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingQueue.toggle()
            }
        }) {
            Image(systemName: "list.bullet")
                .font(.system(size: 16))
                .foregroundColor(showingQueue ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(showingQueue ? Color.accentColor : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(showingQueue ? "Hide Queue" : "Show Queue")
    }
    
    // MARK: - Computed Properties
    
    private var progressPercentage: Double {
        guard let duration = audioPlayerManager.currentTrack?.duration, duration > 0 else { return 0 }
        let currentTime = isDraggingProgress ? tempProgressValue : audioPlayerManager.currentTime
        return min(1, max(0, currentTime / duration))
    }
    
    private var volumeIcon: String {
        if isMuted || audioPlayerManager.volume < 0.01 {
            return "speaker.slash.fill"
        } else if audioPlayerManager.volume < 0.33 {
            return "speaker.fill"
        } else if audioPlayerManager.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Initialize the cached album art
        if let artworkData = audioPlayerManager.currentTrack?.artworkData,
           let image = NSImage(data: artworkData) {
            cachedArtworkImage = image
            currentTrackId = audioPlayerManager.currentTrack?.id
        }

        if audioPlayerManager.volume < 0.01 {
            isMuted = true
            previousVolume = 0.7
        } else {
            previousVolume = audioPlayerManager.volume
        }
    }
    
    private func progressDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingProgress = true
                let percentage = max(0, min(1, value.location.x / geometry.size.width))
                tempProgressValue = percentage * (audioPlayerManager.currentTrack?.duration ?? 0)
            }
            .onEnded { value in
                let percentage = max(0, min(1, value.location.x / geometry.size.width))
                let newTime = percentage * (audioPlayerManager.currentTrack?.duration ?? 0)
                audioPlayerManager.seekTo(time: newTime)
                isDraggingProgress = false
            }
    }
    
    private func handleProgressTap(at x: CGFloat, in width: CGFloat) {
        let percentage = x / width
        let newTime = percentage * (audioPlayerManager.currentTrack?.duration ?? 0)
        audioPlayerManager.seekTo(time: newTime)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func repeatImageName(for mode: RepeatMode) -> String {
        switch mode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
    
    private func toggleMute() {
        if isMuted {
            // Unmute - restore previous volume
            audioPlayerManager.setVolume(previousVolume)
            isMuted = false
        } else {
            // Mute - save current volume and set to 0
            previousVolume = audioPlayerManager.volume
            audioPlayerManager.setVolume(0)
            isMuted = true
        }
    }
}

// Keep the existing supporting views and structs below...

// MARK: - Album Art

struct TrackArtworkInfo: Equatable {
    let id: UUID
    let artworkData: Data?
    
    static func == (lhs: TrackArtworkInfo, rhs: TrackArtworkInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct PlayerAlbumArtView: View, Equatable {
    let trackInfo: TrackArtworkInfo?
    let onTap: (() -> Void)?
    
    static func == (lhs: PlayerAlbumArtView, rhs: PlayerAlbumArtView) -> Bool {
        lhs.trackInfo == rhs.trackInfo
    }
    
    var body: some View {
        AlbumArtworkImage(trackInfo: trackInfo)
            .onTapGesture {
                onTap?()
            }
    }
}

private struct AlbumArtworkImage: View {
    let trackInfo: TrackArtworkInfo?
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Static image content
            AlbumArtworkContent(trackInfo: trackInfo)
        }
        .frame(width: 56, height: 56)
        .shadow(
            color: .black.opacity(isHovered ? 0.4 : 0.2),
            radius: isHovered ? 6 : 2,
            x: 0,
            y: isHovered ? 3 : 1
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct AlbumArtworkContent: View {
    let trackInfo: TrackArtworkInfo?
    
    var body: some View {
        if let artworkData = trackInfo?.artworkData,
           let nsImage = NSImage(data: artworkData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: - Custom Button Style

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showingQueue = false
        
        var body: some View {
            PlayerView(showingQueue: $showingQueue)
                .environmentObject({
                    let coordinator = AppCoordinator()
                    return coordinator.audioPlayerManager
                }())
                .environmentObject({
                    let coordinator = AppCoordinator()
                    return coordinator.playlistManager
                }())
                .frame(height: 200)
        }
    }
    
    return PreviewWrapper()
}
