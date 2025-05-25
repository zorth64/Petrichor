import Foundation

class Track: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    let url: URL
    
    @Published var title: String
    @Published var artist: String
    @Published var album: String
    @Published var genre: String
    @Published var year: String
    @Published var duration: Double
    @Published var artworkData: Data?
    @Published var isMetadataLoaded: Bool = false
    let format: String
    
    init(url: URL) {
        self.url = url
        
        // Default values - these will be overridden by LightweightTrack
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = "Unknown Album"
        self.genre = "Unknown Genre"
        self.year = "Unknown Year"
        self.duration = 0
        self.format = url.pathExtension
    }
    
    // Add Equatable conformance
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
}
