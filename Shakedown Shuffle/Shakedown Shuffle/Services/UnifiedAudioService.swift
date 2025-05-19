import Foundation
import Combine

// Protocol defining a unified interface for audio playback
@MainActor protocol UnifiedAudioPlayable {
    var isPlaying: Bool { get }
    var progress: Double { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var section: AppSection { get }
    var currentTrackTitle: String { get }
    var currentShowInfo: String { get }
    
    func play()
    func pause()
    func togglePlayPause()
    func playTrack(at index: Int)
    func skipToNextTrack()
    func skipToPreviousTrack()
    func seekTo(time: Double)
}

// Unified Audio Service that works with both audio sources
@MainActor
class UnifiedAudioService: ObservableObject {
    static let shared = UnifiedAudioService()
    
    // Reference to the player coordinator
    private let playerCoordinator = PlayerCoordinator.shared
    
    // References to the actual player implementations
    private let deadPlayer = AudioPlayerService.shared
    private let jerryPlayer = JerryShowViewModel.shared
    
    // Adapters for the audio players
    private lazy var deadAudioAdapter = DeadAudioAdapter(player: deadPlayer)
    private lazy var jerryAudioAdapter = JerryAudioAdapter(player: jerryPlayer)
    
    // Subscriptions to track player state
    private var cancellables = Set<AnyCancellable>()
    
    // Private initialization
    private init() {
        setupObservers()
    }
    
    // Get the currently active audio player
    func getActivePlayer() -> UnifiedAudioPlayable? {
        switch playerCoordinator.getActivePlayerDestination() {
        case .dead:
            return deadAudioAdapter
        case .jerry:
            return jerryAudioAdapter
        case .none:
            return nil
        }
    }
    
    // Play the active audio source
    func play() {
        getActivePlayer()?.play()
    }
    
    // Pause the active audio source
    func pause() {
        getActivePlayer()?.pause()
    }
    
    // Toggle play/pause for the active audio source
    func togglePlayPause() {
        getActivePlayer()?.togglePlayPause()
    }
    
    // Play a specific track by index
    func playTrack(at index: Int) {
        getActivePlayer()?.playTrack(at: index)
    }
    
    // Skip to the next track
    func skipToNextTrack() {
        getActivePlayer()?.skipToNextTrack()
    }
    
    // Skip to the previous track
    func skipToPreviousTrack() {
        getActivePlayer()?.skipToPreviousTrack()
    }
    
    // Seek to a specific time in the current track
    func seekTo(time: Double) {
        getActivePlayer()?.seekTo(time: time)
    }
    
    // Setup observers for player changes
    private func setupObservers() {
        // Observe the Dead player
        deadPlayer.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe the Jerry player
        jerryPlayer.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe the player coordinator
        playerCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// Adapter for Dead audio playback
@MainActor
class DeadAudioAdapter: UnifiedAudioPlayable {
    private let player: AudioPlayerService
    
    init(player: AudioPlayerService) {
        self.player = player
    }
    
    var isPlaying: Bool {
        player.isPlaying
    }
    
    var progress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    var currentTime: Double {
        player.currentTime
    }
    
    var duration: Double {
        player.duration
    }
    
    var section: AppSection {
        .dead
    }
    
    var currentTrackTitle: String {
        player.currentTrack?.title ?? "No track playing"
    }
    
    var currentShowInfo: String {
        // Attempt to extract date and venue from the show
        if let currentTrack = player.currentTrack {
            let showIdentifier = currentTrack.filename.prefix(10)
            if let venue = currentTrack.title.components(separatedBy: " - ").first {
                return "\(showIdentifier) - \(venue)"
            }
            // Fallback if venue can't be extracted
            return "\(showIdentifier) - Unknown Venue"
        }
        return "No show playing"
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func playTrack(at index: Int) {
        player.playTrack(at: index)
    }
    
    func skipToNextTrack() {
        // Find the next track based on the current index
        if let currentTrack = player.currentTrack, 
           let currentIndex = player.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
            let nextIndex = min(currentIndex + 1, player.trackList.count - 1)
            if nextIndex != currentIndex {
                player.playTrack(at: nextIndex)
            }
        }
    }
    
    func skipToPreviousTrack() {
        // Find the previous track based on the current index
        if let currentTrack = player.currentTrack,
           let currentIndex = player.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
            let prevIndex = max(currentIndex - 1, 0)
            if prevIndex != currentIndex {
                player.playTrack(at: prevIndex)
            }
        }
    }
    
    func seekTo(time: Double) {
        player.seek(to: time)
    }
}

// Adapter for Jerry audio playback
@MainActor
class JerryAudioAdapter: UnifiedAudioPlayable {
    private let player: JerryShowViewModel
    
    init(player: JerryShowViewModel) {
        self.player = player
    }
    
    var isPlaying: Bool {
        player.isPlaying
    }
    
    var progress: Double {
        player.progress
    }
    
    var currentTime: Double {
        // JerryShowViewModel doesn't expose currentTime directly
        return progress * duration
    }
    
    var duration: Double {
        player.duration
    }
    
    var section: AppSection {
        .jerry
    }
    
    var currentTrackTitle: String {
        // Get the current show and index from the player
        let currentShow = player.getCurrentShow()
        let currentIndex = player.currentTrackIndex
        
        // Check if there are audio files available
        guard let currentShow = currentShow,
              let downloads = currentShow.sortedAudioFiles,
              currentIndex < downloads.count
        else { return "No track playing" }
        
        return downloads[currentIndex].songTitle ?? downloads[currentIndex].name
    }
    
    var currentShowInfo: String {
        // Get the current show from the player
        guard let currentShow = player.getCurrentShow() else {
            return "No show playing"
        }
        
        return "\(currentShow.date) - \(currentShow.venue)"
    }
    
    func play() {
        if !player.isPlaying {
            player.togglePlayPause()
        }
    }
    
    func pause() {
        if player.isPlaying {
            player.togglePlayPause()
        }
    }
    
    func togglePlayPause() {
        player.togglePlayPause()
    }
    
    func playTrack(at index: Int) {
        Task {
            try? await player.playTrack(at: index)
        }
    }
    
    func skipToNextTrack() {
        Task {
            try? await player.playNextTrack()
        }
    }
    
    func skipToPreviousTrack() {
        Task {
            try? await player.playPreviousTrack()
        }
    }
    
    func seekTo(time: Double) {
        // JerryShowViewModel might not support direct seeking
        // This is a placeholder for future implementation
    }
} 