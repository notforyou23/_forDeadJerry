import Foundation

// Protocol that any show must implement to track in history
protocol HistoryTrackable: Identifiable {
    var id: String { get }
}

// Extension to make EnrichedShow conform to HistoryTrackable
extension EnrichedShow: HistoryTrackable {
    // EnrichedShow already has an id property via identifier
    var id: String { identifier }
}

// JerryShow already conforms to HistoryTrackable based on its definition

// Unified History Manager to handle both show types
@MainActor
class UnifiedHistoryManager: ObservableObject {
    static let shared = UnifiedHistoryManager()
    
    // Published properties for UI updates
    @Published private(set) var recentDeadShows: [EnrichedShow] = []
    @Published private(set) var favoriteDeadShows: [EnrichedShow] = []
    @Published private(set) var recentJerryShows: [JerryShow] = []
    @Published private(set) var favoriteJerryShows: [JerryShow] = []
    
    // Constants
    private let maxRecentShows = 50
    
    // UserDefaults keys
    private let deadRecentKey = "unifiedHistory_deadRecent"
    private let deadFavoritesKey = "unifiedHistory_deadFavorites"
    private let jerryRecentKey = "unifiedHistory_jerryRecent"
    private let jerryFavoritesKey = "unifiedHistory_jerryFavorites"
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Helper methods for EnrichedShow

    // Since EnrichedShow has immutable properties, we'll use computed properties with UserDefaults
    
    func getLastPlayedDate(for show: EnrichedShow) -> Date? {
        return UserDefaults.standard.object(forKey: "dead_lastPlayed_\(show.identifier)") as? Date
    }
    
    func setLastPlayedDate(_ date: Date?, for show: EnrichedShow) {
        UserDefaults.standard.set(date, forKey: "dead_lastPlayed_\(show.identifier)")
    }
    
    func getPlayCount(for show: EnrichedShow) -> Int {
        return UserDefaults.standard.integer(forKey: "dead_playCount_\(show.identifier)")
    }
    
    func setPlayCount(_ count: Int, for show: EnrichedShow) {
        UserDefaults.standard.set(count, forKey: "dead_playCount_\(show.identifier)")
    }
    
    func isPartiallyPlayed(_ show: EnrichedShow) -> Bool {
        return UserDefaults.standard.bool(forKey: "dead_isPartial_\(show.identifier)")
    }
    
    func setPartiallyPlayed(_ value: Bool, for show: EnrichedShow) {
        UserDefaults.standard.set(value, forKey: "dead_isPartial_\(show.identifier)")
    }
    
    func isCompleted(_ show: EnrichedShow) -> Bool {
        return UserDefaults.standard.bool(forKey: "dead_isCompleted_\(show.identifier)")
    }
    
    func setCompleted(_ value: Bool, for show: EnrichedShow) {
        UserDefaults.standard.set(value, forKey: "dead_isCompleted_\(show.identifier)")
    }
    
    func isFavorite(_ show: EnrichedShow) -> Bool {
        return UserDefaults.standard.bool(forKey: "dead_isFavorite_\(show.identifier)")
    }
    
    func setFavorite(_ value: Bool, for show: EnrichedShow) {
        UserDefaults.standard.set(value, forKey: "dead_isFavorite_\(show.identifier)")
    }
    
    // MARK: - Dead Show History Methods
    
    func addDeadShowToHistory(_ show: EnrichedShow) {
        // Update last played date and increment play count
        setLastPlayedDate(Date(), for: show)
        let playCount = getPlayCount(for: show)
        setPlayCount(playCount + 1, for: show)
        
        // Update recent shows list
        updateRecentDeadShows(with: show)
        
        // Save changes
        saveDeadHistory()
    }
    
    func markDeadShowAsPartial(_ show: EnrichedShow) {
        if !isCompleted(show) {
            setPartiallyPlayed(true, for: show)
            saveDeadHistory()
        }
    }
    
    func markDeadShowAsCompleted(_ show: EnrichedShow) {
        setCompleted(true, for: show)
        setPartiallyPlayed(false, for: show)
        saveDeadHistory()
    }
    
    func toggleDeadShowFavorite(_ show: EnrichedShow) {
        let currentValue = isFavorite(show)
        setFavorite(!currentValue, for: show)
        
        if !currentValue {
            // Add to favorites if not already present
            if !favoriteDeadShows.contains(where: { $0.identifier == show.identifier }) {
                favoriteDeadShows.append(show)
            }
        } else {
            // Remove from favorites
            favoriteDeadShows.removeAll { $0.identifier == show.identifier }
        }
        
        saveDeadHistory()
    }
    
    func isDeadShowFavorite(_ show: EnrichedShow) -> Bool {
        return isFavorite(show)
    }
    
    // MARK: - Jerry Show History Methods
    
    func addJerryShowToHistory(_ show: JerryShow) {
        // For JerryShow, we don't need to use UserDefaults as the properties are mutable
        // Update its copy in our collections
        
        var updatedShow = getUpdatedJerryShow(show)
        updatedShow.lastPlayedDate = Date()
        updatedShow.playCount += 1
        
        // Update the show in memory and update collections
        updateJerryShow(updatedShow)
        
        // Update recent shows list
        updateRecentJerryShows(with: updatedShow)
        
        // Save changes
        saveJerryHistory()
    }
    
