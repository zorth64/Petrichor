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
            // Custom tab bar
            SettingsTabBar(selectedTab: $selectedTab)
                .padding()
            
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
// MARK: - Settings Tab Bar

struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsView.SettingsTab
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(SettingsView.SettingsTab.allCases, id: \.self) { tab in
                SettingsTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
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

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(Color.white) :
                        isHovered ? AnyShapeStyle(Color.primary) :
                        AnyShapeStyle(Color.secondary)
                    )
                
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isHovered ? .primary :
                        .secondary
                    )
            }
            .frame(width: 85) // Fixed width for all tabs
            .padding(.vertical, 5)
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
        .focusable(false)  // Disable focus ring
        .onHover { hovering in
            isHovered = hovering
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
