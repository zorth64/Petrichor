import Foundation
import Combine

class ColumnVisibilityManager: ObservableObject {
    static let shared = ColumnVisibilityManager()
    
    @Published var columnVisibility: TrackTableColumnVisibility {
        didSet {
            saveColumnVisibility()
        }
    }
    
    private let userDefaultsKey = "trackTableColumnVisibility"
    
    private init() {
        // Load from UserDefaults on init
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(TrackTableColumnVisibility.self, from: data) {
            self.columnVisibility = decoded
        } else {
            // Use default visibility settings
            self.columnVisibility = TrackTableColumnVisibility()
        }
    }
    
    private func saveColumnVisibility() {
        // Save to UserDefaults whenever it changes
        if let encoded = try? JSONEncoder().encode(columnVisibility) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func toggleVisibility(_ column: TrackTableColumn) {
        columnVisibility.toggleVisibility(column)
    }
    
    func isVisible(_ column: TrackTableColumn) -> Bool {
        columnVisibility.isVisible(column)
    }
    
    func setVisibility(_ column: TrackTableColumn, isVisible: Bool) {
        columnVisibility.setVisibility(column, isVisible: isVisible)
    }
}
