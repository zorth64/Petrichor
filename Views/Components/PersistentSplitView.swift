import SwiftUI

struct PersistentSplitView<Left: View, Right: View>: View {
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right
    @AppStorage("sidebarSplitPosition") private var splitPosition: Double = 200
    @State private var localSplitPosition: CGFloat = 200
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                left()
                    .frame(width: localSplitPosition)
                
                Divider()
                    .frame(width: 1)
                    .background(Color(NSColor.separatorColor))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = localSplitPosition + value.translation.width
                                localSplitPosition = min(max(150, newWidth), 500)
                            }
                            .onEnded { _ in
                                splitPosition = Double(localSplitPosition)
                            }
                    )
                
                right()
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            localSplitPosition = CGFloat(splitPosition)
        }
        .onChange(of: splitPosition) { newValue in
            localSplitPosition = CGFloat(newValue)
        }
    }
}
