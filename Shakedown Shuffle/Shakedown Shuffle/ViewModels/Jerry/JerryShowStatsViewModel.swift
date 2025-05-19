import Foundation
import Combine

@MainActor
class JerryShowStatsViewModel: ObservableObject {
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var error: Error?
    @Published var totalShows = 0
    @Published var uniqueSongs = 0
    @Published var totalSongPlays = 0
    @Published var songStats: [SongStat] = []
    @Published var searchText = ""
    @Published var sortOption: SortOption = .plays
    
    // Sort options
    enum SortOption: String, CaseIterable, Identifiable {
        case plays = "Times Played"
        case opens = "Show Openers"
        case alpha = "Alphabetical"
        
        var id: String { self.rawValue }
    }
    
    // Song statistics model
    struct SongStat: Identifiable {
        let song: String
        var count: Int
        var openCount: Int
        var occurrences: [SongOccurrence]
        var firstPlayed: String
        var lastPlayed: String
        
        // Computed property for the number of shows the song was played in
        var uniqueShowCount: Int {
            Set(occurrences.map { $0.showId }).count
        }
        
        var id: String { song.lowercased() }
    }
    
    // Model for each song occurrence
    struct SongOccurrence: Identifiable {
        let date: String
        let showId: String // Renamed from 'id' to 'showId' to avoid conflict
        let venue: String
        let location: String
        let url: String?
        let hasAudio: Bool
        
        var id: String { showId } // Using showId for the Identifiable requirement
    }
    
    // Main function to load data and calculate statistics
    func loadStatistics() async {
        isLoading = true
        error = nil
        
        do {
            // Load the JSON data from the file
            guard let url = Bundle.main.url(forResource: "master_jerry_db", withExtension: "json") else {
                throw NSError(domain: "JerryStatsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "master_jerry_db.json file not found"])
            }
            
            let data = try Data(contentsOf: url)
            let shows = try JSONDecoder().decode([JerryShowData].self, from: data)
            
            // Update total shows count
            totalShows = shows.count
            
            // Dictionary to store song statistics
            var stats: [String: SongStat] = [:]
            
            // Iterate through each show and update song stats from setlists
            for show in shows {
                // Use normalized date if available, fallback to raw date
                let showDate = show.normDate ?? show.date
                
                if !show.setlists.isEmpty {
                    // Process each set in the setlist
                    for set in show.setlists {
                        // Iterate with index so we can detect openers
                        for (index, song) in set.enumerated() {
                            let songKey = song.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            
                            if stats[songKey] == nil {
                                stats[songKey] = SongStat(
                                    song: song.trimmingCharacters(in: .whitespacesAndNewlines),
                                    count: 0,
                                    openCount: 0,
                                    occurrences: [],
                                    firstPlayed: showDate,
                                    lastPlayed: showDate
                                )
                            }
                            
                            // Update count
                            stats[songKey]!.count += 1
                            
                            // Add occurrence
                            let occurrence = SongOccurrence(
                                date: showDate,
                                showId: show.id,
                                venue: show.venue,
                                location: show.location,
                                url: show.url,
                                hasAudio: show.setlists.isEmpty == false // Check if show has setlists instead of downloads
                            )
                            stats[songKey]!.occurrences.append(occurrence)
                            
                            // If this song opened a set
                            if index == 0 {
                                stats[songKey]!.openCount += 1
                            }
                            
                            // Update first/last played dates
                            if self.compareDates(showDate, stats[songKey]!.firstPlayed) < 0 {
                                stats[songKey]!.firstPlayed = showDate
                            }
                            if self.compareDates(showDate, stats[songKey]!.lastPlayed) > 0 {
                                stats[songKey]!.lastPlayed = showDate
                            }
                        }
                    }
                }
            }
            
            // Calculate totals
            uniqueSongs = stats.count
            totalSongPlays = stats.values.reduce(0) { $0 + $1.count }
            
            // Convert to array
            songStats = Array(stats.values)
            
        } catch {
            self.error = error
            print("Error loading statistics: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // Helper function to compare dates (assumes dates are in YYYY-MM-DD format)
    private func compareDates(_ a: String, _ b: String) -> Int {
        return a.compare(b).rawValue
    }
    
    // Get filtered songs based on search text and sorting
    var filteredSongs: [SongStat] {
        var songs = songStats
        
        // Filter by search query
        if !searchText.isEmpty {
            songs = songs.filter { $0.song.lowercased().contains(searchText.lowercased()) }
        }
        
        // Sort based on selected option
        switch sortOption {
        case .plays:
            songs.sort { $0.count > $1.count }
        case .opens:
            songs.sort { $0.openCount > $1.openCount }
        case .alpha:
            songs.sort { $0.song < $1.song }
        }
        
        return songs
    }
}

// Extension to JerryShowData for statistics calculations
extension JerryShowData {
    var normDate: String? {
        // Convert from MM/DD/YYYY to YYYY-MM-DD
        let components = date.split(separator: "/")
        if components.count == 3 {
            let month = components[0].count == 1 ? "0\(components[0])" : String(components[0])
            let day = components[1].count == 1 ? "0\(components[1])" : String(components[1])
            let year = components[2]
            return "\(year)-\(month)-\(day)"
        }
        return nil
    }
} 