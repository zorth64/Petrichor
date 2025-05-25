import Foundation

class TrackCacheManager {
    private var trackCache: [Int: Track] = [:] // Track ID to Track
    private var folderTracksCache: [Int: [Track]] = [:] // Folder ID to Tracks
    private let cacheQueue = DispatchQueue(label: "com.petrichor.trackcache", attributes: .concurrent)
    
    // Cache size limits
    private let maxTrackCacheSize = 1000
    private let maxFolderCacheSize = 10
    
    // LRU tracking
    private var trackAccessOrder: [Int] = []
    private var folderAccessOrder: [Int] = []
    
    // Get or create a track from database track
    func getTrack(from dbTrack: DatabaseTrack, using databaseManager: DatabaseManager) -> Track {
        return cacheQueue.sync {
            if let cachedTrack = trackCache[dbTrack.id] {
                // Move to end (most recently used)
                trackAccessOrder.removeAll { $0 == dbTrack.id }
                trackAccessOrder.append(dbTrack.id)
                return cachedTrack
            }
            
            let track = LightweightTrack(from: dbTrack, databaseManager: databaseManager)
            
            // Add to cache
            trackCache[dbTrack.id] = track
            trackAccessOrder.append(dbTrack.id)
            
            // Evict oldest if cache is too large
            if trackCache.count > maxTrackCacheSize {
                evictOldestTracks()
            }
            
            return track
        }
    }
    
    // Get tracks for a folder (cached)
    func getTracksForFolder(_ folderId: Int, from dbTracks: [DatabaseTrack], using databaseManager: DatabaseManager) -> [Track] {
        return cacheQueue.sync {
            // Check if we have cached tracks for this folder
            if let cachedTracks = folderTracksCache[folderId] {
                // Move to end (most recently used)
                folderAccessOrder.removeAll { $0 == folderId }
                folderAccessOrder.append(folderId)
                return cachedTracks
            }
            
            // Create tracks and cache them
            let tracks = dbTracks.map { dbTrack in
                if let cachedTrack = trackCache[dbTrack.id] {
                    return cachedTrack
                } else {
                    let track = LightweightTrack(from: dbTrack, databaseManager: databaseManager)
                    trackCache[dbTrack.id] = track
                    trackAccessOrder.append(dbTrack.id)
                    return track
                }
            }
            
            // Cache the folder's tracks
            folderTracksCache[folderId] = tracks
            folderAccessOrder.append(folderId)
            
            // Evict oldest if cache is too large
            if folderTracksCache.count > maxFolderCacheSize {
                evictOldestFolderCache()
            }
            
            if trackCache.count > maxTrackCacheSize {
                evictOldestTracks()
            }
            
            return tracks
        }
    }
    
    // Clear cache for a specific folder
    func clearFolderCache(_ folderId: Int) {
        cacheQueue.async(flags: .barrier) {
            self.folderTracksCache.removeValue(forKey: folderId)
            self.folderAccessOrder.removeAll { $0 == folderId }
        }
    }
    
    // Clear all caches
    func clearAllCaches() {
        cacheQueue.async(flags: .barrier) {
            self.trackCache.removeAll()
            self.folderTracksCache.removeAll()
            self.trackAccessOrder.removeAll()
            self.folderAccessOrder.removeAll()
        }
    }
    
    // Update cache when library is refreshed
    func refreshCaches() {
        clearAllCaches()
    }
    
    // MARK: - Private Methods
    
    private func evictOldestTracks() {
        // Remove the 20% oldest tracks
        let countToRemove = maxTrackCacheSize / 5
        let idsToRemove = trackAccessOrder.prefix(countToRemove)
        
        for id in idsToRemove {
            trackCache.removeValue(forKey: id)
        }
        
        trackAccessOrder.removeFirst(countToRemove)
    }
    
    private func evictOldestFolderCache() {
        // Remove the oldest folder cache
        if let oldestFolderId = folderAccessOrder.first {
            folderTracksCache.removeValue(forKey: oldestFolderId)
            folderAccessOrder.removeFirst()
        }
    }
    
    // Memory pressure handler
    func handleMemoryPressure() {
        cacheQueue.async(flags: .barrier) {
            // Clear half of the caches
            let trackCountToKeep = self.trackCache.count / 2
            let folderCountToKeep = self.folderTracksCache.count / 2
            
            // Keep only the most recent tracks
            if self.trackAccessOrder.count > trackCountToKeep {
                let idsToRemove = self.trackAccessOrder.prefix(self.trackAccessOrder.count - trackCountToKeep)
                for id in idsToRemove {
                    self.trackCache.removeValue(forKey: id)
                }
                self.trackAccessOrder.removeFirst(idsToRemove.count)
            }
            
            // Keep only the most recent folder caches
            if self.folderAccessOrder.count > folderCountToKeep {
                let idsToRemove = self.folderAccessOrder.prefix(self.folderAccessOrder.count - folderCountToKeep)
                for id in idsToRemove {
                    self.folderTracksCache.removeValue(forKey: id)
                }
                self.folderAccessOrder.removeFirst(idsToRemove.count)
            }
        }
    }
}
