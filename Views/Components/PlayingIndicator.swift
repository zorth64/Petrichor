import SwiftUI

struct PlayingIndicator: View {
    @State private var animationPhases: [CGFloat] = [0, 0, 0]
    // Update 60 times per second for smooth animation
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.none) // Disable implicit animations for smoother manual control
            }
        }
        .frame(width: 16, height: 12)
        .clipped()
        .onReceive(timer) { _ in
            updateAnimation()
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let phase = animationPhases[index]
        // Smoother sine wave calculation
        let height = 6 + (6 * sin(phase))
        return max(2, height) // Ensure minimum height of 2
    }

    private func updateAnimation() {
        // Slower, smoother animation with different speeds for each bar
        animationPhases[0] += 0.08
        animationPhases[1] += 0.10
        animationPhases[2] += 0.12
    }
}

#Preview {
    PlayingIndicator()
        .padding()
        .background(Color.gray.opacity(0.1))
}
