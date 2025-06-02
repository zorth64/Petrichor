import SwiftUI

struct NoMusicEmptyStateView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var isScanning = false
    @State private var scanProgress: Double = 0.0
    @State private var scanStatusMessage = ""
    
    // Customization options
    let context: EmptyStateContext
    
    enum EmptyStateContext {
        case mainWindow
        case settings
        
        var iconSize: CGFloat {
            switch self {
            case .mainWindow: return 80
            case .settings: return 60
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .mainWindow: return 24
            case .settings: return 20
            }
        }
        
        var titleFont: Font {
            switch self {
            case .mainWindow: return .largeTitle
            case .settings: return .title2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: context.spacing) {
            if isScanning {
                // Scanning progress view
                scanningProgressContent
            } else {
                // Empty state content
                emptyStateContent
            }
        }
        .frame(maxWidth: context == .mainWindow ? .infinity : 500)
        .frame(maxHeight: context == .mainWindow ? .infinity : 400)
        .padding(context == .mainWindow ? 60 : 40)
        .onReceive(libraryManager.$isScanning) { scanning in
            withAnimation(.easeInOut(duration: 0.3)) {
                isScanning = scanning
            }
        }
        .onReceive(libraryManager.$scanProgress) { progress in
            scanProgress = progress
        }
        .onReceive(libraryManager.$scanStatusMessage) { message in
            scanStatusMessage = message
        }
    }
    
    // MARK: - Empty State Content
    
    private var emptyStateContent: some View {
        VStack(spacing: context.spacing) {
            // Icon with subtle animation
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: context.iconSize * 1.8, height: context.iconSize * 1.8)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: context.iconSize, weight: .light))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))
            }
            
            VStack(spacing: 12) {
                Text("No Music Added Yet")
                    .font(context.titleFont)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Text("Add folders containing your music to get started")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("You can select multiple folders at once")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .multilineTextAlignment(.center)
            }
            
            // Add button with hover effect
            Button(action: { libraryManager.addFolder() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add Music Folder")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    // Hover effect handled by button style
                }
            }
            
            // Supported formats
            VStack(spacing: 4) {
                Text("Supported formats")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("MP3, M4A, WAV, AAC, AIFF, FLAC")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .fontDesign(.monospaced)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Scanning Progress Content
    
    private var scanningProgressContent: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: scanProgress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: scanProgress)
                
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 8) {
                Text("Scanning Music Library")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if !scanStatusMessage.isEmpty {
                    Text(scanStatusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                }
                
                // Progress percentage
                Text("\(Int(scanProgress * 100))%")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .monospacedDigit()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * scanProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: scanProgress)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 300)
            
            // Track count
            if libraryManager.tracks.count > 0 {
                HStack(spacing: 16) {
                    Label("\(libraryManager.tracks.count) tracks found", systemImage: "music.note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if libraryManager.folders.count > 0 {
                        Label("\(libraryManager.folders.count) folders", systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("This may take a few minutes for large libraries")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .italic()
        }
    }
}

// MARK: - Preview

#Preview("Main Window") {
    NoMusicEmptyStateView(context: .mainWindow)
        .environmentObject(LibraryManager())
        .frame(width: 800, height: 600)
}

#Preview("Settings") {
    NoMusicEmptyStateView(context: .settings)
        .environmentObject(LibraryManager())
        .frame(width: 600, height: 500)
}

#Preview("Scanning") {
    NoMusicEmptyStateView(context: .mainWindow)
        .environmentObject({
            let manager = LibraryManager()
            manager.isScanning = true
            manager.scanProgress = 0.65
            manager.scanStatusMessage = "Processing My Music Collection..."
            return manager
        }())
        .frame(width: 800, height: 600)
}
