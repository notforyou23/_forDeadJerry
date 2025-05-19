import Foundation

// MARK: - Show Categories Model
struct ShowCategoriesModel: Codable {
    let formatVersion: Int
    let description: String
    let generatedAt: String
    let categories: Categories
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case description
        case generatedAt = "generated_at"
        case categories
    }
    
    init(data: Data) throws {
        do {
            let decoder = JSONDecoder()
            self = try decoder.decode(ShowCategoriesModel.self, from: data)
        } catch {
            print("Error decoding ShowCategoriesModel: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("First 500 characters of JSON: \(String(jsonString.prefix(500)))")
            }
            throw error
        }
    }
}

struct Categories: Codable {
    let notablePerformances: [String: [String]]
    let specialShows: SpecialShows
    let byRating: ByRating
    let byEra: ByEra
    let byIconicVenue: ByIconicVenue
    let byVenueType: ByVenueType
    let byRecording: ByRecording
    let byRegion: ByRegion
    let byState: [String: [String]]
    let bySeason: BySeason
    let byDecade: [String: [String]]
    let byYear: [String: [String]]
    let byMonth: [String: [String]]
    
    enum CodingKeys: String, CodingKey {
        case notablePerformances = "notable_performances"
        case specialShows = "special_shows"
        case byRating = "by_rating"
        case byEra = "by_era"
        case byIconicVenue = "by_iconic_venue"
        case byVenueType = "by_venue_type"
        case byRecording = "by_recording"
        case byRegion = "by_region"
        case byState = "by_state"
        case bySeason = "by_season"
        case byDecade = "by_decade"
        case byYear = "by_year"
        case byMonth = "by_month"
    }
}

struct SpecialShows: Codable {
    private let shows: [String: [String]]
    
    var firstShow: [String] { shows["first_show"] ?? [] }
    var lastShow: [String] { shows["last_show"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        shows = try container.decode([String: [String]].self)
    }
}

struct ByRating: Codable {
    private let ratings: [String: [String]]
    
    var fiveStars: [String] { ratings["5_stars"] ?? [] }
    var fourStars: [String] { ratings["4_stars"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        ratings = try container.decode([String: [String]].self)
    }
}

struct ByEra: Codable {
    private let eras: [String: [String]]
    
    var pigpen: [String] { eras["pigpen"] ?? [] }
    var keith: [String] { eras["keith"] ?? [] }
    var brent: [String] { eras["brent"] ?? [] }
    var vince: [String] { eras["vince"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        eras = try container.decode([String: [String]].self)
    }
}

struct ByIconicVenue: Codable {
    private let venues: [String: [String]]
    
    var fillmore: [String] { venues["fillmore"] ?? [] }
    var winterland: [String] { venues["winterland"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        venues = try container.decode([String: [String]].self)
    }
}

struct ByVenueType: Codable {
    private let types: [String: [String]]
    
    var stadiums: [String] { types["stadiums"] ?? [] }
    var theaters: [String] { types["theaters"] ?? [] }
    var clubs: [String] { types["clubs"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        types = try container.decode([String: [String]].self)
    }
}

struct ByRecording: Codable {
    private let recordings: [String: [String]]
    
    var soundboards: [String] { recordings["soundboards"] ?? [] }
    var audiences: [String] { recordings["audiences"] ?? [] }
    var matrix: [String] { recordings["matrix"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        recordings = try container.decode([String: [String]].self)
    }
}

struct ByRegion: Codable {
    private let regions: [String: [String]]
    
    var northeast: [String] { regions["northeast"] ?? [] }
    var midwest: [String] { regions["midwest"] ?? [] }
    var south: [String] { regions["south"] ?? [] }
    var west: [String] { regions["west"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        regions = try container.decode([String: [String]].self)
    }
}

struct BySeason: Codable {
    private let seasons: [String: [String]]
    
    var spring: [String] { seasons["spring"] ?? [] }
    var summer: [String] { seasons["summer"] ?? [] }
    var fall: [String] { seasons["fall"] ?? [] }
    var winter: [String] { seasons["winter"] ?? [] }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        seasons = try container.decode([String: [String]].self)
    }
}

// MARK: - Computed Best Shows Model
struct ComputedBestShowsModel: Codable {
    let formatVersion: Int
    let description: String
    let generatedAt: String
    let bestShows: [String: BestShow]
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case description
        case generatedAt = "generated_at"
        case bestShows = "best_shows"
    }
    
    init(data: Data) throws {
        do {
            let decoder = JSONDecoder()
            self = try decoder.decode(ComputedBestShowsModel.self, from: data)
        } catch {
            print("Error decoding ComputedBestShowsModel: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("First 500 characters of JSON: \(String(jsonString.prefix(500)))")
            }
            throw error
        }
    }
}

struct BestShow: Codable {
    let identifier: String
    let score: Double
    let location: Location
    let recordingInfo: RecordingInfo
    let showInfo: ShowInfo
    
