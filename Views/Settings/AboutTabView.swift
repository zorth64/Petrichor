import SwiftUI

struct AboutTabView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                appInfoSection
                
                if !libraryManager.tracks.isEmpty {
                    libraryStatisticsSection
                }
                
                footerSection
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .scrollDisabled(libraryManager.tracks.isEmpty)
        .background(Color.clear)
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        VStack(spacing: 16) {
            appIcon
            appDetails
        }
    }
    
    private var appIcon: some View {
        Group {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var appDetails: some View {
        VStack(spacing: 8) {
            Text("Petrichor Music Player")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("A beautiful music player for macOS")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Library Statistics Section

    private var libraryStatisticsSection: some View {
        VStack(spacing: 12) {
            Text("Library Statistics")
                .font(.headline)
            
            statisticsRow
        }
    }

    private var statisticsRow: some View {
        HStack(spacing: 30) {
            statisticItem(
                value: "\(libraryManager.folders.count)",
                label: "Folders"
            )
            
            statisticItem(
                value: "\(libraryManager.tracks.count)",
                label: "Tracks"
            )
            
            statisticItem(
                value: "\(libraryManager.getDistinctValues(for: .artists).count)",
                label: "Artists"
            )
            
            statisticItem(
                value: "\(libraryManager.getDistinctValues(for: .albums).count)",
                label: "Albums"
            )
            
            statisticItem(
                value: formatTotalDuration(),
                label: "Duration"
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }

    private func statisticItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Built with Swift and SwiftUI")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Named after the pleasant smell of earth after rain")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTotalDuration() -> String {
        let totalSeconds = libraryManager.tracks.reduce(0) { $0 + $1.duration }
        let totalHours = Int(totalSeconds) / 3600
        let days = totalHours / 24
        let remainingHours = totalHours % 24
        
        if days > 0 {
            return "\(days)d \(remainingHours)h"
        } else if totalHours > 0 {
            return "\(totalHours)h"
        } else {
            let minutes = Int(totalSeconds) / 60
            return "\(minutes)m"
        }
    }
}

#Preview {
    AboutTabView()
        .environmentObject(LibraryManager())
        .frame(width: 600, height: 500)
}
