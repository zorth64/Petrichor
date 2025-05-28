import Foundation

struct ArtistParser {
    // Common separators used in artist fields
    private static let separators = [
        " feat. ", " feat ", " featuring ", " ft. ", " ft ",
        " & ", " and ", " x ", " X ", " vs. ", " vs ",
        ", ", " with ", " / ", "／", "、", ";"
    ]
    
    /// Parses a multi-artist string into individual artist names
    static func parse(_ artistString: String) -> [String] {
        var artists: [String] = [artistString]
        
        // Process each separator
        for separator in separators {
            var newArtists: [String] = []
            
            for artist in artists {
                if artist.localizedCaseInsensitiveContains(separator) {
                    // Split by this separator (case-insensitive)
                    let components = artist.components(separatedBy: separator, options: .caseInsensitive)
                    newArtists.append(contentsOf: components)
                } else {
                    newArtists.append(artist)
                }
            }
            
            artists = newArtists
        }
        
        // Clean up and remove duplicates
        let cleanedArtists = artists
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Unknown Artist" }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        var uniqueArtists: [String] = []
        
        for artist in cleanedArtists {
            let lowercased = artist.lowercased()
            if !seen.contains(lowercased) {
                seen.insert(lowercased)
                uniqueArtists.append(artist)
            }
        }
        
        // If no valid artists found, return the original or "Unknown Artist"
        if uniqueArtists.isEmpty {
            return [artistString.isEmpty ? "Unknown Artist" : artistString]
        }
        
        return uniqueArtists
    }
    
    /// Checks if a specific artist appears in a track's artist field
    static func trackContainsArtist(_ track: Track, artistName: String) -> Bool {
        let artists = parse(track.artist)
        return artists.contains { artist in
            artist.localizedCaseInsensitiveCompare(artistName) == .orderedSame
        }
    }
}

// Extension to String for case-insensitive split
extension String {
    func components(separatedBy separator: String, options: String.CompareOptions) -> [String] {
        var result: [String] = []
        var currentIndex = self.startIndex
        
        while currentIndex < self.endIndex {
            if let range = self.range(of: separator, options: options, range: currentIndex..<self.endIndex) {
                result.append(String(self[currentIndex..<range.lowerBound]))
                currentIndex = range.upperBound
            } else {
                result.append(String(self[currentIndex..<self.endIndex]))
                break
            }
        }
        
        return result
    }
}
