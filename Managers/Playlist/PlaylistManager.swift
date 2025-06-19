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
    private var smartPlaylistsInitialized = false
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
        if let favoritesPlaylist = playlists.first(where: { $0.smartType == .favorites }) {
            updateTrackInPlaylist(track: track, playlist: favoritesPlaylist, add: !track.isFavorite)
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
        
    // MARK: - Data Persistence
    
    func loadPlaylists() {
        guard let dbManager = libraryManager?.databaseManager else {
            return
        }
        
        let savedPlaylists = dbManager.loadAllPlaylists()
        
        let savedSmartPlaylists = savedPlaylists.filter { $0.type == .smart }
        let savedRegularPlaylists = savedPlaylists.filter { $0.type == .regular }
        
        if savedSmartPlaylists.isEmpty && !smartPlaylistsInitialized {
            let defaultSmartPlaylists = Playlist.createDefaultSmartPlaylists()
            
            for playlist in defaultSmartPlaylists {
                Task {
                    do {
                        try await dbManager.savePlaylistAsync(playlist)
                    } catch {
                        print("Failed to save default playlist: \(error)")
                    }
                }
            }
            
            playlists = sortPlaylists(smart: defaultSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = true
        } else {
            playlists = sortPlaylists(smart: savedSmartPlaylists, regular: savedRegularPlaylists)
            smartPlaylistsInitialized = !savedSmartPlaylists.isEmpty
        }
        
        updateSmartPlaylists()
    }
}
