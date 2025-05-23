import SwiftUI

struct TopTabBar: View {
    @Binding var selectedTab: MainTab
    
    var body: some View {
        HStack(spacing: 0) {
            // App title/logo area
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                Text("Petrichor")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.leading, 20)
            
            Spacer()
            
            // Tab buttons
            HStack(spacing: 8) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Right side controls
            HStack(spacing: 12) {
                Button(action: { 
                    // Open preferences
                    if #available(macOS 14, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            .padding(.trailing, 20)
        }
        .frame(height: 50)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    @State var selectedTab: MainTab = .library
    
    return TopTabBar(selectedTab: $selectedTab)
}
