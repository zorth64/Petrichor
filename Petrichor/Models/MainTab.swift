import Foundation

enum MainTab: String, CaseIterable {
    case library = "Library"
    case folders = "Folders"
    case playlists = "Playlists"
    
    var icon: String {
        switch self {
        case .library: return "music.note.list"
        case .folders: return "folder"
        case .playlists: return "music.note.list"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .library: return "music.note.list"
        case .folders: return "folder.fill"
        case .playlists: return "music.note.list"
        }
    }
}
