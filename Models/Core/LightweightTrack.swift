import Foundation

class LightweightTrack: Track {
    private let trackId: Int
    private weak var databaseManager: DatabaseManager?
    private var _artworkData: Data?
    private var artworkLoaded = false
    private var artworkAccessDate: Date?
    
    // Artwork cache timeout (30 seconds)
    private static let artworkCacheTimeout: TimeInterval = 30
    
    init(from dbTrack: DatabaseTrack, databaseManager: DatabaseManager) {
        self.trackId = dbTrack.id
        self.databaseManager = databaseManager
        
        let url = URL(fileURLWithPath: dbTrack.path)
        super.init(url: url)
        
        // Set metadata immediately without loading artwork
        self.title = dbTrack.title
        self.artist = dbTrack.artist
        self.album = dbTrack.album
        self.genre = dbTrack.genre
        self.year = dbTrack.year
        self.duration = dbTrack.duration
        self.isMetadataLoaded = true
    }
    
    // Override artworkData to load on-demand with cache management
    override var artworkData: Data? {
        get {
            // Check if we should clear cached artwork
            if let accessDate = artworkAccessDate,
               Date().timeIntervalSince(accessDate) > Self.artworkCacheTimeout {
                clearArtwork()
            }
            
            if !artworkLoaded {
                artworkLoaded = true
                _artworkData = databaseManager?.getArtworkForTrack(trackId)
                artworkAccessDate = _artworkData != nil ? Date() : nil
            }
            
            // Update access time when artwork is accessed
            if _artworkData != nil {
                artworkAccessDate = Date()
            }
            
            return _artworkData
        }
        set {
            _artworkData = newValue
            artworkLoaded = true
            artworkAccessDate = newValue != nil ? Date() : nil
        }
    }
    
    // Method to explicitly clear artwork from memory
    func clearArtwork() {
        _artworkData = nil
        artworkLoaded = false
        artworkAccessDate = nil
    }
    
    // Method to preload artwork (useful for visible items)
    func preloadArtwork() {
        _ = artworkData
    }
}

// Extension to DatabaseTrack for lightweight conversion
extension DatabaseTrack {
    func toLightweightTrack(using databaseManager: DatabaseManager) -> Track {
        return LightweightTrack(from: self, databaseManager: databaseManager)
    }
}
