import SwiftUI

// MARK: - Sidebar Item Row

struct SidebarItemRow<Item: SidebarItem>: View {
    let item: Item
    let isSelected: Bool
    let isHovered: Bool
    let isEditing: Bool
    @Binding var editingText: String
    @FocusState var isEditingFieldFocused: Bool
    let showIcon: Bool
    let iconColor: Color
    let showCount: Bool
    let trailingContent: ((Item) -> AnyView)?
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let onStartEditing: () -> Void
    let onCommitEditing: () -> Void
    let onCancelEditing: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            if showIcon, let icon = item.icon {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : iconColor)
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
            }

            // Content
            if isEditing {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .focused($isEditingFieldFocused)
                    .onSubmit {
                        onCommitEditing()
                    }
                    .onExitCommand {
                        onCancelEditing()
                    }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Trailing content (pin icon, etc.)
            if let trailing = trailingContent?(item) {
                trailing
            } else if showCount, let count = item.count, count > 0 {
                // Default count badge if no trailing content
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white : Color.secondary.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            if !isEditing {
                onHover(hovering)
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
        } else {
            return Color.clear
        }
    }
}
