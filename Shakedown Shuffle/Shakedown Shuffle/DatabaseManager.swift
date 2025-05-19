import Foundation
import OSLog

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var showCategories: ShowCategoriesModel?
    private var enrichedShows: EnrichedShowsData?
    
    private init() {}
    
    func loadData() async throws {
        logger.info("Starting data load...")
        
        // Load show categories
        if let categoriesURL = Bundle.main.url(forResource: "show_categories", withExtension: "json") {
            logger.info("Found show_categories.json in bundle")
            let data = try Data(contentsOf: categoriesURL)
            showCategories = try ShowCategoriesModel(data: data)
            logger.info("Loaded show categories: \(showCategories?.categories.byYear.count ?? 0) years")
        } else {
            // Try loading from the project directory
            let projectPath = Bundle.main.bundlePath
            let categoriesPath = (projectPath as NSString).deletingLastPathComponent + "/show_categories.json"
            logger.info("Looking for show_categories.json at: \(categoriesPath)")
            let data = try Data(contentsOf: URL(fileURLWithPath: categoriesPath))
            showCategories = try ShowCategoriesModel(data: data)
            logger.info("Loaded show categories from project directory")
        }
        
        // Load enriched shows
        if let enrichedURL = Bundle.main.url(forResource: "enriched_shows", withExtension: "json") {
            logger.info("Found enriched_shows.json in bundle")
            let data = try Data(contentsOf: enrichedURL)
            enrichedShows = try JSONDecoder().decode(EnrichedShowsData.self, from: data)
            logger.info("Loaded enriched shows: \(enrichedShows?.bestShows.count ?? 0) shows")
        } else {
            // Try loading from the project directory
            let projectPath = Bundle.main.bundlePath
            let enrichedPath = (projectPath as NSString).deletingLastPathComponent + "/enriched_shows.json"
            logger.info("Looking for enriched_shows.json at: \(enrichedPath)")
            let data = try Data(contentsOf: URL(fileURLWithPath: enrichedPath))
            enrichedShows = try JSONDecoder().decode(EnrichedShowsData.self, from: data)
            logger.info("Loaded enriched shows from project directory")
        }
        
        guard enrichedShows != nil else {
            throw DatabaseError.fileNotFound("enriched_shows.json")
        }
    }
    
    // MARK: - Accessor Methods
    
    func getShowCategories() -> ShowCategoriesModel? {
        return showCategories
    }
    
    func getShow(forDate date: String) -> EnrichedShow? {
        // First try exact match (for backward compatibility)
        if let show = enrichedShows?.bestShows[date] {
            return show
        }
        // Try finding by date prefix
        return enrichedShows?.bestShows.values.first { $0.identifier.contains(date) }
    }
    
    func getAllShows() -> [String: EnrichedShow]? {
        // Convert to use full identifiers as keys
        guard let shows = enrichedShows?.bestShows else { return nil }
        return Dictionary(uniqueKeysWithValues: shows.values.map { ($0.identifier, $0) })
    }
    
    // MARK: - Category Methods
    
    func getNotablePerformances() -> [String: [String]]? {
        return showCategories?.categories.notablePerformances
    }
    
    func getSpecialShows() -> SpecialShows? {
        return showCategories?.categories.specialShows
    }
    
    func getShowsByRating() -> ByRating? {
        return showCategories?.categories.byRating
    }
    
    func getShowsByEra() -> ByEra? {
        return showCategories?.categories.byEra
    }
    
    func getShowsByVenue() -> ByIconicVenue? {
        return showCategories?.categories.byIconicVenue
    }
    
    func getShowsByVenueType() -> ByVenueType? {
        return showCategories?.categories.byVenueType
    }
    
    func getShowsByRecording() -> ByRecording? {
        return showCategories?.categories.byRecording
    }
    
    func getShowsByRegion() -> ByRegion? {
        return showCategories?.categories.byRegion
    }
    
    func getShowsByState() -> [String: [String]]? {
        return showCategories?.categories.byState
    }
    
    func getShowsBySeason() -> BySeason? {
        return showCategories?.categories.bySeason
    }
    
    func getShowsByDecade() -> [String: [String]]? {
        return showCategories?.categories.byDecade
    }
    
    func getShowsByYear() -> [String: [String]]? {
        return showCategories?.categories.byYear
    }
    
    func getShowsByMonth() -> [String: [String]]? {
        return showCategories?.categories.byMonth
    }
    
    func getRandomShow() -> EnrichedShow? {
        guard let allShows = getAllShows() else { return nil }
        let allDates = Array(allShows.keys)
        guard let randomDate = allDates.randomElement() else { return nil }
        return allShows[randomDate]
    }
    
    func getTodaysShow() -> EnrichedShow? {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let todayMMDD = formatter.string(from: today)
        
        // Try to find a show from any year on this date
        guard let shows = getAllShows() else { return nil }
        
        // Look for shows with this MM-DD pattern
        let todaysShows = shows.values.filter { show in
            // Extract MM-DD from show identifier (which starts with YYYY-MM-DD)
            let startIndex = show.identifier.index(show.identifier.startIndex, offsetBy: 5)
            let endIndex = show.identifier.index(show.identifier.startIndex, offsetBy: 10)
            let showMMDD = String(show.identifier[startIndex..<endIndex])
            return showMMDD == todayMMDD
        }
        
        // Return a random show from today's date if multiple exist
        return todaysShows.randomElement()
    }
}

// MARK: - Errors

enum DatabaseError: Error {
    case fileNotFound(String)
    case dataCorrupted
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound(let filename):
            return "Could not find \(filename) in the app bundle"
        case .dataCorrupted:
            return "The data file is corrupted"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 