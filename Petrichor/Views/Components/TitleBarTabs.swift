import SwiftUI

struct TitleBarTabs: View {
    @Binding var selectedTab: MainTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                TitleBarTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
    }
}

struct TitleBarTabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                // Very subtle background only for selected tab
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @State var selectedTab: MainTab = .library
    
    return VStack(spacing: 20) {
        // Show in title bar context
        HStack {
            Spacer()
            TitleBarTabs(selectedTab: $selectedTab)
            Spacer()
        }
        .frame(height: 52)
        .background(Color(NSColor.windowBackgroundColor))
        
        // Show what it looks like on different backgrounds
        HStack {
            Spacer()
            TitleBarTabs(selectedTab: $selectedTab)
            Spacer()
        }
        .frame(height: 52)
        .background(Color.gray.opacity(0.1))
    }
    .padding()
}
