import Foundation
import AVFoundation

class Track: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    
    @Published var title: String
    @Published var artist: String
    @Published var album: String
    @Published var genre: String
    @Published var duration: Double
    @Published var artworkData: Data?
    let format: String
    
    init(url: URL) {
        self.url = url
        
        // Default values
        self.title = url.lastPathComponent
        self.artist = "Unknown Artist"
        self.album = "Unknown Album"
        self.genre = "Unknown Genre"
        self.duration = 0
        self.format = url.pathExtension
        
        // Load metadata
        loadMetadata()
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
    
    private func loadMetadata() {
        // We'll use AVURLAsset for metadata extraction
        let asset = AVURLAsset(url: self.url)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get all common metadata
            let metadataList = asset.commonMetadata
            
            var title: String?
            var artist: String?
            var album: String?
            var genre: String?
            var artwork: Data?
            
            // Process metadata
            for item in metadataList {
                if let stringValue = item.stringValue {
                    if let key = item.commonKey {
                        switch key {
                        case AVMetadataKey.commonKeyTitle:
                            title = stringValue
                        case AVMetadataKey.commonKeyArtist:
                            artist = stringValue
                        case AVMetadataKey.commonKeyAlbumName:
                            album = stringValue
                        default:
                            break
                        }
                    }
                    
                    // Look for genre in various possible keys
                    let keyString = item.key as? String ?? ""
                    if keyString.lowercased().contains("genre") {
                        genre = stringValue
                    }
                }
                
                // Look for artwork
                if item.commonKey == AVMetadataKey.commonKeyArtwork, let data = item.dataValue {
                    artwork = data
                }
            }
            
            // Extract genre using ID3 metadata if we didn't find it above
            if genre == nil {
                for format in [AVMetadataFormat.id3Metadata, AVMetadataFormat.iTunesMetadata] {
                    let formatMetadata = asset.metadata(forFormat: format)
                    // Check if the array is not empty before processing
                    if !formatMetadata.isEmpty {
                        for item in formatMetadata {
                            let keyString = item.key as? String ?? ""
                            if keyString.lowercased().contains("genre"), let stringValue = item.stringValue {
                                genre = stringValue
                                break
                            }
                        }
                    }
                    if genre != nil { break }
                }
            }
            
            // Get duration (this works regardless of metadata)
            let duration = CMTimeGetSeconds(asset.duration)
            
            // Update on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let title = title, !title.isEmpty {
                    self.title = title
                }
                
                if let artist = artist, !artist.isEmpty {
                    self.artist = artist
                }
                
                if let album = album, !album.isEmpty {
                    self.album = album
                }
                
                if let genre = genre, !genre.isEmpty {
                    self.genre = genre
                }
                
                self.duration = duration
                self.artworkData = artwork
            }
        }
    }
}
