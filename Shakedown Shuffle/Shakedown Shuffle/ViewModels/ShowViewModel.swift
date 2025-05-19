import Foundation
import Combine

@MainActor
class ShowViewModel: ObservableObject {
    // Add shared singleton instance
    static let shared = ShowViewModel()
    
    @Published var currentShow: EnrichedShow?
    @Published var currentDate: String = ""
    @Published var playTimeInSeconds: Int = 0
    @Published private(set) var isFavorited: Bool = false
    @Published var todaysShows: [EnrichedShow] = []
    @Published var todaysDateString: String = ""
    
    private var playTimer: Timer?
    private let historyManager = ShowHistoryManager.shared
    private let minimumPlayTimeForHistory = 30 // seconds
    
    // Make init public but don't change its implementation
    // This allows creating instances for previews/testing while maintaining the singleton for actual usage
    
    func loadRandomShow() {
        print("Loading random show...")
        guard let show = DatabaseManager.shared.getRandomShow() else {
            print("Failed to get random show from DatabaseManager")
            return
        }
        print("Got random show: \(show.metadata.title)")
        setShow(show)
    }
    
    // Load a random show without auto-playing it
    func loadRandomShowWithoutPlaying() {
        print("Loading random show without auto-play...")
        guard let show = DatabaseManager.shared.getRandomShow() else {
            print("Failed to get random show from DatabaseManager")
            return
        }
        print("Got random show: \(show.metadata.title)")
        setShowWithoutPlaying(show)
    }
    
    func loadTodaysShows() -> [EnrichedShow] {
        print("Loading today's shows...")
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        todaysDateString = formatter.string(from: today)
        
        formatter.dateFormat = "MM-dd"
        let todayMMDD = formatter.string(from: today)
        
        guard let shows = DatabaseManager.shared.getAllShows() else {
            print("Failed to get shows from DatabaseManager")
            return []
        }
        
        // Look for shows with this MM-DD pattern
        let todaysShows = shows.values.filter { show in
            let startIndex = show.identifier.index(show.identifier.startIndex, offsetBy: 5)
            let endIndex = show.identifier.index(show.identifier.startIndex, offsetBy: 10)
            let showMMDD = String(show.identifier[startIndex..<endIndex])
            return showMMDD == todayMMDD
        }
        .sorted { $0.identifier < $1.identifier }
        
        self.todaysShows = todaysShows
        return todaysShows
    }
    
    func loadTodaysShow() {
        let shows = loadTodaysShows()
        if let show = shows.randomElement() {
            setShow(show)
        }
    }
    
    func setShow(_ show: EnrichedShow) {
        stopPlayTimer()
        playTimeInSeconds = 0  // Reset play time when setting new show
        currentShow = show
        currentDate = show.identifier
        isFavorited = historyManager.isFavorite(show)
        print("Set show \(show.identifier), favorite status: \(isFavorited)")
        
        Task {
            do {
                print("Loading show audio...")
                try await AudioPlayerService.shared.loadShow(identifier: show.identifier, tracks: show.tracks, show: show)
                print("Show audio loaded successfully")
                AudioPlayerService.shared.play() // Start playing immediately
                
                // Add to history immediately when playback starts
                historyManager.markShowAsPartial(show)
                print("Show marked as partial and added to history")
                
                startPlayTimer() // Keep timer for other tracking purposes
            } catch {
                print("Error loading show: \(error)")
            }
        }
    }
    
    // Set a show without auto-playing it
    func setShowWithoutPlaying(_ show: EnrichedShow) {
        stopPlayTimer()
        playTimeInSeconds = 0  // Reset play time when setting new show
        currentShow = show
        currentDate = show.identifier
        isFavorited = historyManager.isFavorite(show)
        print("Set show \(show.identifier) without auto-play, favorite status: \(isFavorited)")
        
        Task {
            do {
                print("Loading show audio...")
                try await AudioPlayerService.shared.loadShow(identifier: show.identifier, tracks: show.tracks, show: show)
                print("Show audio loaded successfully")
                // Note: Not starting playback automatically
                
                // Only add to history when actual playback starts, which will happen in the player view
                print("Show loaded but not marked as partial yet")
            } catch {
                print("Error loading show: \(error)")
            }
        }
    }
    
    // Set a show reference only, without loading audio or affecting playback
    // This is useful for browsing while another player is active
    func setShowReferenceOnly(_ show: EnrichedShow) {
        currentShow = show
        currentDate = show.identifier
        isFavorited = historyManager.isFavorite(show)
        print("Set show reference only for \(show.identifier), not affecting playback")
    }
    
    private func startPlayTimer() {
        stopPlayTimer()
        print("🕒 Starting play timer for show tracking")
        
        playTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else {
                print("❌ Timer fired but self is nil")
                return
            }
            
            Task { @MainActor in
                self.playTimeInSeconds += 1
                print("🕒 Play time: \(self.playTimeInSeconds) seconds")
                
                // Add to history after minimum play time
                if self.playTimeInSeconds == self.minimumPlayTimeForHistory,
                   let show = self.currentShow {
                    print("✅ Minimum play time (\(self.minimumPlayTimeForHistory) seconds) reached for show: \(show.identifier)")
                    self.historyManager.addToHistory(show)
                    self.historyManager.markShowAsPartial(show)
                    print("✅ Show marked as partial and added to history")
                }
            }
        }
        print("🕒 Play timer started successfully")
    }
    
    private nonisolated func stopPlayTimer() {
        RunLoop.main.perform { [weak self] in
            Task { @MainActor in
                if let timer = self?.playTimer {
                    timer.invalidate()
                    print("🛑 Play timer stopped")
                }
                self?.playTimer = nil
            }
        }
    }
    
    func toggleFavorite() {
        guard let show = currentShow else { return }
        historyManager.toggleFavorite(show)
        isFavorited = historyManager.isFavorite(show)
    }
    
    deinit {
        stopPlayTimer()
    }
} 