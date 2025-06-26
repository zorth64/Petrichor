import Foundation

class PlaylistManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var currentQueue: [Track] = []
    @Published var currentQueueIndex: Int = -1
    @Published var currentQueueSource: QueueSource = .library

    enum QueueSource {
        case library
        case folder
        case playlist
    }

    // MARK: - Private/Internal Properties
    private var shuffledIndices: [Int] = []
    internal var libraryManager: LibraryManager?

    // MARK: - Dependencies
    internal weak var audioPlayer: AudioPlayerManager?

    // MARK: - Initialization
    init() {
        // Don't load playlists yet - wait until libraryManager is set
    }

    func setAudioPlayer(_ player: AudioPlayerManager) {
        self.audioPlayer = player
    }

    func setLibraryManager(_ manager: LibraryManager) {
        self.libraryManager = manager
        print("PlaylistManager: Library manager set, loading playlists...")
        loadPlaylists()
    }

    // MARK: - Convenience Methods

    /// Toggle favorite status for a track
    func toggleFavorite(for track: Track) {
        // Simply toggle the favorite status - the system will handle the rest
        Task {
            await updateTrackFavoriteStatus(track: track, isFavorite: !track.isFavorite)
        }
    }

    /// Add track to a specific playlist by ID
    func addTrackToPlaylist(track: Track, playlistID: UUID) {
        if let playlist = playlists.first(where: { $0.id == playlistID }) {
            updateTrackInPlaylist(track: track, playlist: playlist, add: true)
        }
    }

    /// Remove track from a specific playlist by ID
    func removeTrackFromPlaylist(track: Track, playlistID: UUID) {
        if let playlist = playlists.first(where: { $0.id == playlistID }) {
            updateTrackInPlaylist(track: track, playlist: playlist, add: false)
        }
    }
}
