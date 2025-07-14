import SwiftUI

struct ContextualToolbar: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var viewType: LibraryViewType
    var disableTableView: Bool = false

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        HStack {
            toolbarContent
        }
        .frame(height: 40)
        .padding(.horizontal, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private var isSearchActive: Bool {
        !libraryManager.globalSearchText.isEmpty
    }

    // MARK: - Shared Toolbar Content

    private var toolbarContent: some View {
        ZStack {
            HStack {
                Spacer()
                viewToggleButtons
                Spacer()
            }

            HStack {
                Spacer()
                searchField
            }
        }
    }

    // MARK: - View Toggle Buttons

    private var viewToggleButtons: some View {
        TabbedButtons(
            items: disableTableView
                ? [LibraryViewType.list, LibraryViewType.grid]
                : [LibraryViewType.table, LibraryViewType.list, LibraryViewType.grid],
            selection: $viewType,
            style: .viewToggle
        )
    }

    // MARK: - Search Input Field
    private var searchField: some View {
        HStack(spacing: 6) {
            // TODO we should ideally replace this with `.searchable`
            // which provides this UX without log of extra code, although
            // it would require titlebar layout changes.
            SearchInputField(
                text: $libraryManager.globalSearchText,
                placeholder: "Search",
                fontSize: 12,
                width: 280
            )
            .frame(width: 280)
        }
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
