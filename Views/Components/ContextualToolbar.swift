import SwiftUI

struct ContextualToolbar: View {
    let selectedTab: MainTab
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var viewType: LibraryViewType
    
    var body: some View {
        HStack {
            switch selectedTab {
            case .library:
                toolbarContent
            case .folders:
                toolbarContent
            case .playlists:
                toolbarContent
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Shared Toolbar Content
    
    private var toolbarContent: some View {
        HStack {
            Spacer()
            
            viewToggleButtons
            
            Spacer()
        }
    }
    
    // MARK: - View Toggle Buttons
    
    private var viewToggleButtons: some View {
        HStack(spacing: 1) {
            ViewToggleButton(
                icon: "list.bullet",
                viewType: .list,
                currentViewType: $viewType
            )
            
            ViewToggleButton(
                icon: "square.grid.2x2",
                viewType: .grid,
                currentViewType: $viewType
            )
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

// MARK: - View Toggle Button Component

private struct ViewToggleButton: View {
    let icon: String
    let viewType: LibraryViewType
    @Binding var currentViewType: LibraryViewType
    @State private var isHovered = false
    
    var isSelected: Bool {
        currentViewType == viewType
    }
    
    var body: some View {
        Button(action: { currentViewType = viewType }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected ? AnyShapeStyle(Color.white) :
                    isHovered ? AnyShapeStyle(Color.primary) :
                    AnyShapeStyle(Color.secondary)
                )
                .frame(width: 32, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isSelected ? Color.accentColor :
                            isHovered ? Color.primary.opacity(0.06) :
                            Color.clear
                        )
                        .animation(.easeOut(duration: 0.15), value: isSelected)
                        .animation(.easeOut(duration: 0.1), value: isHovered)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("\(viewType.displayName)")
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    @State var viewType: LibraryViewType = .list
    let libraryManager = LibraryManager()
    
    VStack(spacing: 0) {
        ContextualToolbar(selectedTab: .library, viewType: $viewType)
        ContextualToolbar(selectedTab: .folders, viewType: $viewType)
        ContextualToolbar(selectedTab: .playlists, viewType: $viewType)
    }
    .environmentObject(libraryManager)
}
