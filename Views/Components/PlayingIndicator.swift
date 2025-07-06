import SwiftUI

struct PlayingIndicator: View {
    var body: some View {
        Image(systemName: Icons.speakerWave3Fill)
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
