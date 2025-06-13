import Foundation
import GRDB

// MARK: - Track Processing Extension
extension DatabaseManager {
    
    // MARK: - Batch Processing
    
    /// Process a batch of music files with normalized data support
    func processBatch(_ batch: [(url: URL, folderId: Int64)]) async throws {
        await MainActor.run {
            self.isScanning = true
            self.scanProgress = 0
            self.scanStatusMessage = "Processing \(batch.count) files..."
        }
        
        // Process files concurrently but collect results
        try await withThrowingTaskGroup(of: (URL, TrackProcessResult).self) { group in
            for (fileURL, folderId) in batch {
                group.addTask { [weak self] in
                    guard let self = self else { return (fileURL, TrackProcessResult.skipped) }
                    
                    // Check if track already exists
                    if let existingTrack = try? await self.dbQueue.read({ db in
                        try Track.filter(Track.Columns.path == fileURL.path).fetchOne(db)
                    }) {
                        // Check if file has been modified
                        if let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                           let modificationDate = attributes.contentModificationDate,
                           let trackModifiedDate = existingTrack.dateModified,
                           modificationDate <= trackModifiedDate {
                            return (fileURL, TrackProcessResult.skipped)
                        }
                        
                        // File has changed, extract metadata
                        let metadata = MetadataExtractor.extractMetadataSync(from: fileURL)
                        var updatedTrack = existingTrack
                        
                        let hasChanges = self.updateTrackIfNeeded(&updatedTrack, with: metadata, at: fileURL)
                        
                        if hasChanges {
                            return (fileURL, TrackProcessResult.update(updatedTrack))
                        } else {
                            return (fileURL, TrackProcessResult.skipped)
                        }
                    } else {
                        // New track
                        let metadata = MetadataExtractor.extractMetadataSync(from: fileURL)
                        var track = Track(url: fileURL)
                        track.folderId = folderId
                        self.applyMetadataToTrack(&track, from: metadata, at: fileURL)
                        
                        return (fileURL, TrackProcessResult.new(track))
                    }
                }
            }
            
            // Collect results
            var newTracks: [Track] = []
            var tracksToUpdate: [Track] = []
            var skippedCount = 0
            
            for try await (_, result) in group {
                switch result {
                case TrackProcessResult.new(let track):
                    newTracks.append(track)
                case TrackProcessResult.update(let track):
                    tracksToUpdate.append(track)
                case TrackProcessResult.skipped:
                    skippedCount += 1
                }
            }
            
            // Process in database transaction
            try await dbQueue.write { db in
                // Process new tracks
                for track in newTracks {
                    try self.processNewTrack(track, in: db)
                }
                
                // Process updated tracks
                for track in tracksToUpdate {
                    try self.processUpdatedTrack(track, in: db)
                }
                
                // Update statistics after batch
                if !newTracks.isEmpty || !tracksToUpdate.isEmpty {
                    try self.updateEntityStats(in: db)
                }
            }
            
            print("Batch processing complete: \(newTracks.count) new, \(tracksToUpdate.count) updated, \(skippedCount) skipped")
        }
        
        await MainActor.run {
            self.isScanning = false
            self.scanProgress = 1.0
            self.scanStatusMessage = "Scan complete"
        }
    }
    
    // MARK: - Track Processing
    
    /// Process a new track with normalized data
    private func processNewTrack(_ track: Track, in db: Database) throws {
        var mutableTrack = track
        
        // Extract metadata for processing
        let metadata = TrackMetadata(url: track.url)
        
        // Process album first (so we can link the track to it)
        try processTrackAlbum(&mutableTrack, in: db)
        
        // Save the track (with album_id set)
        try mutableTrack.save(db)
        
        guard let trackId = mutableTrack.trackId else {
            throw DatabaseError.invalidTrackId
        }
        
        print("Added new track: \(mutableTrack.title) (ID: \(trackId))")
        
        // Process normalized relationships
        try processTrackArtists(mutableTrack, metadata: metadata, in: db)
        try processTrackGenres(mutableTrack, in: db)
        
        // Log interesting metadata
        logTrackMetadata(mutableTrack)
    }
    
    /// Process an updated track with normalized data
    private func processUpdatedTrack(_ track: Track, in db: Database) throws {
        var mutableTrack = track
        
        // Extract metadata for processing
        let metadata = TrackMetadata(url: track.url)
        
        // Update album association
        try processTrackAlbum(&mutableTrack, in: db)
        
        // Update the track
        try mutableTrack.update(db)
        
        guard let trackId = mutableTrack.trackId else {
            throw DatabaseError.invalidTrackId
        }
        
        print("Updated track: \(mutableTrack.title) (ID: \(trackId))")
        
        // Clear existing relationships
        try TrackArtist
            .filter(TrackArtist.Columns.trackId == trackId)
            .deleteAll(db)
        
        try TrackGenre
            .filter(TrackGenre.Columns.trackId == trackId)
            .deleteAll(db)
        
        // Re-process normalized relationships
        try processTrackArtists(mutableTrack, metadata: metadata, in: db)
        try processTrackGenres(mutableTrack, in: db)
    }
    
    // MARK: - Single File Processing (for legacy compatibility)
    
    /// Process a single music file
    func processMusicFile(at fileURL: URL, folderId: Int64) async throws {
        try await processBatch([(url: fileURL, folderId: folderId)])
    }
    
    // MARK: - Metadata Logging
    
    private func logTrackMetadata(_ track: Track) {
        // Log interesting metadata for debugging
        if let extendedMetadata = track.extendedMetadata {
            var interestingFields: [String] = []
            
            if let isrc = extendedMetadata.isrc { interestingFields.append("ISRC: \(isrc)") }
            if let label = extendedMetadata.label { interestingFields.append("Label: \(label)") }
            if let conductor = extendedMetadata.conductor { interestingFields.append("Conductor: \(conductor)") }
            if let producer = extendedMetadata.producer { interestingFields.append("Producer: \(producer)") }
            
            if !interestingFields.isEmpty {
                print("  Extended metadata: \(interestingFields.joined(separator: ", "))")
            }
        }
        
        // Log multi-artist info
        if track.artist.contains(";") || track.artist.contains(",") || track.artist.contains("&") {
            print("  Multi-artist track: \(track.artist)")
        }
        
        // Log album artist if different from artist
        if let albumArtist = track.albumArtist, albumArtist != track.artist {
            print("  Album artist differs: \(albumArtist)")
        }
    }
}
