import Foundation

enum LibraryFilterType: String, CaseIterable {
    case artists = "Artists"
    case albums = "Albums"
    case years = "Years"
    case genres = "Genres"
    
    var icon: String {
        switch self {
        case .artists: return "person.fill"
        case .albums: return "opticaldisc.fill"
        case .years: return "calendar"
        case .genres: return "music.note"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .artists: return "No artists found in your library"
        case .albums: return "No albums found in your library"
        case .years: return "No release years found in your library"
        case .genres: return "No genres found in your library"
        }
    }
}
