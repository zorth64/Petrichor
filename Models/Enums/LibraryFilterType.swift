import Foundation

enum LibraryFilterType: String, CaseIterable {
    case artists = "Artists"
    case albums = "Albums"
    case composers = "Composers"
    case genres = "Genres"
    case years = "Years"
    
    var icon: String {
        switch self {
        case .artists: return "person.fill"
        case .albums: return "opticaldisc.fill"
        case .composers: return "person.fill"
        case .genres: return "music.note"
        case .years: return "calendar"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .artists: return "No artists found in your library"
        case .albums: return "No albums found in your library"
        case .composers: return "No composers found in your library"
        case .genres: return "No genres found in your library"
        case .years: return "No release years found in your library"
        }
    }
}
