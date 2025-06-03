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
        .background(Color(NSColor.windowBackgroundColor))
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
        TabbedButtons(
            items: [LibraryViewType.table, LibraryViewType.list, LibraryViewType.grid],
            selection: $viewType,
            style: .viewToggle
        )
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
