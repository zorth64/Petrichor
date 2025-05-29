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
        HStack(spacing: 0) {
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
    }
}

// MARK: - View Toggle Button Component

private struct ViewToggleButton: View {
    let icon: String
    let viewType: LibraryViewType
    @Binding var currentViewType: LibraryViewType
    
    var isSelected: Bool {
        currentViewType == viewType
    }
    
    var body: some View {
        Button(action: { currentViewType = viewType }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.borderless)
        .help("\(viewType.displayName)")
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
