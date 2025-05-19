import Foundation

@MainActor
class ShowHistoryManager: ObservableObject {
    static let shared = ShowHistoryManager()
    
    @Published private(set) var recentShows: [EnrichedShow] = []
    @Published private(set) var favoriteShows: [EnrichedShow] = []
    @Published var completedShows: Set<String> = [] // Shows listened to in full
    @Published var partialShows: Set<String> = [] // Shows partially listened to
    
    private let maxHistoryItems = 50
    private let userDefaults = UserDefaults.standard
    private let recentShowsKey = "recentShows"
    private let favoriteShowsKey = "favoriteShows"
    private let completedShowsKey = "completedShows"
    private let partialShowsKey = "partialShows"
    
    // Add new properties to cache show lists
    private var completedShowsList: [EnrichedShow] = []
    private var partialShowsList: [EnrichedShow] = []
    
    private init() {
        loadShows()
    }
    
    func addToHistory(_ show: EnrichedShow) {
        print("📝 Adding show to history: \(show.identifier)")
        print("📝 Current recent shows before adding: \(recentShows.map { $0.identifier })")
        
        // Remove if already exists to avoid duplicates
        recentShows.removeAll { $0.identifier == show.identifier }
        print("📝 Recent shows after removing duplicates: \(recentShows.map { $0.identifier })")
        
        // Add to beginning of array
        recentShows.insert(show, at: 0)
        print("📝 Recent shows after inserting new show: \(recentShows.map { $0.identifier })")
        
        // Trim if exceeds max items
        if recentShows.count > maxHistoryItems {
            recentShows = Array(recentShows.prefix(maxHistoryItems))
            print("📝 Trimmed history to \(maxHistoryItems) items")
        }
        
        saveToUserDefaults()
        print("📝 History saved to UserDefaults, final count: \(recentShows.count)")
    }
    
    func toggleFavorite(_ show: EnrichedShow) {
        print("Toggling favorite for show: \(show.identifier)")
        if isFavorite(show) {
            print("Removing from favorites")
            favoriteShows.removeAll { $0.identifier == show.identifier }
        } else {
            print("Adding to favorites")
            favoriteShows.append(show)
        }
        saveToUserDefaults()
        print("Current favorites count: \(favoriteShows.count)")
    }
    
    func isFavorite(_ show: EnrichedShow) -> Bool {
        let result = favoriteShows.contains { $0.identifier == show.identifier }
        print("Checking if show \(show.identifier) is favorite: \(result)")
        return result
    }
    
    func clearHistory() {
        recentShows.removeAll()
        saveToUserDefaults()
    }
    
    func resetStats() {
        print("Resetting all stats...")
        recentShows.removeAll()
        favoriteShows.removeAll()
        completedShows.removeAll()
        partialShows.removeAll()
        completedShowsList = []
        partialShowsList = []
        
        // Clear UserDefaults
        userDefaults.removeObject(forKey: recentShowsKey)
        userDefaults.removeObject(forKey: favoriteShowsKey)
        userDefaults.removeObject(forKey: completedShowsKey)
        userDefaults.removeObject(forKey: partialShowsKey)
        print("All stats have been reset")
    }
    
    func markShowAsCompleted(_ show: EnrichedShow) {
        completedShows.insert(show.identifier)
        partialShows.remove(show.identifier)
        completedShowsList = [] // Clear cache to force refresh
        partialShowsList = [] // Clear cache to force refresh
        saveShowProgress()
    }
    
    func markShowAsPartial(_ show: EnrichedShow) {
        print("Marking show as partial: \(show.identifier)")
        if !completedShows.contains(show.identifier) {
            partialShows.insert(show.identifier)
            print("Added to partial shows. Current count: \(partialShows.count)")
            partialShowsList = [] // Clear cache to force refresh
            saveShowProgress()
            
            // Also add to recent shows history
            addToHistory(show)
            print("Added show to recent history")
        } else {
            print("Show is already marked as completed")
        }
    }
    
    private func saveShowProgress() {
        print("Saving show progress...")
        print("Completed shows: \(completedShows.count)")
        print("Partial shows: \(partialShows.count)")
        userDefaults.set(Array(completedShows), forKey: completedShowsKey)
        userDefaults.set(Array(partialShows), forKey: partialShowsKey)
    }
    
    private func saveToUserDefaults() {
        print("💾 Saving shows to UserDefaults...")
        
        // Save recent shows
        do {
            let recentData = try JSONEncoder().encode(recentShows)
            userDefaults.set(recentData, forKey: recentShowsKey)
            print("💾 Successfully encoded and saved \(recentShows.count) recent shows")
            print("💾 Recent shows saved: \(recentShows.map { $0.identifier })")
        } catch {
            print("❌ Failed to encode recent shows: \(error)")
        }
        
        // Save favorites
        do {
            let favoritesData = try JSONEncoder().encode(favoriteShows)
            userDefaults.set(favoritesData, forKey: favoriteShowsKey)
            print("💾 Successfully encoded and saved \(favoriteShows.count) favorites")
            print("💾 Favorites saved: \(favoriteShows.map { $0.identifier })")
        } catch {
            print("❌ Failed to encode favorites: \(error)")
        }
        
        // Synchronize to ensure data is written
        userDefaults.synchronize()
    }
    
