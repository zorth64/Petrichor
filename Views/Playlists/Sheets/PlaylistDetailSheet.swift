import SwiftUI

struct PlaylistDetailSheet: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(playlist.name)
                .font(.title)

            Text("\(playlist.tracks.count) songs")
                .foregroundColor(.secondary)

            Button("Close") {
                dismiss()
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    let samplePlaylist = Playlist(name: "Sample Playlist", tracks: [])
    return PlaylistDetailSheet(playlist: samplePlaylist)
}
