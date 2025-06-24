import SwiftUI

struct PlayingIndicator: View {
    var body: some View {
        Image(systemName: "speaker.wave.3.fill")
            .font(.system(size: 12))
            .foregroundColor(.accentColor)
            .frame(width: 16, height: 12)
    }
}

#Preview {
    PlayingIndicator()
        .padding()
        .background(Color.gray.opacity(0.1))
}
