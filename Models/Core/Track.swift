import Foundation
import GRDB

class Track: Identifiable, ObservableObject, Equatable, FetchableRecord, PersistableRecord {
    let id = UUID()
    var trackId: Int64?  // Database ID
    let url: URL
    
    @Published var title: String
    @Published var artist: String
    @Published var album: String
    @Published var genre: String
    @Published var year: String
    @Published var duration: Double
    @Published var artworkData: Data?
    @Published var isMetadataLoaded: Bool = false
    let format: String
    var folderId: Int64?
    
    // MARK: - Initialization
    
    init(url: URL) {
        self.url = url
        
        // Default values - these will be overridden by metadata
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = "Unknown Album"
        self.genre = "Unknown Genre"
        self.year = "Unknown Year"
        self.duration = 0
        self.format = url.pathExtension
    }
    
    // MARK: - DB Configuration
    
    static let databaseTableName = "tracks"
    
    enum Columns {
        static let trackId = Column("id")
        static let folderId = Column("folder_id")
        static let path = Column("path")
        static let filename = Column("filename")
        static let title = Column("title")
        static let artist = Column("artist")
        static let album = Column("album")
        static let genre = Column("genre")
        static let year = Column("year")
        static let duration = Column("duration")
        static let format = Column("format")
        static let fileSize = Column("file_size")
        static let dateAdded = Column("date_added")
        static let dateModified = Column("date_modified")
        static let artworkData = Column("artwork_data")
    }
    
    // MARK: - FetchableRecord
    
    required init(row: Row) throws {
        trackId = row[Columns.trackId]
        folderId = row[Columns.folderId]
        
        let path: String = row[Columns.path]
        url = URL(fileURLWithPath: path)
        
        title = row[Columns.title] ?? url.deletingPathExtension().lastPathComponent
        artist = row[Columns.artist] ?? "Unknown Artist"
        album = row[Columns.album] ?? "Unknown Album"
        genre = row[Columns.genre] ?? "Unknown Genre"
        year = row[Columns.year] ?? ""
        duration = row[Columns.duration] ?? 0
        format = row[Columns.format] ?? url.pathExtension
        artworkData = row[Columns.artworkData]
        isMetadataLoaded = true
    }
    
    // MARK: - PersistableRecord
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.trackId] = trackId
        container[Columns.folderId] = folderId
        container[Columns.path] = url.path
        container[Columns.filename] = url.lastPathComponent
        container[Columns.title] = title
        container[Columns.artist] = artist
        container[Columns.album] = album
        container[Columns.genre] = genre
        container[Columns.year] = year
        container[Columns.duration] = duration
        container[Columns.format] = format
        container[Columns.dateAdded] = Date()
        container[Columns.artworkData] = artworkData
    }
    
    // Update if exists based on path
    func didInsert(_ inserted: InsertionSuccess) {
        trackId = inserted.rowID
    }
    
    // MARK: - Associations
    
    static let folder = belongsTo(Folder.self)
    
    var folder: QueryInterfaceRequest<Folder> {
        request(for: Track.folder)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
}
