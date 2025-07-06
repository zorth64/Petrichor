import Foundation

enum LibraryViewType: String, CaseIterable, Codable {
    case list
    case grid
    case table

    var displayName: String {
        switch self {
        case .list: return "List View"
        case .grid: return "Grid View"
        case .table: return "Table View"
        }
    }
}
