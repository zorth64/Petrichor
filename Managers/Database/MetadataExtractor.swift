import Foundation
import AVFoundation

class MetadataExtractor {
    
    // MARK: - Known metadata keys for different formats
    private static let composerKeys = [
        "composer",
        "©wrt",
        "\u{00A9}wrt", // Unicode copyright symbol + wrt
        "TCOM",
        "TCM",
        AVMetadataKey.commonKeyCreator.rawValue,
        AVMetadataKey.iTunesMetadataKeyComposer.rawValue,
        AVMetadataKey.id3MetadataKeyComposer.rawValue,
        AVMetadataKey.quickTimeMetadataKeyProducer.rawValue
    ]
    
    private static let genreKeys = [
        "genre",
        "gnre",
        "©gen",
        "\u{00A9}gen", // Unicode copyright symbol + gen
        "TCON",
        AVMetadataKey.id3MetadataKeyContentType.rawValue,
        AVMetadataKey.iTunesMetadataKeyUserGenre.rawValue,
        AVMetadataKey.quickTimeMetadataKeyGenre.rawValue
    ]
    
    private static let yearKeys = [
        "year",
        "date",
        "©day",
        "\u{00A9}day", // Unicode copyright symbol + day
        "TDRC",
        "TYER",
        "TDAT",
        "TYE",
        "TDA",
        "TDRL",
        AVMetadataKey.id3MetadataKeyYear.rawValue,
        AVMetadataKey.id3MetadataKeyRecordingTime.rawValue,
        AVMetadataKey.iTunesMetadataKeyReleaseDate.rawValue,
        AVMetadataKey.quickTimeMetadataKeyYear.rawValue,
        AVMetadataKey.commonKeyCreationDate.rawValue
    ]
    
    static func extractMetadata(from url: URL, completion: @escaping (TrackMetadata) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let metadata = extractMetadataSync(from: url)
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
        asset.loadValuesAsynchronously(forKeys: ["commonMetadata", "metadata", "availableMetadataFormats", "duration"]) {
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
            
            // Process common metadata first
            let commonMetadata = asset.commonMetadata
            processMetadataItems(commonMetadata, into: &metadata)
            
            // Process all available format-specific metadata
            for format in asset.availableMetadataFormats {
                let formatMetadata = asset.metadata(forFormat: format)
                if !formatMetadata.isEmpty {
                    processMetadataItems(formatMetadata, into: &metadata)
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
    
    // MARK: - Private Helper Methods
    
    private static func processMetadataItems(_ items: [AVMetadataItem], into metadata: inout TrackMetadata) {
        for item in items {
            // Get all possible representations of the key
            let keyString = getKeyString(from: item)
            let identifier = item.identifier?.rawValue ?? ""
            let commonKey = item.commonKey?.rawValue ?? ""
            
            // Try to get string value
            if let stringValue = getStringValue(from: item) {
                // Check common keys first
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case AVMetadataKey.commonKeyTitle:
                        if metadata.title == nil {
                            metadata.title = stringValue
                        }
                    case AVMetadataKey.commonKeyArtist:
                        if metadata.artist == nil {
                            metadata.artist = stringValue
                        }
                    case AVMetadataKey.commonKeyAlbumName:
                        if metadata.album == nil {
                            metadata.album = stringValue
                        }
                    case AVMetadataKey.commonKeyCreator:
                        if metadata.composer == nil {
                            metadata.composer = stringValue
                        }
                    default:
                        break
                    }
                }
                
                if metadata.composer == nil && (isComposerKey(keyString) || isComposerKey(identifier) || isComposerKey(commonKey)) {
                    metadata.composer = stringValue
                }
                
                // Check for genre using all possible key representations
                if metadata.genre == nil && (isGenreKey(keyString) || isGenreKey(identifier) || isGenreKey(commonKey)) {
                    metadata.genre = stringValue
                }
                
                // Check for year using all possible key representations
                if metadata.year == nil && (isYearKey(keyString) || isYearKey(identifier) || isYearKey(commonKey)) {
                    metadata.year = extractYear(from: stringValue)
                }
            }
            
            // Check for artwork
            if item.commonKey == AVMetadataKey.commonKeyArtwork {
                if let data = item.dataValue {
                    metadata.artworkData = data
                } else if let value = item.value {
                    // Sometimes artwork is stored as NSData or other types
                    if let data = value as? Data {
                        metadata.artworkData = data
                    } else if let data = value as? NSData {
                        metadata.artworkData = data as Data
                    }
                }
            }
        }
    }
    
    private static func getStringValue(from item: AVMetadataItem) -> String? {
        // Try direct string value
        if let stringValue = item.stringValue {
            return stringValue
        }
        
        // Try to get value and convert to string
        if let value = item.value {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            } else if let dataValue = value as? Data {
                // Try to decode as UTF-8 string
                return String(data: dataValue, encoding: .utf8)
            }
        }
        
        // Try data value as string
        if let dataValue = item.dataValue {
            return String(data: dataValue, encoding: .utf8)
        }
        
        return nil
    }
    
    private static func getKeyString(from item: AVMetadataItem) -> String {
        if let key = item.key {
            if let stringKey = key as? String {
                return stringKey
            } else if let numberKey = key as? NSNumber {
                // For ID3 tags, convert numeric keys to their string equivalents
                let id3Key = String(format: "%c%c%c%c",
                    (numberKey.uint32Value >> 24) & 0xFF,
                    (numberKey.uint32Value >> 16) & 0xFF,
                    (numberKey.uint32Value >> 8) & 0xFF,
                    numberKey.uint32Value & 0xFF)
                return id3Key
            } else {
                return String(describing: key)
            }
        }
        return ""
    }
    
    private static func isComposerKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        
        // Direct match
        if composerKeys.contains(where: { $0.lowercased() == lowercaseKey }) {
            return true
        }
        
        // Check if key contains composer-related terms
        return lowercaseKey.contains("composer") ||
               lowercaseKey.contains("tcom") ||
               lowercaseKey.contains("wrt") ||
               lowercaseKey == "©wrt" ||
               lowercaseKey == "\u{00A9}wrt"
    }
    
