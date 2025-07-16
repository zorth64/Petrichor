import SwiftUI

struct ContextualToolbar: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var viewType: LibraryViewType
    var disableTableView: Bool = false

    var body: some View {
        HStack {
            toolbarContent
        }
        .frame(height: 40)
        .padding(.trailing, 8)
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private var isSearchActive: Bool {
        !libraryManager.globalSearchText.isEmpty
    }

    // MARK: - Shared Toolbar Content

    private var toolbarContent: some View {
        HStack {
            viewToggleButtons
        }
    }

    // MARK: - View Toggle Buttons

    private var viewToggleButtons: some View {
        TabbedButtons(
            items: [LibraryViewType.table, LibraryViewType.list, LibraryViewType.grid],
            selection: $viewType,
            style: .viewToggle,
            disableTableView: disableTableView
        )
    }
}

#Preview {
    @Previewable @State var viewType: LibraryViewType = .list
    let libraryManager = LibraryManager()

    VStack(spacing: 0) {
        ContextualToolbar(
            viewType: $viewType
        )
    }
    .environmentObject(libraryManager)
}
