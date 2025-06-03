import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    
    private var shouldAnimate: Bool {
        textSize.width > containerWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Hidden text to measure size
                Text(text)
                    .font(font)
                    .foregroundColor(.clear)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    textSize = textGeometry.size
                                    containerWidth = geometry.size.width
                                }
                        }
                    )
                
                // Visible content
                if shouldAnimate {
                    MarqueeAnimatedText(
                        text: text,
                        font: font,
                        color: color,
                        textWidth: textSize.width,
                        containerWidth: containerWidth
                    )
                } else {
                    // Static text when it fits
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .lineLimit(1)
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .clipped()
        }
    }
}

private struct MarqueeAnimatedText: View {
    let text: String
    let font: Font
    let color: Color
    let textWidth: CGFloat
    let containerWidth: CGFloat
    
    @State private var offset: CGFloat = 0
    
    private var animationDuration: Double {
        let baseSpeed = 20.0
        let distance = textWidth + 20
        return distance / baseSpeed
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize()
            
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize()
        }
        .offset(x: offset)
        .onAppear {
            startScrolling()
        }
    }
    
    private func startScrolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            withAnimation(.linear(duration: 0)) {
                let totalDistance = textWidth + 20
                let currentTime = Date().timeIntervalSinceReferenceDate
                let phase = (currentTime.truncatingRemainder(dividingBy: animationDuration * 2)) / animationDuration
                
                if phase <= 1.0 {
                    // Forward direction
                    offset = -totalDistance * phase
                } else {
                    // Backward direction
                    offset = -totalDistance * (2.0 - phase)
                }
            }
        }
    }
}
