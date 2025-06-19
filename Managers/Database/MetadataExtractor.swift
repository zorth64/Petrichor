import Foundation
import AVFoundation
import CoreMedia

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

    private static let albumArtistKeys = [
        "TPE2",
        "albumartist",
        "album artist",
        AVMetadataKey.iTunesMetadataKeyAlbumArtist.rawValue,
        AVMetadataKey.id3MetadataKeyBand.rawValue
    ]

    private static let trackNumberKeys = [
        "TRCK",
        "tracknumber",
        "track",
        AVMetadataKey.id3MetadataKeyTrackNumber.rawValue,
        AVMetadataKey.iTunesMetadataKeyTrackNumber.rawValue
    ]

    private static let discNumberKeys = [
        "TPOS",
        "discnumber",
        "disc",
        AVMetadataKey.iTunesMetadataKeyDiscNumber.rawValue
    ]

    private static let copyrightKeys = [
        "TCOP",
        "©cpy",
        "\u{00A9}cpy",
        "copyright",
        AVMetadataKey.commonKeyCopyrights.rawValue,
        AVMetadataKey.id3MetadataKeyCopyright.rawValue,
        AVMetadataKey.iTunesMetadataKeyCopyright.rawValue
    ]

    private static let bpmKeys = [
        "TBPM",
        "bpm",
        "beatsperminute",
        AVMetadataKey.iTunesMetadataKeyBeatsPerMin.rawValue
    ]

    private static let commentKeys = [
        "COMM",
        "comment",
        "©cmt",
        "\u{00A9}cmt",
        AVMetadataKey.commonKeyDescription.rawValue,
        AVMetadataKey.iTunesMetadataKeyUserComment.rawValue
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
        asset.loadValuesAsynchronously(forKeys: ["commonMetadata", "metadata", "availableMetadataFormats", "duration", "tracks"]) {
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

            // Get audio format information
            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription] ?? []

                if let formatDescription = formatDescriptions.first {
                    // Get audio stream basic description
                    if let streamBasicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                        metadata.sampleRate = Int(streamBasicDesc.pointee.mSampleRate)
                        metadata.channels = Int(streamBasicDesc.pointee.mChannelsPerFrame)

                        // Bit depth from bits per channel
                        if streamBasicDesc.pointee.mBitsPerChannel > 0 {
                            metadata.bitDepth = Int(streamBasicDesc.pointee.mBitsPerChannel)
                        }
                    }

                    // Get codec
                    let audioCodec = CMFormatDescriptionGetMediaSubType(formatDescription)
                    metadata.codec = fourCCToString(audioCodec)
                }

                // Estimate bitrate
                let dataRate = audioTrack.estimatedDataRate
                if dataRate > 0 {
                    metadata.bitrate = Int(dataRate / 1000) // Convert to kbps
                }
            }
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

                // Core metadata
                if metadata.composer == nil && (isComposerKey(keyString) || isComposerKey(identifier) || isComposerKey(commonKey)) {
                    metadata.composer = stringValue
                }

                if metadata.genre == nil && (isGenreKey(keyString) || isGenreKey(identifier) || isGenreKey(commonKey)) {
                    metadata.genre = stringValue
                }

                if metadata.year == nil && (isYearKey(keyString) || isYearKey(identifier) || isYearKey(commonKey)) {
                    metadata.year = extractYear(from: stringValue)
                }

                // Core additional metadata
                if metadata.albumArtist == nil && isAlbumArtistKey(keyString, identifier, commonKey) {
                    metadata.albumArtist = stringValue
                }

                if metadata.trackNumber == nil && isTrackNumberKey(keyString, identifier, commonKey) {
                    let (track, total) = parseNumbering(stringValue)
                    metadata.trackNumber = track.flatMap { Int($0) }
                    metadata.totalTracks = total.flatMap { Int($0) }
                }

                if metadata.discNumber == nil && isDiscNumberKey(keyString, identifier, commonKey) {
                    let (disc, total) = parseNumbering(stringValue)
                    metadata.discNumber = disc.flatMap { Int($0) }
                    metadata.totalDiscs = total.flatMap { Int($0) }
                }

                if metadata.extended.copyright == nil && isCopyrightKey(keyString, identifier, commonKey) {
                    metadata.extended.copyright = stringValue
                }

                if metadata.bpm == nil && isBPMKey(keyString, identifier, commonKey) {
                    metadata.bpm = Int(stringValue)
                }

                if metadata.extended.comment == nil && isCommentKey(keyString, identifier, commonKey) {
                    metadata.extended.comment = stringValue
                }

                // Additional extended fields
                extractExtendedFields(keyString, identifier, stringValue, into: &metadata)
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

    // NEW: Extract additional extended fields
    private static func extractExtendedFields(_ keyString: String, _ identifier: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = keyString.lowercased()
        let lowercaseIdentifier = identifier.lowercased()

        // Label
        if lowercaseKey.contains("label") || lowercaseKey == "tpub" || lowercaseIdentifier.contains("label") {
            metadata.extended.label = value
        }

        // ISRC
        if lowercaseKey == "tsrc" || lowercaseKey.contains("isrc") || lowercaseIdentifier.contains("isrc") {
            metadata.extended.isrc = value
        }

        // Lyrics
        if lowercaseKey == "uslt" || lowercaseKey.contains("lyrics") || lowercaseIdentifier.contains("lyrics") {
            metadata.extended.lyrics = value
        }

        // Original Artist
        if lowercaseKey == "tope" || lowercaseKey.contains("originalartist") || lowercaseIdentifier.contains("originalartist") {
            metadata.extended.originalArtist = value
        }

        // Release dates
        if lowercaseKey.contains("releasedate") || lowercaseKey == "tdrl" {
            metadata.releaseDate = value
        } else if lowercaseKey.contains("originaldate") || lowercaseKey == "tdor" {
            metadata.originalReleaseDate = value
        }

        // Key
        if lowercaseKey == "tkey" || lowercaseKey.contains("initialkey") || lowercaseKey.contains("musicalkey") {
            metadata.extended.key = value
        }

        // MusicBrainz IDs
        if lowercaseKey.contains("musicbrainz") || identifier.contains("MusicBrainz") {
            parseMusicBrainzTag(keyString, identifier, value, into: &metadata)
        }

        // Sorting fields
        if lowercaseKey.contains("sort") || identifier.contains("sort") {
            parseSortingTag(keyString, identifier, value, into: &metadata)
        }

        // ReplayGain
        if lowercaseKey.contains("replaygain") || identifier.contains("replaygain") {
            parseReplayGainTag(keyString, identifier, value, into: &metadata)
        }

        // iTunes specific
        if lowercaseKey.contains("itunes") || identifier.contains("iTunes") {
            parseITunesTag(keyString, identifier, value, into: &metadata)
        }

        // Additional personnel
        if lowercaseKey == "tpe3" || lowercaseKey.contains("conductor") {
            metadata.extended.conductor = value
        }

        if lowercaseKey == "tpe4" || lowercaseKey.contains("remixer") {
            metadata.extended.remixer = value
        }

        if lowercaseKey == "tpro" || lowercaseKey.contains("producer") {
            metadata.extended.producer = value
        }

        if lowercaseKey.contains("engineer") {
            metadata.extended.engineer = value
        }

        if lowercaseKey == "text" || lowercaseKey.contains("lyricist") {
            metadata.extended.lyricist = value
        }

        // Additional descriptive fields
        if lowercaseKey.contains("subtitle") || lowercaseKey == "tit3" {
            metadata.extended.subtitle = value
        }

        if lowercaseKey.contains("grouping") || lowercaseKey == "tit1" || lowercaseKey == "grp1" {
            metadata.extended.grouping = value
        }

        if lowercaseKey.contains("movement") {
            metadata.extended.movement = value
        }

        if lowercaseKey.contains("mood") {
            metadata.extended.mood = value
        }

        if lowercaseKey == "tlan" || lowercaseKey.contains("language") {
            metadata.extended.language = value
        }

        // Publisher
        if lowercaseKey == "tpub" || lowercaseKey.contains("publisher") {
            metadata.extended.publisher = value
        }

        // Barcode
        if lowercaseKey.contains("barcode") || lowercaseKey.contains("upc") {
            metadata.extended.barcode = value
        }

        // Catalog number
        if lowercaseKey.contains("catalog") {
            metadata.extended.catalogNumber = value
        }

        // Encoded by
        if lowercaseKey == "tenc" || lowercaseKey.contains("encodedby") {
            metadata.extended.encodedBy = value
        }

        // Encoder settings
        if lowercaseKey == "tsse" || lowercaseKey.contains("encodersettings") {
            metadata.extended.encoderSettings = value
        }
    }

    // Helper methods for parsing specific tag types
    private static func parseMusicBrainzTag(_ key: String, _ identifier: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        if lowercaseKey.contains("artist") && lowercaseKey.contains("id") {
            metadata.extended.musicBrainzArtistId = value
        } else if lowercaseKey.contains("album") && lowercaseKey.contains("id") {
            metadata.extended.musicBrainzAlbumId = value
        } else if lowercaseKey.contains("track") && lowercaseKey.contains("id") {
            metadata.extended.musicBrainzTrackId = value
        } else if lowercaseKey.contains("release") && lowercaseKey.contains("group") {
            metadata.extended.musicBrainzReleaseGroupId = value
        } else if lowercaseKey.contains("work") && lowercaseKey.contains("id") {
            metadata.extended.musicBrainzWorkId = value
        }
    }

    private static func parseSortingTag(_ key: String, _ identifier: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        if lowercaseKey.contains("albumsort") || lowercaseKey == "tsoa" {
            metadata.sortAlbum = value
        } else if lowercaseKey.contains("artistsort") || lowercaseKey == "tsop" {
            metadata.sortArtist = value
        } else if lowercaseKey.contains("albumartistsort") || lowercaseKey == "tso2" {
            metadata.sortAlbumArtist = value
        } else if lowercaseKey.contains("titlesort") || lowercaseKey == "tsot" {
            metadata.sortTitle = value
        } else if lowercaseKey.contains("composersort") || lowercaseKey == "tsoc" {
            metadata.extended.sortComposer = value
        }
    }

    private static func parseReplayGainTag(_ key: String, _ identifier: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        if lowercaseKey.contains("album") {
            metadata.extended.replayGainAlbum = value
        } else if lowercaseKey.contains("track") {
            metadata.extended.replayGainTrack = value
        }
    }

    private static func parseITunesTag(_ key: String, _ identifier: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        if lowercaseKey.contains("compilation") {
            metadata.compilation = (value == "1" || value.lowercased() == "true")
        } else if lowercaseKey.contains("gapless") {
            metadata.extended.gaplessData = value
        } else if lowercaseKey.contains("mediatype") || lowercaseKey.contains("stik") {
            metadata.mediaType = value
        } else if lowercaseKey.contains("rating") {
            // iTunes stores rating as 0-100, we'll convert to 0-5
            if let ratingValue = Int(value) {
                metadata.rating = ratingValue / 20
            }
        } else if lowercaseKey.contains("advisory") {
            metadata.extended.itunesAdvisory = value
        } else if lowercaseKey.contains("account") {
            metadata.extended.itunesAccount = value
        } else if lowercaseKey.contains("purchasedate") {
            metadata.extended.itunesPurchaseDate = value
        }
    }

    // Parse track/disc numbering (e.g., "5/12" -> ("5", "12"))
    private static func parseNumbering(_ value: String) -> (String?, String?) {
        let components = value.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        if components.count >= 2 {
            return (components[0], components[1])
        } else if components.count == 1 {
            return (components[0], nil)
        }
        return (nil, nil)
    }

    // Key checking methods
    private static func isAlbumArtistKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return albumArtistKeys.contains { combined.contains($0.lowercased()) }
    }

    private static func isTrackNumberKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return trackNumberKeys.contains { combined.contains($0.lowercased()) }
    }

    private static func isDiscNumberKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return discNumberKeys.contains { combined.contains($0.lowercased()) }
    }

    private static func isCopyrightKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return copyrightKeys.contains { combined.contains($0.lowercased()) }
    }

    private static func isBPMKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return bpmKeys.contains { combined.contains($0.lowercased()) }
    }

    private static func isCommentKey(_ key: String, _ identifier: String, _ commonKey: String) -> Bool {
        let combined = (key + identifier + commonKey).lowercased()
        return commentKeys.contains { combined.contains($0.lowercased()) }
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

    // Helper to convert FourCC to string
    private static func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]

        // Common audio codecs mapping
        switch fourCC {
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatLinearPCM: return "PCM"
        case kAudioFormatAC3: return "AC-3"
        case kAudioFormatMPEG4AAC_HE: return "HE-AAC"
        case kAudioFormatMPEG4AAC_HE_V2: return "HE-AACv2"
        default:
            // Convert FourCC bytes to string
            let fourCCString = String(bytes: bytes, encoding: .ascii) ?? "Unknown"
            return fourCCString.trimmingCharacters(in: .whitespaces)
        }
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
    var albumArtist: String?
    var trackNumber: Int?
    var totalTracks: Int?
    var discNumber: Int?
    var totalDiscs: Int?
    var rating: Int?
    var compilation: Bool = false
    var releaseDate: String?
    var originalReleaseDate: String?
    var bpm: Int?
    var mediaType: String?
    var bitrate: Int?
    var sampleRate: Int?
    var channels: Int?
    var codec: String?
    var bitDepth: Int?

    var sortTitle: String?
    var sortArtist: String?
    var sortAlbum: String?
    var sortAlbumArtist: String?

    var extended: ExtendedMetadata

    init(url: URL) {
        self.url = url
        self.extended = ExtendedMetadata()
    }
}
