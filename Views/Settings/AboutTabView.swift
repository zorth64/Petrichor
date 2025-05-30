import SwiftUI

struct AboutTabView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                // App Icon and Info
                VStack(spacing: 16) {
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
                
                // Library Statistics
                if !libraryManager.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Library Statistics")
                            .font(.headline)
                        
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("\(libraryManager.folders.count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Folders")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(libraryManager.tracks.count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(libraryManager.getDistinctValues(for: .artists).count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Artists")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                
                // Footer Info
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
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .scrollDisabled(libraryManager.tracks.isEmpty)
        .background(Color.clear)
    }
}

#Preview {
    AboutTabView()
        .environmentObject(LibraryManager())
        .frame(width: 600, height: 500)
}
