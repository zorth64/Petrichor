import SwiftUI

struct BackgroundScanningIndicator: View {
    @State private var isAnimating = false
    @EnvironmentObject var libraryManager: LibraryManager
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 24, height: 24)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Music note icon
            Image(systemName: "music.note")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.accentColor)
        }
        .onAppear {
            isAnimating = true
        }
        .help(scanningTooltip)
    }
    
    private var scanningTooltip: String {
        if !libraryManager.scanStatusMessage.isEmpty {
            return libraryManager.scanStatusMessage
        } else {
            return "Scanning for new music..."
        }
    }
}

#Preview {
    BackgroundScanningIndicator()
        .environmentObject({
            let manager = LibraryManager()
            manager.isBackgroundScanning = true
            return manager
        }())
        .padding()
        .background(Color.gray.opacity(0.1))
}