    func markJerryShowAsPartial(_ show: JerryShow) {
        var updatedShow = getUpdatedJerryShow(show)
        if !updatedShow.isCompleted {
            updatedShow.isPartiallyPlayed = true
            updateJerryShow(updatedShow)
            saveJerryHistory()
        }
    }
    
    func markJerryShowAsCompleted(_ show: JerryShow) {
        var updatedShow = getUpdatedJerryShow(show)
        updatedShow.isCompleted = true
        updatedShow.isPartiallyPlayed = false
        updateJerryShow(updatedShow)
        saveJerryHistory()
    }
    
    func toggleJerryShowFavorite(_ show: JerryShow) {
        var updatedShow = getUpdatedJerryShow(show)
        updatedShow.isFavorite.toggle()
        
        updateJerryShow(updatedShow)
        
        if updatedShow.isFavorite {
            // Add to favorites if not already present
            if !favoriteJerryShows.contains(where: { $0.id == updatedShow.id }) {
                favoriteJerryShows.append(updatedShow)
            }
        } else {
            // Remove from favorites
            favoriteJerryShows.removeAll { $0.id == updatedShow.id }
        }
        
        saveJerryHistory()
    }
    
    func isJerryShowFavorite(_ show: JerryShow) -> Bool {
        return getUpdatedJerryShow(show).isFavorite
    }
    
    // Helper method to get the most up-to-date copy of a JerryShow
    private func getUpdatedJerryShow(_ show: JerryShow) -> JerryShow {
        // Try to find the show in our collections first
        if let existingShow = recentJerryShows.first(where: { $0.id == show.id }) {
            return existingShow
        }
        return show
    }
    
    // Helper method to update a JerryShow in our collections
    private func updateJerryShow(_ show: JerryShow) {
        // Update in recent shows if present
        if let index = recentJerryShows.firstIndex(where: { $0.id == show.id }) {
            recentJerryShows[index] = show
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateRecentDeadShows(with show: EnrichedShow) {
        // Remove the show if it already exists in the list
        recentDeadShows.removeAll { $0.identifier == show.identifier }
        
        // Add the show to the front of the list
        recentDeadShows.insert(show, at: 0)
        
        // Trim the list if it exceeds the maximum size
        if recentDeadShows.count > maxRecentShows {
            recentDeadShows = Array(recentDeadShows.prefix(maxRecentShows))
        }
    }
    
    private func updateRecentJerryShows(with show: JerryShow) {
        // Remove the show if it already exists in the list
        recentJerryShows.removeAll { $0.id == show.id }
        
        // Add the show to the front of the list
        recentJerryShows.insert(show, at: 0)
        
        // Trim the list if it exceeds the maximum size
        if recentJerryShows.count > maxRecentShows {
            recentJerryShows = Array(recentJerryShows.prefix(maxRecentShows))
        }
    }
    
    private func loadHistory() {
        loadDeadHistory()
        loadJerryHistory()
    }
    
    private func loadDeadHistory() {
        // Load recent shows
        if let data = UserDefaults.standard.data(forKey: deadRecentKey),
           let recentIds = try? JSONDecoder().decode([String].self, from: data) {
            // Load the actual shows from identifiers
            recentDeadShows = recentIds.compactMap { id in
                DatabaseManager.shared.getShow(forDate: id)
            }
        }
        
        // Load favorite shows
        if let data = UserDefaults.standard.data(forKey: deadFavoritesKey),
           let favoriteIds = try? JSONDecoder().decode([String].self, from: data) {
            // Load the actual shows from identifiers
            favoriteDeadShows = favoriteIds.compactMap { id in
                DatabaseManager.shared.getShow(forDate: id)
            }
        }
    }
    
    private func loadJerryHistory() {
        // Load recent shows
        if let data = UserDefaults.standard.data(forKey: jerryRecentKey),
           let shows = try? JSONDecoder().decode([JerryShow].self, from: data) {
            recentJerryShows = shows
        }
    }
    
    private func saveDeadHistory() {
        // Save recent show IDs
        let recentIds = recentDeadShows.map { $0.identifier }
        if let data = try? JSONEncoder().encode(recentIds) {
            UserDefaults.standard.set(data, forKey: deadRecentKey)
        }
        
        // Save favorite show IDs
        let favoriteIds = favoriteDeadShows.map { $0.identifier }
        if let data = try? JSONEncoder().encode(favoriteIds) {
            UserDefaults.standard.set(data, forKey: deadFavoritesKey)
        }
    }
    
    private func saveJerryHistory() {
        // Save recent shows
        if let data = try? JSONEncoder().encode(recentJerryShows) {
            UserDefaults.standard.set(data, forKey: jerryRecentKey)
        }
    }
    
    // MARK: - Reset History Methods
    
    func resetJerryHistory() {
        recentJerryShows.removeAll()
        favoriteJerryShows.removeAll()
        
        // Remove all Jerry-related keys from UserDefaults
        UserDefaults.standard.removeObject(forKey: jerryRecentKey)
        UserDefaults.standard.removeObject(forKey: jerryFavoritesKey)
        
        // Save the empty collections
        saveJerryHistory()
        print("🧹 Reset all Jerry history data in UnifiedHistoryManager")
    }
} 
