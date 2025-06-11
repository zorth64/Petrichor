import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case library
    case playlists
    case folders
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .playlists: return "Playlists"
        case .folders: return "Folders"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "music.note.house"
        case .library: return "custom.music.note.rectangle.stack"
        case .playlists: return "music.note.list"
        case .folders: return "folder"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .home: return "music.note.house.fill"
        case .library: return "custom.music.note.rectangle.stack.fill"
        case .playlists: return "music.note.list"
        case .folders: return "folder.fill"
        }
    }
}
