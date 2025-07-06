import SwiftUI

struct ScanningAnimation: View {
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0

    // Customizable properties
    let size: CGFloat
    let lineWidth: CGFloat

    init(size: CGFloat = 80, lineWidth: CGFloat = 4) {
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Animated arc
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.5)
                        ]),
                        startPoint: .leading,
                        
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        rotationAngle = 360
                    }
                }

            // Center icon with pulsing effect
            Image(systemName: Icons.musicNote)
                .font(.system(size: size * 0.4, weight: .light))
                .foregroundColor(.accentColor)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .opacity(isAnimating ? 1.0 : 0.7)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        isAnimating = true
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Default Size") {
    ScanningAnimation()
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Small Size") {
    ScanningAnimation(size: 40, lineWidth: 3)
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Large Size") {
    ScanningAnimation(size: 120, lineWidth: 6)
        .padding()
        .background(Color.gray.opacity(0.1))
}