    private func loadShows() {
        print("📂 Loading shows from UserDefaults...")
        
        // Load existing recent and favorite shows
        if let recentData = userDefaults.data(forKey: recentShowsKey) {
            print("📂 Found recent shows data, size: \(recentData.count) bytes")
            do {
                let recentShows = try JSONDecoder().decode([EnrichedShow].self, from: recentData)
                self.recentShows = recentShows
                print("📂 Successfully loaded \(recentShows.count) recent shows")
                recentShows.forEach { show in
                    print("  📄 Loaded recent show: \(show.identifier)")
                }
            } catch {
                print("❌ Failed to decode recent shows: \(error)")
                // Try to recover by removing corrupted data
                userDefaults.removeObject(forKey: recentShowsKey)
                self.recentShows = []
            }
        } else {
            print("⚠️ No recent shows data found in UserDefaults")
            self.recentShows = []
        }
        
        // Load favorites with similar error handling
        if let favoritesData = userDefaults.data(forKey: favoriteShowsKey) {
            print("📂 Found favorites data, size: \(favoritesData.count) bytes")
            do {
                let favoriteShows = try JSONDecoder().decode([EnrichedShow].self, from: favoritesData)
                self.favoriteShows = favoriteShows
                print("📂 Successfully loaded \(favoriteShows.count) favorites")
                favoriteShows.forEach { show in
                    print("  ⭐️ Loaded favorite show: \(show.identifier)")
                }
            } catch {
                print("❌ Failed to decode favorites: \(error)")
                // Try to recover by removing corrupted data
                userDefaults.removeObject(forKey: favoriteShowsKey)
                self.favoriteShows = []
            }
        } else {
            print("⚠️ No favorites data found in UserDefaults")
            self.favoriteShows = []
        }
        
        // Load show progress
        if let completedShows = userDefaults.stringArray(forKey: completedShowsKey) {
            self.completedShows = Set(completedShows)
            print("📂 Loaded \(completedShows.count) completed shows")
            completedShows.forEach { identifier in
                print("  ✅ Loaded completed show: \(identifier)")
            }
        } else {
            print("⚠️ No completed shows found in UserDefaults")
            self.completedShows = []
        }
        
        if let partialShows = userDefaults.stringArray(forKey: partialShowsKey) {
            self.partialShows = Set(partialShows)
            print("📂 Loaded \(partialShows.count) partial shows")
            partialShows.forEach { identifier in
                print("  ⏳ Loaded partial show: \(identifier)")
            }
        } else {
            print("⚠️ No partial shows found in UserDefaults")
            self.partialShows = []
        }
    }
    
    func getCompletedShows() -> [EnrichedShow] {
        print("Getting completed shows...")
        // Cache the completed shows list if not already cached
        if completedShowsList.isEmpty {
            print("Building completed shows list from \(completedShows.count) identifiers")
            if let allShows = DatabaseManager.shared.getAllShows() {
                completedShowsList = completedShows.compactMap { identifier in
                    let show = allShows[identifier]
                    if show == nil {
                        print("Warning: Could not find completed show for identifier: \(identifier)")
                    } else {
                        print("Found completed show: \(identifier)")
                    }
                    return show
                }
            }
            print("Built list with \(completedShowsList.count) shows")
        }
        return completedShowsList
    }
    
    func getPartialShows() -> [EnrichedShow] {
        print("Getting partial shows...")
        print("Current partial shows identifiers: \(partialShows)")
        
        // Cache the partial shows list if not already cached
        if partialShowsList.isEmpty {
            print("Building partial shows list from \(partialShows.count) identifiers")
            if let allShows = DatabaseManager.shared.getAllShows() {
                print("Got all shows from database, count: \(allShows.count)")
                partialShowsList = partialShows.compactMap { identifier in
                    let show = allShows[identifier]
                    if show == nil {
                        print("❌ Could not find partial show for identifier: \(identifier)")
                        print("Available keys in allShows: \(Array(allShows.keys).prefix(5))...")
                    } else {
                        print("✅ Found partial show: \(identifier)")
                    }
                    return show
                }
            } else {
                print("❌ Failed to get shows from database")
            }
            print("Built partial shows list with \(partialShowsList.count) shows")
        } else {
            print("Using cached partial shows list with \(partialShowsList.count) shows")
        }
        return partialShowsList
    }
} 