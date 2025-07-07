import Foundation

struct LibraryFilterItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let count: Int
    let filterType: LibraryFilterType

    init(name: String, count: Int, filterType: LibraryFilterType) {
        self.name = name.isEmpty ? "Unknown \(filterType.rawValue.dropLast())" : name
        self.count = count
        self.filterType = filterType
    }

    static func allItem(for filterType: LibraryFilterType, totalCount: Int) -> LibraryFilterItem {
        LibraryFilterItem(name: "All \(filterType.rawValue)", count: totalCount, filterType: filterType)
    }
}