    private static func isGenreKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        
        // Direct match
        if genreKeys.contains(where: { $0.lowercased() == lowercaseKey }) {
            return true
        }
        
        // Check if key contains genre-related terms
        return lowercaseKey.contains("genre") ||
               lowercaseKey.contains("gnre") ||
               lowercaseKey.contains("tcon") ||
               lowercaseKey == "©gen" ||
               lowercaseKey == "\u{00A9}gen"
    }
    
    private static func isYearKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        
        // Direct match
        if yearKeys.contains(where: { $0.lowercased() == lowercaseKey }) {
            return true
        }
        
        // Check if key contains year/date-related terms
        return lowercaseKey.contains("year") ||
               lowercaseKey.contains("date") ||
               lowercaseKey.contains("tyer") ||
               lowercaseKey.contains("tdrc") ||
               lowercaseKey.contains("tdat") ||
               lowercaseKey == "©day" ||
               lowercaseKey == "\u{00A9}day"
    }
    
    private static func extractYear(from dateString: String) -> String {
        // Try to extract just the year from various date formats
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's already just a year (4 digits), return it
        if trimmed.count == 4 && Int(trimmed) != nil {
            return trimmed
        }
        
        // Try to find a 4-digit year in the string
        let pattern = #"\b(19\d{2}|20\d{2})\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let yearRange = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[yearRange])
        }
        
        // Try date formatter as last resort
        let dateFormatters = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "yyyy",
            "dd-MM-yyyy",
            "dd/MM/yyyy",
            "MM-dd-yyyy",
            "MM/dd/yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZ", // ISO 8601
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: trimmed) {
                let yearFormatter = DateFormatter()
                yearFormatter.dateFormat = "yyyy"
                return yearFormatter.string(from: date)
            }
        }
        
        // If all else fails, return the original string
        return trimmed
    }
}

struct TrackMetadata {
    let url: URL
    var title: String?
    var artist: String?
    var album: String?
    var composer: String?
    var genre: String?
    var year: String?
    var duration: Double = 0
    var artworkData: Data?
    
    init(url: URL) {
        self.url = url
    }
}
