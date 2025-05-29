import SwiftUI

struct GeneralTabView: View {
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("closeToMenubar") private var closeToMenubar = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoScanInterval") private var autoScanInterval: AutoScanInterval = .every60Minutes
    @AppStorage("colorMode") private var colorMode: ColorMode = .auto
    
    enum ColorMode: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case auto = "Auto"
        
        var displayName: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .light:
                return "sun.max.fill"
            case .dark:
                return "moon.fill"
            case .auto:
                return "circle.lefthalf.filled"
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Start at login", isOn: $startAtLogin)
                Toggle("Keep running in menubar on close", isOn: $closeToMenubar)
                Toggle("Show notifications for new tracks", isOn: $showNotifications)
            }
            
            Section("Appearance") {
                HStack {
                    Text("Color mode")
                    Spacer()
                    ColorModeSegmentedControl(selection: $colorMode)
                        .frame(width: 200)
                }
            }
            
            Section("Library Scanning") {
                HStack {
                    Picker("Auto-scan library every", selection: $autoScanInterval) {
                        ForEach(AutoScanInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .padding()
        .onChange(of: colorMode) { newValue in
            updateAppearance(newValue)
        }
        .onAppear {
            // Apply the saved color mode when the view appears
            updateAppearance(colorMode)
        }
    }
    
    private func updateAppearance(_ mode: ColorMode) {
        switch mode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil // Follow system
        }
    }
}

// Custom segmented control that shows icons
struct ColorModeSegmentedControl: View {
    @Binding var selection: GeneralTabView.ColorMode
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(GeneralTabView.ColorMode.allCases, id: \.self) { mode in
                ColorModeButton(
                    mode: mode,
                    isSelected: selection == mode,
                    action: { selection = mode }
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

struct ColorModeButton: View {
    let mode: GeneralTabView.ColorMode
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(Color.white) :
                        isHovered ? AnyShapeStyle(Color.primary) :
                        AnyShapeStyle(Color.secondary)
                    )
                
                Text(mode.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isHovered ? .primary :
                        .secondary
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    GeneralTabView()
        .frame(width: 600, height: 500)
}
