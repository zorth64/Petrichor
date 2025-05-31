import SwiftUI

extension Notification.Name {
    static let goToLibraryFilter = Notification.Name("GoToLibraryFilter")
}

struct TrackContextMenu {
    static func createMenuItems(
        for track: Track,
        audioPlayerManager: AudioPlayerManager,
        playlistManager: PlaylistManager,
        currentContext: MenuContext
    ) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        // Play
        items.append(.button(title: "Play") {
            switch currentContext {
            case .library:
                // We don't have the filtered tracks here, so just play the single track
                playlistManager.playTrack(track, fromTracks: [track])
            case .folder(let folder):
                // For context menu, we create a minimal queue
                playlistManager.playTrackFromFolder(track, folder: folder, folderTracks: [track])
            case .playlist(let playlist):
                if let index = playlist.tracks.firstIndex(of: track) {
                    playlistManager.playTrackFromPlaylist(playlist, at: index)
                }
            }
        })
        
        // Play Next
        items.append(.button(title: "Play Next") {
            playlistManager.playNext(track)
        })
        
        // Add to Queue
        items.append(.button(title: "Add to Queue") {
            playlistManager.addToQueue(track)
        })
        
        // Show Info
        items.append(.button(title: "Show Info") {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowTrackInfo"),
                object: nil,
                userInfo: ["track": track]
            )
        })

        items.append(.divider)
        
        // Go to submenu
        var goToItems: [ContextMenuItem] = []

        for filterType in LibraryFilterType.allCases {
            if filterType.usesMultiArtistParsing {
                // Parse the multi-value field
                let value = filterType.getValue(from: track)
                let parsedValues = ArtistParser.parse(value, unknownPlaceholder: filterType.unknownPlaceholder)
                
                if parsedValues.count > 1 {
                    // Multiple values - create submenu
                    var subItems: [ContextMenuItem] = []
                    for parsedValue in parsedValues {
                        subItems.append(.button(title: parsedValue) {
                            NotificationCenter.default.post(
                                name: .goToLibraryFilter,
                                object: nil,
                                userInfo: [
                                    "filterType": filterType,
                                    "filterValue": parsedValue
                                ]
                            )
                        })
                    }
                    goToItems.append(.menu(title: filterType.rawValue, items: subItems))
                } else {
                    // Single value - create direct menu item
                    let displayValue = parsedValues.first ?? filterType.unknownPlaceholder
                    goToItems.append(.button(title: "\(filterType.singularDisplayName): \(displayValue)") {
                        NotificationCenter.default.post(
                            name: .goToLibraryFilter,
                            object: nil,
                            userInfo: [
                                "filterType": filterType,
                                "filterValue": displayValue
                            ]
                        )
                    })
                }
            } else {
                // Non-parsed fields - direct menu item
                let value = filterType.getValue(from: track)
                goToItems.append(.button(title: "\(filterType.singularDisplayName): \(value)") {
                    NotificationCenter.default.post(
                        name: .goToLibraryFilter,
                        object: nil,
                        userInfo: [
                            "filterType": filterType,
                            "filterValue": value
                        ]
                    )
                })
            }
        }

        items.append(.menu(title: "Go to", items: goToItems))
        
        items.append(.divider)
        
        // Add to Playlist submenu
        let regularPlaylists = playlistManager.playlists.filter { $0.type == .regular }
        if !regularPlaylists.isEmpty {
            var playlistItems: [ContextMenuItem] = []
            
            for playlist in regularPlaylists {
                // Don't show current playlist in the menu if we're in playlist context
                if case .playlist(let currentPlaylist) = currentContext,
                   currentPlaylist.id == playlist.id {
                    continue
                }
                
                playlistItems.append(.button(title: playlist.name) {
                    playlistManager.addTrackToPlaylist(track: track, playlistID: playlist.id)
                })
            }
            
            if !playlistItems.isEmpty {
                playlistItems.append(.divider)
            }
            
            playlistItems.append(.button(title: "New Playlist...") {
                // This will be handled by the view that uses this menu
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreatePlaylistWithTrack"),
                    object: nil,
                    userInfo: ["track": track]
                )
            })
            
            items.append(.menu(title: "Add to Playlist", items: playlistItems))
        }
        
        // Add/Remove from Favorites
        items.append(.divider)
        items.append(.button(title: track.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            playlistManager.toggleFavorite(for: track)
        })
        
        // Context-specific items
        switch currentContext {
        case .folder:
            items.append(.divider)
            items.append(.button(title: "Show in Finder") {
                NSWorkspace.shared.selectFile(track.url.path, inFileViewerRootedAtPath: track.url.deletingLastPathComponent().path)
            })
            
        case .playlist(let playlist):
            if playlist.type == .regular {
                items.append(.divider)
                items.append(.button(title: "Remove from Playlist", role: .destructive) {
                    playlistManager.removeTrackFromPlaylist(track: track, playlistID: playlist.id)
                })
            }
            
        case .library:
            break
        }
        
        return items
    }
    
    enum MenuContext {
        case library
        case folder(Folder)
        case playlist(Playlist)
    }
}
