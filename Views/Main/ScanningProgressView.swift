import SwiftUI

struct ScanningProgressView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .symbolEffect(.pulse)
            
            // Title
            Text("Scanning Music Library")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Status message
            if !libraryManager.scanStatusMessage.isEmpty {
                Text(libraryManager.scanStatusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            
            // Progress bar
            ProgressView(value: libraryManager.scanProgress) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(libraryManager.scanProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .progressViewStyle(.linear)
            .frame(width: 300)
            
            // Additional info
            VStack(spacing: 8) {
                if libraryManager.tracks.count > 0 {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(libraryManager.tracks.count) tracks found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if libraryManager.folders.count > 0 {
                    HStack {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(libraryManager.folders.count) folders added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Tips
            Text("This may take a few minutes for large music libraries")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 350)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(radius: 10)
        )
    }
}

// Overlay modifier for showing scanning progress
struct ScanningOverlay: ViewModifier {
    @EnvironmentObject var libraryManager: LibraryManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: libraryManager.isScanning ? 3 : 0)
                .disabled(libraryManager.isScanning)
                .animation(.easeInOut(duration: 0.3), value: libraryManager.isScanning)
            
            if libraryManager.isScanning {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ScanningProgressView()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: libraryManager.isScanning)
    }
}

extension View {
    func scanningOverlay() -> some View {
        modifier(ScanningOverlay())
    }
}

#Preview {
    ScanningProgressView()
        .environmentObject({
            let manager = LibraryManager()
            manager.isScanning = true
            manager.scanProgress = 0.65
            manager.scanStatusMessage = "Scanning My Music Collection..."
            return manager
        }())
}
