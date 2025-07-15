//
// ColumnVisibilityManager class
//
// This class handles the column visibility for TrackTableView.
//

import Foundation
import Combine

class ColumnVisibilityManager: ObservableObject {
    static let shared = ColumnVisibilityManager()

    @Published var columnVisibility: TrackTableColumnVisibility {
        didSet {
            saveColumnVisibility()
        }
    }
    
    @Published var columnOrder: [String]? {
        didSet {
            saveColumnOrder()
        }
    }

    private let columnVisibilityKey = "trackTableColumnVisibility"
    private let columnOrderKey = "trackTableColumnOrder"

    private init() {
        // Load from UserDefaults on init
        if let data = UserDefaults.standard.data(forKey: columnVisibilityKey),
           let decoded = try? JSONDecoder().decode(TrackTableColumnVisibility.self, from: data) {
            self.columnVisibility = decoded
        } else {
            // Use default visibility settings
            self.columnVisibility = TrackTableColumnVisibility()
        }
        self.columnOrder = UserDefaults.standard.array(forKey: columnOrderKey) as? [String]
    }

    private func saveColumnVisibility() {
        // Save to UserDefaults whenever it changes
        if let encoded = try? JSONEncoder().encode(columnVisibility) {
            UserDefaults.standard.set(encoded, forKey: columnVisibilityKey)
        }
    }
    
    private func saveColumnOrder() {
        if let order = columnOrder {
            UserDefaults.standard.set(order, forKey: columnOrderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: columnOrderKey)
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
    
    func updateColumnOrder(_ order: [String]) {
        columnOrder = order
    }
}
