import SwiftUI

struct PlayingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: isAnimating ? 8 : 3)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 16, height: 12)
        .onAppear {
            isAnimating = true
        }
    }
}
