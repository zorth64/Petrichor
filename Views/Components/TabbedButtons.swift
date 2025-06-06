import SwiftUI

// MARK: - Generic Tab Protocol
protocol TabbedItem: Hashable {
    var title: String { get }
    var icon: String { get }
    var selectedIcon: String { get }
    var tooltip: String? { get }
}

// MARK: - Default implementation for selectedIcon
extension TabbedItem {
    var selectedIcon: String { icon }
    var tooltip: String? { nil }
}

// MARK: - Reusable Tabbed Buttons Component
struct TabbedButtons<Item: TabbedItem>: View {
    let items: [Item]
    @Binding var selection: Item
    let style: TabbedButtonStyle
    
    init(
        items: [Item],
        selection: Binding<Item>,
        style: TabbedButtonStyle = .standard
    ) {
        self.items = items
        self._selection = selection
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(items, id: \.self) { item in
                TabbedButton(
                    item: item,
                    isSelected: selection == item,
                    style: style,
                    action: { selection = item }
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Individual Tab Button
private struct TabbedButton<Item: TabbedItem>: View {
    let item: Item
    let isSelected: Bool
    let style: TabbedButtonStyle
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            HStack(spacing: style.iconTextSpacing) {
                if style.showIcon {
                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(.system(size: style.iconSize, weight: .medium))
                        .foregroundStyle(foregroundStyle)
                }
                
                if style.showTitle {
                    Text(item.title)
                        .font(.system(size: style.textSize, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(
                minWidth: style.buttonWidth,
                maxWidth: style.expandButtons ? .infinity : style.buttonWidth,
                minHeight: style.buttonHeight,
                maxHeight: style.buttonHeight
            )
            .padding(.vertical, style.buttonHeight == nil ? style.verticalPadding : 0)
            .background(backgroundView)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .if(item.tooltip != nil) { view in
            view.help(item.tooltip!)
        }
    }
    
    private var foregroundStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.white)
        } else if isHovered {
            return AnyShapeStyle(Color.primary)
        } else {
            return AnyShapeStyle(Color.secondary)
        }
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                isSelected ? Color.accentColor :
                isHovered ? Color.primary.opacity(0.06) :
                Color.clear
            )
            .animation(.easeOut(duration: 0.15), value: isSelected)
            .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Styling Options
struct TabbedButtonStyle {
    let showIcon: Bool
    let showTitle: Bool
    let iconSize: CGFloat
    let textSize: CGFloat
    let iconTextSpacing: CGFloat
    let buttonWidth: CGFloat?
    let verticalPadding: CGFloat
    let expandButtons: Bool

    var buttonHeight: CGFloat? {
        return (self.iconSize == 14 && !self.showTitle && self.verticalPadding == 0) ? 24 : nil
    }
    
    static let standard = TabbedButtonStyle(
        showIcon: true,
        showTitle: true,
        iconSize: 13,
        textSize: 12,
        iconTextSpacing: 5,
        buttonWidth: 90,
        verticalPadding: 5,
        expandButtons: false
    )

    static let compact = TabbedButtonStyle(
        showIcon: true,
        showTitle: true,
        iconSize: 12,
        textSize: 11,
        iconTextSpacing: 4,
        buttonWidth: 85,
        verticalPadding: 5,
        expandButtons: false
    )

    static let iconOnly = TabbedButtonStyle(
        showIcon: true,
        showTitle: false,
        iconSize: 14,
        textSize: 12,
        iconTextSpacing: 0,
        buttonWidth: 32,
        verticalPadding: 5,
        expandButtons: false
    )

    static let flexible = TabbedButtonStyle(
        showIcon: true,
        showTitle: true,
        iconSize: 12,
        textSize: 11,
        iconTextSpacing: 4,
        buttonWidth: nil,
        verticalPadding: 4,
        expandButtons: true
    )

    static let viewToggle = TabbedButtonStyle(
        showIcon: true,
        showTitle: false,
        iconSize: 14,
        textSize: 12,
        iconTextSpacing: 0,
        buttonWidth: 32,
        verticalPadding: 0,
        expandButtons: false
    )
}

// MARK: - Convenience Extensions for Existing Types

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension MainTab: TabbedItem {
    var title: String { self.rawValue }
}

extension LibraryViewType: TabbedItem {
    var title: String { "" }
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .table: return "tablecells"
        }
    }

    var tooltip: String? {
        switch self {
        case .list: return "List View"
        case .grid: return "Grid View"
        case .table: return "Table View"
        }
    }
}

extension SettingsView.SettingsTab: TabbedItem {
    var title: String { self.rawValue }
}