    enum CodingKeys: String, CodingKey {
        case identifier
        case score
        case location
        case recordingInfo = "recording_info"
        case showInfo = "show_info"
    }
}

struct Location: Codable {
    let venue: String
    let city: String
    let state: String
}

struct RecordingInfo: Codable {
    let sourceType: String
    let avgRating: Double
    let downloads: Int
    let downloadRate: Double
    let numReviews: Int
    let addedDate: String
    
    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case avgRating = "avg_rating"
        case downloads
        case downloadRate = "download_rate"
        case numReviews = "num_reviews"
        case addedDate = "added_date"
    }
}

struct ShowInfo: Codable {
    let numTracks: Int
    let tracks: [Track]
    let setData: SetData
    
    enum CodingKeys: String, CodingKey {
        case numTracks = "num_tracks"
        case tracks
        case setData = "set_data"
    }
}

struct Track: Codable {
    let title: String
    let filename: String
    let length: String
    let trackNumber: Int
    
    enum CodingKeys: String, CodingKey {
        case title, filename, length
        case trackNumber = "track_number"
    }
}

struct SetData: Codable {
    let numSets: Int
    let multipleLocations: Bool
    let setBreaks: SetBreaks
    
    enum CodingKeys: String, CodingKey {
        case numSets = "num_sets"
        case multipleLocations = "multiple_locations"
        case setBreaks = "set_breaks"
    }
}

struct SetBreaks: Codable {
    let long: [String]
    let short: [String]
}

struct EnrichedShowsData: Codable {
    let lastUpdated: String
    let stats: ShowStats
    let bestShows: [String: EnrichedShow]
    
    enum CodingKeys: String, CodingKey {
        case lastUpdated = "last_updated"
        case stats
        case bestShows = "best_shows"
    }
}

struct EnrichedShow: Codable {
    let identifier: String
    let score: Double
    let location: Location
    let recordingInfo: RecordingInfo
    let metadata: ShowMetadata
    let tracks: [Track]
    
    enum CodingKeys: String, CodingKey {
        case identifier, score, location
        case recordingInfo = "recording_info"
        case metadata, tracks
    }
}

struct ShowStats: Codable {
    let progress: ProgressStats
    let performance: PerformanceStats
    let trackStatistics: TrackStats
    let metadataQuality: MetadataQuality
    let errors: [String]
    
    enum CodingKeys: String, CodingKey {
        case progress, performance
        case trackStatistics = "track_statistics"
        case metadataQuality = "metadata_quality"
        case errors
    }
}

struct ProgressStats: Codable {
    let totalShows: Int
    let processedShows: Int
    let completionPercentage: String
    let elapsedTime: String
    let estimatedRemaining: String
    
    enum CodingKeys: String, CodingKey {
        case totalShows = "total_shows"
        case processedShows = "processed_shows"
        case completionPercentage = "completion_percentage"
        case elapsedTime = "elapsed_time"
        case estimatedRemaining = "estimated_remaining"
    }
}

struct PerformanceStats: Codable {
    let showsPerMinute: String
    let successfulFetches: Int
    let failedFetches: Int
    let successRate: String
    
    enum CodingKeys: String, CodingKey {
        case showsPerMinute = "shows_per_minute"
        case successfulFetches = "successful_fetches"
        case failedFetches = "failed_fetches"
        case successRate = "success_rate"
    }
}

struct TrackStats: Codable {
    let totalTracks: Int
    let avgTracksPerShow: String
    let missingDurations: Int
    let missingTitles: Int
    let avgFileSizeMb: String
    
    enum CodingKeys: String, CodingKey {
        case totalTracks = "total_tracks"
        case avgTracksPerShow = "avg_tracks_per_show"
        case missingDurations = "missing_durations"
        case missingTitles = "missing_titles"
        case avgFileSizeMb = "avg_file_size_mb"
    }
}

struct MetadataQuality: Codable {
    let missingSetlists: Int
    let missingNotes: Int
    let missingSources: Int
    let sourceTypes: SourceTypes
    
    enum CodingKeys: String, CodingKey {
        case missingSetlists = "missing_setlists"
        case missingNotes = "missing_notes"
        case missingSources = "missing_sources"
        case sourceTypes = "source_types"
    }
}

struct SourceTypes: Codable {
    let sbd: Int
    let aud: Int
    let matrix: Int
    let other: Int
    
    enum CodingKeys: String, CodingKey {
        case sbd = "SBD"
        case aud = "AUD"
        case matrix = "MATRIX"
        case other = "OTHER"
    }
}

struct ShowMetadata: Codable {
    let title: String
    let collection: [String]
    let source: String?
    let lineage: String?
    let notes: String?
    let setlist: String?
}
