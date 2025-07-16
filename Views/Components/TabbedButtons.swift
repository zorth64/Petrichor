import SwiftUI

// MARK: - Animation Type
enum TabbedButtonAnimation {
    case fade
    case transform
}

// MARK: - Animation Constants
private struct AnimationConstants {
    static let transformDuration: Double = 0.2
    static let transformTextDelay: Double = 0.1
    static let fadeDuration: Double = 0.15
    static let hoverDuration: Double = 0.1
}

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
    let animation: TabbedButtonAnimation
    let isDisabled: Bool
    let disableTableView: Bool

    init(
        items: [Item],
        selection: Binding<Item>,
        style: TabbedButtonStyle = .standard,
        animation: TabbedButtonAnimation = .fade,
        isDisabled: Bool = false,
        disableTableView: Bool = false
    ) {
        self.items = items
        self._selection = selection
        self.style = style
        self.animation = animation
        self.isDisabled = isDisabled
        self.disableTableView = disableTableView
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                TabbedButton(
                    item: item,
                    isSelected: selection == item,
                    style: style,
                    animation: animation,
                    isDisabled: self.disableTableView && item as! LibraryViewType == LibraryViewType.table ?
                                true : isDisabled
                ) {
                    if !isDisabled {
                        withAnimation(.easeInOut(duration: AnimationConstants.transformDuration)) {
                            selection = item
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                // Container background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                // Moving background for transform animation
                if animation == .transform {
                    movingBackground
                }
            }
        )
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    @ViewBuilder
    private var movingBackground: some View {
        if let selectedIndex = items.firstIndex(of: selection) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width - 8 // Account for padding
                let buttonWidth = totalWidth / CGFloat(items.count)
                let xOffset = CGFloat(selectedIndex) * buttonWidth + 4 // Account for padding

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                    .frame(
                        width: buttonWidth - 1, // Account for spacing
                        height: geometry.size.height - 8 // Account for padding
                    )
                    .position(
                        x: xOffset + (buttonWidth - 1) / 2,
                        y: geometry.size.height / 2
                    )
                    .animation(.easeInOut(duration: AnimationConstants.transformDuration), value: selectedIndex)
            }
        }
    }
}

// MARK: - Individual Tab Button
private struct TabbedButton<Item: TabbedItem>: View {
    let item: Item
    let isSelected: Bool
    let style: TabbedButtonStyle
    let animation: TabbedButtonAnimation
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            HStack(spacing: style.iconTextSpacing) {
                if style.showIcon {
                    iconImage(for: isSelected ? item.selectedIcon : item.icon)
                        .font(.system(size: style.iconSize, weight: .medium))
                        .foregroundStyle(foregroundStyle)
                        .animation(
                            .easeInOut(duration: isDisabled ? 0 : AnimationConstants.transformDuration)
                                .delay(animation == .transform && isSelected
                                    ? AnimationConstants.transformTextDelay
                                    : 0),
                            value: isSelected && !isDisabled
                        )
                }

                if style.showTitle {
                    Text(item.title)
                        .font(.system(size: style.textSize, weight: .medium))
                        .foregroundColor(foregroundColor)
                        .animation(
                            .easeInOut(duration: AnimationConstants.transformDuration)
                                .delay(animation == .transform && isSelected
                                    ? AnimationConstants.transformTextDelay
                                    : 0),
                            value: isSelected
                        )
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
        .disabled(isDisabled)
        .onHover { hovering in
            if !isDisabled {
                isHovered = hovering
            }
        }
        .if(item.tooltip != nil) { view in
            view.help(item.tooltip!)
        }
    }

    @ViewBuilder
    private func iconImage(for iconName: String) -> some View {
        if iconName.hasPrefix("custom.") {
            Image(iconName)
        } else {
            Image(systemName: iconName)
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        if animation == .transform {
            // For transform animation, delay white text until background is in position
            if isSelected {
                return AnyShapeStyle(Color.white)
            } else if isHovered {
                return AnyShapeStyle(Color.primary)
            } else {
                return AnyShapeStyle(Color.secondary)
            }
        } else {
            // Original fade animation behavior
            if isSelected {
                return AnyShapeStyle(Color.white)
            } else if isHovered {
                return AnyShapeStyle(Color.primary)
            } else {
                return AnyShapeStyle(Color.secondary)
            }
        }
    }

    private var foregroundColor: Color {
        if animation == .transform {
            // For transform animation, delay white text until background is in position
            if isSelected {
                return .white
            } else if isHovered {
                return .primary
            } else {
                return .secondary
            }
        } else {
            // Original fade animation behavior
            if isSelected {
                return .white
            } else if isHovered {
                return .primary
            } else {
                return .secondary
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if animation == .fade {
            // Original fade animation
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.accentColor :
                        isHovered ? Color.primary.opacity(0.06) :
                        Color.clear
                )
                .animation(.easeOut(duration: isDisabled ? 0 : AnimationConstants.fadeDuration),
                           value: isSelected && !isDisabled)
                .animation(.easeOut(duration: AnimationConstants.hoverDuration), value: isHovered)
        } else {
            // Transform animation - no individual background, uses moving background
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovered && !isSelected ? Color.primary.opacity(0.06) : Color.clear
                )
                .animation(.easeOut(duration: AnimationConstants.hoverDuration), value: isHovered)
        }
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
        (self.iconSize == 14 && !self.showTitle && self.verticalPadding == 0) ? 24 : nil
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

extension Sections: TabbedItem {
    var title: String { self.label }
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
