import SwiftUI
import UniformTypeIdentifiers

struct PlayQueueView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var draggedTrack: Track?
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            queueHeader
            
            Divider()
                .frame(height: 1)
                .overlay(Color(NSColor.controlColor).opacity(0.2))
            
            // Queue list
            if playlistManager.currentQueue.isEmpty {
                emptyQueueView
            } else {
                Spacer(minLength: 5)
                queueListView
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Clear Queue", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                playlistManager.clearQueue()
            }
        } message: {
            Text("Are you sure you want to clear the entire queue? This will stop playback.")
        }
    }
    
    // MARK: - Queue Header
        
    private var queueHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Play Queue")
                    .font(.headline)
            }
            .padding(.leading, 15)
            .padding(.vertical, 8)
            
            Spacer()
            
            HStack(spacing: 12) {
                Text("\(playlistManager.currentQueue.count) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Clear queue button
                if !playlistManager.currentQueue.isEmpty {
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Queue")
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 5)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty Queue View
    
    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Queue is Empty")
                .font(.headline)
            
            Text("Play a song to start building your queue")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Queue List View
    
    private var queueListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(playlistManager.currentQueue.enumerated()), id: \.element.id) { index, track in
                    PlayQueueRow(
                        track: track,
                        position: index,
                        isCurrentTrack: index == playlistManager.currentQueueIndex,
                        isPlaying: index == playlistManager.currentQueueIndex && audioPlayerManager.isPlaying,
                        playlistManager: playlistManager,
                        onRemove: {
                            playlistManager.removeFromQueue(at: index)
                        }
                    )
                    .id(track.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onDrag {
                        self.draggedTrack = track
                        return NSItemProvider(object: track.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: QueueDropDelegate(
                        track: track,
                        tracks: playlistManager.currentQueue,
                        draggedTrack: $draggedTrack,
                        playlistManager: playlistManager
                    ))
                }
            }
            .padding(.horizontal, -8)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: playlistManager.currentQueueIndex) { newIndex in
                // Auto-scroll to current track
                if newIndex >= 0 && newIndex < playlistManager.currentQueue.count {
                    withAnimation {
                        proxy.scrollTo(playlistManager.currentQueue[newIndex].id, anchor: .center)
                    }
                }
            }
            .onAppear {
                // Scroll to current track on appear
                if playlistManager.currentQueueIndex >= 0 &&
                   playlistManager.currentQueueIndex < playlistManager.currentQueue.count {
                    proxy.scrollTo(playlistManager.currentQueue[playlistManager.currentQueueIndex].id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Queue Row Component

struct PlayQueueRow: View {
    let track: Track
    let position: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let playlistManager: PlaylistManager
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Position or playing indicator
            ZStack {
                if isCurrentTrack && isPlaying {
                    PlayingIndicator()
                        .frame(width: 20)
                } else if isCurrentTrack {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                } else {
                    Text("\(position + 1)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 20)
                }
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 13, weight: isCurrentTrack ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                
                Text(track.artist)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Duration and remove button
            HStack(spacing: 5) {
                Text(formatDuration(track.duration))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                if isHovered && !isCurrentTrack {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            // Double-click to play
            if !isCurrentTrack {
                playlistManager.playFromQueue(at: position)
            }
        }
    }
    
    private var backgroundColor: Color {
        if isCurrentTrack {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Drag and Drop Delegate

struct QueueDropDelegate: DropDelegate {
    let track: Track
    let tracks: [Track]
    @Binding var draggedTrack: Track?
    let playlistManager: PlaylistManager
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedTrack = self.draggedTrack else { return }
        
        if draggedTrack.id != track.id {
            let from = tracks.firstIndex(where: { $0.id == draggedTrack.id }) ?? 0
            let to = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
            
            withAnimation(.default) {
                playlistManager.moveInQueue(from: from, to: to)
            }
        }
    }
}

#Preview {
    PlayQueueView()
        .environmentObject({
            let coordinator = AppCoordinator()
            // Add some sample tracks to the queue for preview
            let sampleTrack1 = Track(url: URL(fileURLWithPath: "/sample1.mp3"))
            sampleTrack1.title = "Sample Song 1"
            sampleTrack1.artist = "Sample Artist"
            sampleTrack1.duration = 180
            
            let sampleTrack2 = Track(url: URL(fileURLWithPath: "/sample2.mp3"))
            sampleTrack2.title = "Sample Song 2"
            sampleTrack2.artist = "Another Artist"
            sampleTrack2.duration = 240
            
            coordinator.playlistManager.currentQueue = [sampleTrack1, sampleTrack2]
            coordinator.playlistManager.currentQueueIndex = 0
            
            return coordinator.playlistManager
        }())
        .environmentObject({
            let coordinator = AppCoordinator()
            return coordinator.audioPlayerManager
        }())
        .frame(width: 350, height: 600)
}
