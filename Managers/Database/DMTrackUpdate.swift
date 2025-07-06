import Foundation
import GRDB

extension DatabaseManager {
    // Updates a track's favorite status
    func updateTrackFavoriteStatus(trackId: Int64, isFavorite: Bool) async throws {
        _ = try await dbQueue.write { db in
            try Track
                .filter(Track.Columns.trackId == trackId)
                .updateAll(db, Track.Columns.isFavorite.set(to: isFavorite))
        }
    }

    // Updates a track's play count and last played date
    func updateTrackPlayInfo(trackId: Int64, playCount: Int, lastPlayedDate: Date) async throws {
        _ = try await dbQueue.write { db in
            try Track
                .filter(Track.Columns.trackId == trackId)
                .updateAll(db,
                    Track.Columns.playCount.set(to: playCount),
                    Track.Columns.lastPlayedDate.set(to: lastPlayedDate)
                )
        }
    }

    // Batch update for track properties (more efficient for multiple updates)
    func updateTrack(_ track: Track) async throws {
        guard track.trackId != nil else {
            throw DatabaseError.invalidTrackId
        }

        try await dbQueue.write { db in
            try track.update(db)
        }
    }

    // Gets tracks by favorite status
    func getFavoriteTracks() -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.isFavorite == true)
                    .order(Track.Columns.title)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch favorite tracks: \(error)")
            return []
        }
    }

    // Gets most played tracks
    func getMostPlayedTracks(minPlayCount: Int = 3, limit: Int = 25) -> [Track] {
        do {
            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.playCount >= minPlayCount)
                    .order(Track.Columns.playCount.desc)
                    .limit(limit)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch most played tracks: \(error)")
            return []
        }
    }

    // Gets recently played tracks
    func getRecentlyPlayedTracks(daysBack: Int = 7, limit: Int = 25) -> [Track] {
        do {
            let cutoffDate = Date().addingTimeInterval(-Double(daysBack * 24 * 60 * 60))

            return try dbQueue.read { db in
                try Track
                    .filter(Track.Columns.lastPlayedDate > cutoffDate)
                    .order(Track.Columns.lastPlayedDate.desc)
                    .limit(limit)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch recently played tracks: \(error)")
            return []
        }
    }
}
