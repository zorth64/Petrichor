import SwiftUI

struct IconOnlyDropdown<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let iconProvider: (Item) -> String
    let tooltipProvider: (Item) -> String
    
    @State private var isHovered = false
    
    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(action: {
                    selection = item
                }) {
                    HStack {
                        Image(systemName: iconProvider(item))
                            .frame(width: 16)
                        Text(tooltipProvider(item))
                    }
                }
            }
        } label: {
            Image(systemName: iconProvider(selection))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .overlay(
            Color.clear
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
                .allowsHitTesting(false)
        )
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(tooltipProvider(selection))
    }
}
