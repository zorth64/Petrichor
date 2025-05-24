import Foundation
import AVFoundation

class MetadataExtractor {
    
    static func extractMetadata(from url: URL, completion: @escaping (TrackMetadata) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            var metadata = TrackMetadata(url: url)
            
            // Get all common metadata
            let metadataList = asset.commonMetadata
            
            // Process metadata
            for item in metadataList {
                if let stringValue = item.stringValue {
                    if let key = item.commonKey {
                        switch key {
                        case AVMetadataKey.commonKeyTitle:
                            metadata.title = stringValue
                        case AVMetadataKey.commonKeyArtist:
                            metadata.artist = stringValue
                        case AVMetadataKey.commonKeyAlbumName:
                            metadata.album = stringValue
                        default:
                            break
                        }
                    }
                    
                    // Look for genre and year in various possible keys
                    let keyString = item.key as? String ?? ""
                    if keyString.lowercased().contains("genre") {
                        metadata.genre = stringValue
                    } else if keyString.lowercased().contains("year") || keyString.lowercased().contains("date") {
                        metadata.year = stringValue
                    }
                }
                
                // Look for artwork
                if item.commonKey == AVMetadataKey.commonKeyArtwork, let data = item.dataValue {
                    metadata.artworkData = data
                }
            }
            
            // Extract genre and year using ID3 metadata if we didn't find them above
            if metadata.genre == nil || metadata.year == nil {
                for format in [AVMetadataFormat.id3Metadata, AVMetadataFormat.iTunesMetadata] {
                    let formatMetadata = asset.metadata(forFormat: format)
                    if !formatMetadata.isEmpty {
                        for item in formatMetadata {
                            let keyString = item.key as? String ?? ""
                            if metadata.genre == nil && keyString.lowercased().contains("genre"), 
                               let stringValue = item.stringValue {
                                metadata.genre = stringValue
                            }
                            if metadata.year == nil && (keyString.lowercased().contains("year") || 
                                                       keyString.lowercased().contains("date")), 
                               let stringValue = item.stringValue {
                                // Extract just the year from date strings
                                let components = stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                if let yearString = components.first(where: { $0.count == 4 && Int($0) != nil }) {
                                    metadata.year = yearString
                                } else {
                                    metadata.year = stringValue
                                }
                            }
                        }
                    }
                    if metadata.genre != nil && metadata.year != nil { break }
                }
            }
            
            // Get duration
            metadata.duration = CMTimeGetSeconds(asset.duration)
            
            // Return the metadata
            DispatchQueue.main.async {
                completion(metadata)
            }
        }
    }
    
    // Synchronous version for batch processing in database operations
    static func extractMetadataSync(from url: URL) -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var metadata = TrackMetadata(url: url)
        
        // Set a timeout for loading
        let semaphore = DispatchSemaphore(value: 0)
        var loadingComplete = false
        
        // Load metadata asynchronously but wait for it
        asset.loadValuesAsynchronously(forKeys: ["commonMetadata", "duration"]) {
            defer { 
                loadingComplete = true
                semaphore.signal() 
            }
            
            var error: NSError?
            let metadataStatus = asset.statusOfValue(forKey: "commonMetadata", error: &error)
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)
            
            guard metadataStatus == .loaded && durationStatus == .loaded else {
                return
            }
            
            // Process metadata
            let metadataList = asset.commonMetadata
            
            for item in metadataList {
                if let stringValue = item.stringValue {
                    if let key = item.commonKey {
                        switch key {
                        case AVMetadataKey.commonKeyTitle:
                            metadata.title = stringValue
                        case AVMetadataKey.commonKeyArtist:
                            metadata.artist = stringValue
                        case AVMetadataKey.commonKeyAlbumName:
                            metadata.album = stringValue
                        default:
                            break
                        }
                    }
                    
                    let keyString = item.key as? String ?? ""
                    if keyString.lowercased().contains("genre") {
                        metadata.genre = stringValue
                    } else if keyString.lowercased().contains("year") || keyString.lowercased().contains("date") {
                        metadata.year = stringValue
                    }
                }
                
                if item.commonKey == AVMetadataKey.commonKeyArtwork, let data = item.dataValue {
                    metadata.artworkData = data
                }
            }
            
            // Get duration
            metadata.duration = CMTimeGetSeconds(asset.duration)
        }
        
        // Wait for loading to complete (with timeout)
        let timeout = DispatchTime.now() + .seconds(5)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("MetadataExtractor: Timeout loading metadata for \(url.lastPathComponent)")
        }
        
        return metadata
    }
}

struct TrackMetadata {
    let url: URL
    var title: String?
    var artist: String?
    var album: String?
    var genre: String?
    var year: String?
    var duration: Double = 0
    var artworkData: Data?
    
    init(url: URL) {
        self.url = url
    }
}
