//
//  PlayerView.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-04-19.
//


import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var audioPlayerManager: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    
    var body: some View {
        VStack(spacing: 10) {
            // Track info
            HStack {
                // Album art
                if let artworkData = audioPlayerManager.currentTrack?.artworkData,
                   let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .frame(width: 100, height: 100)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading) {
                    Text(audioPlayerManager.currentTrack?.title ?? "No Track Selected")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(audioPlayerManager.currentTrack?.artist ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(audioPlayerManager.currentTrack?.album ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous
                Button(action: {
                    playlistManager.playPreviousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Play/Pause
                Button(action: {
                    audioPlayerManager.togglePlayPause()
                }) {
                    Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Next
                Button(action: {
                    playlistManager.playNextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .disabled(audioPlayerManager.currentTrack == nil)
                
                // Volume
                Slider(value: $audioPlayerManager.volume, in: 0...1)
                    .frame(width: 100)
                
                // Repeat
                Button(action: {
                    playlistManager.toggleRepeatMode()
                }) {
                    Image(systemName: repeatImageName(for: playlistManager.repeatMode))
                }
                
                // Shuffle
                Button(action: {
                    playlistManager.toggleShuffle()
                }) {
                    Image(systemName: "shuffle")
                        .foregroundColor(playlistManager.isShuffleEnabled ? .accentColor : .primary)
                }
            }
            .padding(.horizontal)
            
            // Progress bar
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { audioPlayerManager.currentTime },
                        set: { audioPlayerManager.seekTo(time: $0) }
                    ),
                    in: 0...(audioPlayerManager.currentTrack?.duration ?? 0)
                )
                .disabled(audioPlayerManager.currentTrack == nil)
                
                HStack {
                    Text(formatDuration(audioPlayerManager.currentTime))
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(formatDuration(audioPlayerManager.currentTrack?.duration ?? 0))
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.secondary.opacity(0.1))
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func repeatImageName(for mode: PlaylistManager.RepeatMode) -> String {
        switch mode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}