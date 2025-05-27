import SwiftUI

// MARK: - Track View
struct TrackView: View {
    let tracks: [Track]
    let viewType: LibraryViewType
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    
    var body: some View {
        switch viewType {
        case .list:
            TrackListView(
                tracks: tracks,
                selectedTrackID: $selectedTrackID,
                onPlayTrack: onPlayTrack,
                contextMenuItems: contextMenuItems
            )
        case .grid:
            TrackGridView(
                tracks: tracks,
                selectedTrackID: $selectedTrackID,
                onPlayTrack: onPlayTrack,
                contextMenuItems: contextMenuItems
            )
        }
    }
}

// MARK: - List View Implementation
private struct TrackListView: View {
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
                        ForEach(contextMenuItems(track), id: \.id) { item in
                            contextMenuItem(item)
                        }
                    }
                    .id(track.id)
                }
            }
            .padding(5) // Small padding to prevent edge clipping
        }
    }
    
    @ViewBuilder
    private func contextMenuItem(_ item: ContextMenuItem) -> some View {
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
                        .frame(width: 32) // 16 + 10 + 6 = 32 total for alignment
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

// MARK: - Grid View Implementation
private struct TrackGridView: View {
    let tracks: [Track]
    @Binding var selectedTrackID: UUID?
    let onPlayTrack: (Track) -> Void
    let contextMenuItems: (Track) -> [ContextMenuItem]
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @State private var gridWidth: CGFloat = 0
    
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
                        TrackGridItem(
                            track: track,
                            isSelected: selectedTrackID == track.id,
                            onSelect: {
                                withAnimation(.none) {
                                    selectedTrackID = track.id
                                }
                            },
                            onPlay: {
                                // Only play if it's not already the current track
                                let isCurrentTrack = audioPlayerManager.currentTrack?.url.path == track.url.path
                                if !isCurrentTrack {
                                    onPlayTrack(track)
                                    selectedTrackID = track.id
                                }
                            }
                        )
                        .frame(width: itemWidth, height: itemHeight)
                        .contextMenu {
                            ForEach(contextMenuItems(track), id: \.id) { item in
                                contextMenuItem(item)
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
    
    @ViewBuilder
    private func contextMenuItem(_ item: ContextMenuItem) -> some View {
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

// MARK: - Track Grid Item
private struct TrackGridItem: View {
    @ObservedObject var track: Track
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @State private var isHovered = false
    @State private var artworkImage: NSImage?
    
    private var isCurrentTrack: Bool {
        guard let currentTrack = audioPlayerManager.currentTrack else { return false }
        return currentTrack.url.path == track.url.path
    }
    
    private var isPlaying: Bool {
        isCurrentTrack && audioPlayerManager.isPlaying
    }
    
    var body: some View {
        VStack(spacing: 8) {
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

// MARK: - Preview
#Preview("List View") {
    let sampleTracks = (0..<5).map { i in
        let track = Track(url: URL(fileURLWithPath: "/path/to/sample\(i).mp3"))
        track.title = "Sample Song \(i)"
        track.artist = "Sample Artist"
        track.album = "Sample Album"
        track.duration = 180.0
        track.isMetadataLoaded = true
        return track
    }
    
    @State var selectedTrackID: UUID? = nil
    
    return TrackView(
        tracks: sampleTracks,
        viewType: .list,
        selectedTrackID: $selectedTrackID,
        onPlayTrack: { track in
            print("Playing \(track.title)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 400)
    .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
}

#Preview("Grid View") {
    let sampleTracks = (0..<6).map { i in
        let track = Track(url: URL(fileURLWithPath: "/path/to/sample\(i).mp3"))
        track.title = "Sample Song \(i)"
        track.artist = "Sample Artist"
        track.album = "Sample Album"
        track.duration = 180.0
        track.isMetadataLoaded = true
        return track
    }
    
    @State var selectedTrackID: UUID? = nil
    
    return TrackView(
        tracks: sampleTracks,
        viewType: .grid,
        selectedTrackID: $selectedTrackID,
        onPlayTrack: { track in
            print("Playing \(track.title)")
        },
        contextMenuItems: { _ in [] }
    )
    .frame(height: 600)
    .environmentObject(AudioPlayerManager(libraryManager: LibraryManager(), playlistManager: PlaylistManager()))
}
