import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case library = "Library"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return Icons.settings
            case .library: return Icons.musicNoteList
            case .about: return Icons.infoCircle
            }
        }

        var selectedIcon: String {
            switch self {
            case .general: return Icons.settings
            case .library: return Icons.musicNoteList
            case .about: return Icons.infoCircleFill
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabbedButtons(
                items: SettingsTab.allCases,
                selection: $selectedTab,
                style: .compact,
                animation: .transform
            )
            .padding(10)
            .focusable(false)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    GeneralTabView()
                case .library:
                    LibraryTabView()
                case .about:
                    AboutTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SettingsSelectTab"))) { notification in
            if let tab = notification.object as? SettingsTab {
                selectedTab = tab
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let manager = LibraryManager()
            return manager
        }())
}
