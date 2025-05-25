import SwiftUI
import Foundation

struct PlayerView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var isDraggingProgress = false
    @State private var tempProgressValue: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Track info section
            HStack(spacing: 16) {
                // Album art with proper clipping
                ZStack {
                    if let artworkData = audioPlayerManager.currentTrack?.artworkData,
                       let nsImage = NSImage(data: artworkData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                // Track details
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioPlayerManager.currentTrack?.title ?? "")
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(audioPlayerManager.currentTrack?.artist ?? "")
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Text(audioPlayerManager.currentTrack?.album ?? "")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Volume control
                HStack(spacing: 8) {
                    Image(systemName: audioPlayerManager.volume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { audioPlayerManager.volume },
                            set: { audioPlayerManager.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 80)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 10)
            
            // Progress bar section
            VStack(spacing: 5) {
                // Custom progress bar with fixed height to prevent jumping
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
                            
                            // Drag handle - always present but only visible on hover or drag
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                                .opacity(isDraggingProgress || hoveredOverProgress ? 1.0 : 0.0)
                                .offset(x: (geometry.size.width * progressPercentage) - 6)
                                .animation(.easeInOut(duration: 0.15), value: hoveredOverProgress)
                                .animation(.easeInOut(duration: 0.15), value: isDraggingProgress)
                        }
                        .contentShape(Rectangle())
                        .gesture(
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
                        )
                        .onTapGesture { value in
                            let percentage = value.x / geometry.size.width
                            let newTime = percentage * (audioPlayerManager.currentTrack?.duration ?? 0)
                            audioPlayerManager.seekTo(time: newTime)
                        }
                        .onHover { hovering in
                            hoveredOverProgress = hovering
                        }
                    }
                }
                .frame(height: 10) // Fixed height to prevent jumping
                
                // Time labels
                HStack {
                    Text(formatDuration(isDraggingProgress ? tempProgressValue : audioPlayerManager.currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatDuration(audioPlayerManager.currentTrack?.duration ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 20)

            // Control buttons section
            HStack(spacing: 15) {
                // Shuffle button
                Button(action: {
                    playlistManager.toggleShuffle()
                }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(playlistManager.isShuffleEnabled ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ControlButtonStyle())
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Previous track button
                Button(action: {
                    playlistManager.playPreviousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ControlButtonStyle())
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Play/Pause button (larger and prominent)
                Button(action: {
                    audioPlayerManager.togglePlayPause()
                }) {
                    Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
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
                
                // Next track button
                Button(action: {
                    playlistManager.playNextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ControlButtonStyle())
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Repeat button
                Button(action: {
                    playlistManager.toggleRepeatMode()
                }) {
                    Image(systemName: repeatImageName(for: playlistManager.repeatMode))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(playlistManager.repeatMode != .off ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ControlButtonStyle())
                .disabled(audioPlayerManager.currentTrack == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4) // Extra bottom padding to ensure buttons aren't clipped
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity) // Ensure it doesn't exceed window bounds
    }
    
    // MARK: - State Variables
    @State private var hoveredOverProgress = false
    @State private var playButtonPressed = false
    
    // MARK: - Computed Properties
    
    private var progressPercentage: Double {
        guard let duration = audioPlayerManager.currentTrack?.duration, duration > 0 else { return 0 }
        let currentTime = isDraggingProgress ? tempProgressValue : audioPlayerManager.currentTime
        return min(1, max(0, currentTime / duration))
    }
    
    // MARK: - Helper Methods
    
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
    PlayerView()
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
