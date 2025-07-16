import SwiftUI

// MARK: - Types

enum NotificationType: Codable {
    case info, warning, error
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .accentColor
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct NotificationMessage: Identifiable, Codable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let timestamp: Date
    
    init(type: NotificationType, title: String) {
        self.type = type
        self.title = title
        self.timestamp = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case type, title, timestamp
    }
}

// MARK: - Manager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isActivityInProgress = false
    @Published var activityMessage = ""
    @Published var messages: [NotificationMessage] = []
    
    private let messagesKey = "NotificationTrayMessages"
    private var recentMessages: [String: Date] = [:]
    private var cleanupTimer: Timer?
    
    private init() {
        loadPersistedMessages()
    }
    
    func startActivity(_ message: String) {
        DispatchQueue.main.async {
            self.isActivityInProgress = true
            self.activityMessage = message
        }
    }
    
    func stopActivity() {
        DispatchQueue.main.async {
            self.isActivityInProgress = false
            self.activityMessage = ""
        }
    }
    
    func addMessage(_ type: NotificationType, _ title: String) {
        let messageKey = "\(type):\(title)"
        let now = Date()
        
        if let lastTime = recentMessages[messageKey], now.timeIntervalSince(lastTime) < 3.0 {
            return
        }
        
        DispatchQueue.main.async {
            self.messages.append(NotificationMessage(type: type, title: title))
            self.recentMessages[messageKey] = now
            self.saveMessages()
            self.startCleanupIfNeeded()
        }
    }
    
    func clearMessages() {
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.recentMessages.removeAll()
            self.saveMessages()
            self.stopCleanup()
        }
    }
    
    func removeMessage(_ message: NotificationMessage, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.messages.removeAll { $0.id == message.id }
            self.saveMessages()
            completion?()
        }
    }
    
    private func startCleanupIfNeeded() {
        guard cleanupTimer == nil else { return }
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let cutoff = Date().addingTimeInterval(-3.0)
            self.recentMessages = self.recentMessages.filter { $0.value > cutoff }
            if self.recentMessages.isEmpty { self.stopCleanup() }
        }
    }
    
    private func stopCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    private func saveMessages() {
        guard let encoded = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(encoded, forKey: messagesKey)
    }
    
    private func loadPersistedMessages() {
        guard let data = UserDefaults.standard.data(forKey: messagesKey),
              let decoded = try? JSONDecoder().decode([NotificationMessage].self, from: data) else { return }
        messages = decoded
    }
    
    deinit { stopCleanup() }
}

// MARK: - Views

struct NotificationTray: View {
    @StateObject private var manager = NotificationManager.shared
    @State private var showingPopover = false
    @State private var isHovered = false
    @State private var showingActivity = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: { if hasNotifications { showingPopover.toggle() } }) {
            ZStack {
                if isHovered {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.1), value: isHovered)
                }
                
                if showingActivity {
                    activityIndicator
                } else if hasNotifications {
                    Image(systemName: mostSevereNotificationType.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(mostSevereNotificationType.color)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            NotificationPopover(isPresented: $showingPopover)
        }
        .help(tooltipText)
        .onHover { isHovered = $0 }
        .onChange(of: manager.isActivityInProgress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) { showingActivity = newValue }
            if newValue { rotationAngle = 0 }
        }
    }
    
    private var hasNotifications: Bool { !manager.messages.isEmpty }
    private var mostSevereNotificationType: NotificationType {
        if manager.messages.contains(where: { $0.type == .error }) { return .error }
        if manager.messages.contains(where: { $0.type == .warning }) { return .warning }
        return .info
    }
    private var tooltipText: String {
        if manager.isActivityInProgress {
            return manager.activityMessage.isEmpty ? "Background activity..." : manager.activityMessage
        } else if hasNotifications {
            return "\(manager.messages.count) notification\(manager.messages.count == 1 ? "" : "s")"
        }
        return ""
    }
    
    @ViewBuilder
    private var activityIndicator: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear { startContinuousRotation() }
                .onDisappear { stopContinuousRotation() }
            
            Image(systemName: Icons.musicNote)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.accentColor)
        }
    }
    
    private func startContinuousRotation() {
        withAnimation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func stopContinuousRotation() {
        withAnimation(.easeOut(duration: 0.3)) { rotationAngle = 0 }
    }
}

struct NotificationPopover: View {
    @StateObject private var manager = NotificationManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notifications").font(.headline)
                Spacer()
                if !manager.messages.isEmpty {
                    Button("Clear") {
                        manager.clearMessages()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            
            Divider()
            
            if manager.messages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No notifications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.messages.reversed()) { message in
                            NotificationRow(message: message) {
                                manager.removeMessage(message) {
                                    if manager.messages.isEmpty { isPresented = false }
                                }
                            }
                            if message.id != manager.messages.first?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 350)
        .frame(maxHeight: 400)
    }
}

struct NotificationRow: View {
    let message: NotificationMessage
    let onDismiss: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.type.icon)
                .font(.system(size: 14))
                .foregroundColor(message.type.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(timeAgoText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isHovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { isHovered = $0 }
    }
    
    private var timeAgoText: String {
        let interval = Date().timeIntervalSince(message.timestamp)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hour\(Int(interval / 3600) == 1 ? "" : "s") ago" }
        return "\(Int(interval / 86400)) day\(Int(interval / 86400) == 1 ? "" : "s") ago"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        NotificationTray()
            .onAppear { NotificationManager.shared.startActivity("Scanning for new music...") }
        NotificationTray()
            .onAppear {
                NotificationManager.shared.stopActivity()
                NotificationManager.shared.addMessage(.info, "2 folders refreshed for changes")
                NotificationManager.shared.addMessage(.warning, "1 folder couldn't be accessed")
                NotificationManager.shared.addMessage(.error, "Failed to scan Downloads folder")
            }
    }
    .padding()
}
