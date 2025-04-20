import Foundation

struct Folder: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var name: String
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
    }
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
}
