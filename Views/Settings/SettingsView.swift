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
            case .general: return "gear"
            case .library: return "music.note.list"
            case .about: return "info.circle"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .general: return "gear"
            case .library: return "music.note.list"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabbedButtons(
                items: SettingsTab.allCases,
                selection: $selectedTab,
                style: .compact
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
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let manager = LibraryManager()
            return manager
        }())
}
