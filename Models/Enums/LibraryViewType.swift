import Foundation

enum LibraryViewType: String, CaseIterable, Codable {
    case list = "list"
    case grid = "grid"
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
    
    var displayName: String {
        switch self {
        case .list: return "List View"
        case .grid: return "Grid View"
        }
    }
}
