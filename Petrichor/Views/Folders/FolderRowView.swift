import SwiftUI

struct FolderRowView: View {
    let folder: Folder
    let trackCount: Int
    let onRemove: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Folder icon
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack {
                        Text(folder.url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(trackCount) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 8) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    
                    HStack {
                        Text("Full Path:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(folder.url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    HStack {
                        Text("Added:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Recently") // You could store this date if needed
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if trackCount > 0 {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    } else {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text("No tracks found")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sampleURL = URL(fileURLWithPath: "/Users/username/Music")
    let sampleFolder = Folder(url: sampleURL)
    
    return VStack {
        FolderRowView(
            folder: sampleFolder,
            trackCount: 42,
            onRemove: { print("Remove folder") }
        )
        
        FolderRowView(
            folder: sampleFolder,
            trackCount: 0,
            onRemove: { print("Remove folder") }
        )
    }
    .padding()
}
