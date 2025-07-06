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
            HStack {
                Image(systemName: Icons.magnifyingGlass)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search...", text: $libraryManager.globalSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                // Spacer or clear button - maintains consistent space
                ZStack {
                    Color.clear
                        .frame(width: 16, height: 16)

                    if !libraryManager.globalSearchText.isEmpty {
                        Button(action: {
                            libraryManager.globalSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .frame(width: 280) // Fixed total width
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
