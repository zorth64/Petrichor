//
//  PlaylistCard.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-05-22.
//


import SwiftUI

struct PlaylistCard: View {
    let playlist: Playlist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Playlist artwork
                Group {
                    if let artworkData = playlist.effectiveCoverArtwork,
                       let nsImage = NSImage(data: artworkData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.secondary.opacity(0.1))
                    }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Playlist info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text("\(playlist.tracks.count) songs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.borderless)
        .background(Color.clear)
    }
}

#Preview {
    let samplePlaylist = Playlist(name: "My Playlist", tracks: [])
    
    return PlaylistCard(playlist: samplePlaylist) {
        print("Playlist tapped")
    }
    .frame(width: 200)
    .padding()
}