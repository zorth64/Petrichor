import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animationDirection: Bool = true
    
    private var shouldAnimate: Bool {
        textSize.width > containerWidth
    }
    
    private var animationDuration: Double {
        // Adjust speed based on text length
        let baseSpeed = 20.0 // pixels per second
        let distance = textSize.width + 20 // extra space between repeats
        return distance / baseSpeed
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
                
                // Visible scrolling text
                if shouldAnimate {
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
                        startAnimation()
                    }
                    .onDisappear {
                        offset = 0
                    }
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
    
    private func startAnimation() {
        guard shouldAnimate else { return }
        
        // Reset to start position
        offset = 0
        
        // Animate back and forth
        withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
            offset = -(textSize.width + 20)
        }
    }
}
