import Foundation
import GRDB

extension PlaylistManager {
    // MARK: - Smart Playlist Management

    func updateSmartPlaylists() {
        guard let library = libraryManager else { return }

        print("PlaylistManager: Updating smart playlists...")

        for index in playlists.indices {
            guard playlists[index].type == .smart else { continue }

            var updatedPlaylist = playlists[index]

            switch updatedPlaylist.smartType {
            case .favorites:
                updatedPlaylist.tracks = library.tracks
                    .filter { $0.isFavorite }
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            case .mostPlayed:
                let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                updatedPlaylist.tracks = library.tracks
                    .filter { $0.playCount >= 3 }
                    .sorted { $0.playCount > $1.playCount }
                    .prefix(limit)
                    .map { $0 }

            case .recentlyPlayed:
                let limit = updatedPlaylist.smartCriteria?.limit ?? 25
                let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

                updatedPlaylist.tracks = library.tracks
                    .filter { track in
                        guard let lastPlayed = track.lastPlayedDate else { return false }
                        return lastPlayed > oneWeekAgo
                    }
                    .sorted { track1, track2 in
                        guard let date1 = track1.lastPlayedDate,
                              let date2 = track2.lastPlayedDate else { return false }
                        return date1 > date2
                    }
                    .prefix(limit)
                    .map { $0 }

            default:
                break
            }

            playlists[index] = updatedPlaylist
        }
    }

    // MARK: - Playlist CRUD Operations

    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        let newPlaylist = Playlist(name: name, tracks: tracks)

        let smartPlaylists = playlists.filter { $0.type == .smart }
        let regularPlaylists = playlists.filter { $0.type == .regular }

        playlists = sortPlaylists(smart: smartPlaylists, regular: regularPlaylists + [newPlaylist])

        // Save to database
        Task {
            do {
                if let dbManager = libraryManager?.databaseManager {
                    try await dbManager.savePlaylistAsync(newPlaylist)
                }
            } catch {
                print("PlaylistManager: Failed to save new playlist: \(error)")
            }
        }

        return newPlaylist
    }

    func deletePlaylist(_ playlist: Playlist) {
        guard playlist.isUserEditable else {
            print("Cannot delete system playlist: \(playlist.name)")
            return
        }

        playlists.removeAll { $0.id == playlist.id }

        guard let dbManager = libraryManager?.databaseManager else { return }

        Task {
            do {
                // Remove the playlist from pinned items
                await handlePlaylistDeletionForPinnedItems(playlist.id)
                
                // Remove the playlist from db
                try await dbManager.deletePlaylist(playlist.id)
            } catch {
                print("Failed to delete playlist from database: \(error)")
            }
        }
    }

    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard playlist.isUserEditable else {
            print("Cannot rename system playlist: \(playlist.name)")
            return
        }

        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.name = newName
            updatedPlaylist.dateModified = Date()
            playlists[index] = updatedPlaylist

            // Save to database
            Task {
                do {
                    if let dbManager = libraryManager?.databaseManager {
                        try await dbManager.savePlaylistAsync(updatedPlaylist)
                    }
                } catch {
                    print("Failed to save renamed playlist: \(error)")
                }
            }
        }
    }

    internal func sortPlaylists(smart: [Playlist], regular: [Playlist]) -> [Playlist] {
        let smartPlaylistOrder: [SmartPlaylistType] = [.favorites, .mostPlayed, .recentlyPlayed]

        let sortedSmartPlaylists = smart.sorted { playlist1, playlist2 in
            guard let type1 = playlist1.smartType,
                  let type2 = playlist2.smartType else {
                return false
            }

            let index1 = smartPlaylistOrder.firstIndex(of: type1) ?? Int.max
            let index2 = smartPlaylistOrder.firstIndex(of: type2) ?? Int.max

            return index1 < index2
        }

        let sortedRegularPlaylists = regular.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return sortedSmartPlaylists + sortedRegularPlaylists
    }
}
