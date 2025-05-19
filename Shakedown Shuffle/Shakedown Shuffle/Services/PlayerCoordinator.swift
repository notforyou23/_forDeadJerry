import Foundation
import Combine

// Enum to represent player destination types
enum PlayerDestination {
    case dead
    case jerry
    case youtube
    case none
}

// Coordinator class to manage which player is currently active
@MainActor class PlayerCoordinator: ObservableObject {
    static let shared = PlayerCoordinator()
    
    // Published properties for UI updates
    @Published private(set) var activeDestination: PlayerDestination = .none
    
    // Private properties to store player references
    private var deadPlayer: AudioPlayerService?
    private var jerryPlayer: JerryShowViewModel?
    private var youtubePlayer: YouTubeShowViewModel?
    
    // Subscriptions to track player state
    private var cancellables = Set<AnyCancellable>()
    
    // Initialize with the player services and set up observation
    private init() {
        deadPlayer = AudioPlayerService.shared
        jerryPlayer = JerryShowViewModel.shared
        youtubePlayer = YouTubeShowViewModel.shared
        
        // Observe Dead player state
        deadPlayer?.objectWillChange
            .sink { [weak self] _ in
                self?.updateActivePlayer()
            }
            .store(in: &cancellables)
        
        // Observe Jerry player state
        jerryPlayer?.objectWillChange
            .sink { [weak self] _ in
                self?.updateActivePlayer()
            }
            .store(in: &cancellables)

        // Observe YouTube player state
        youtubePlayer?.objectWillChange
            .sink { [weak self] _ in
                self?.updateActivePlayer()
            }
            .store(in: &cancellables)
    }
    
    // Check if any player is active
    func hasActivePlayer() -> Bool {
        return activeDestination != .none
    }
    
    // Get the current active player destination
    func getActivePlayerDestination() -> PlayerDestination {
        return activeDestination
    }
    
    // Set the active player destination explicitly
    func setActivePlayer(_ destination: PlayerDestination) {
        switch destination {
        case .dead:
            // If switching to Dead, pause Jerry
            if activeDestination == .jerry {
                pauseJerryPlayer()
            } else if activeDestination == .youtube {
                pauseYouTubePlayer()
            }
            activeDestination = .dead

        case .jerry:
            // If switching to Jerry, pause Dead
            if activeDestination == .dead {
                pauseDeadPlayer()
            } else if activeDestination == .youtube {
                pauseYouTubePlayer()
            }
            activeDestination = .jerry

        case .youtube:
            if activeDestination == .dead {
                pauseDeadPlayer()
            } else if activeDestination == .jerry {
                pauseJerryPlayer()
            }
            activeDestination = .youtube

        case .none:
            activeDestination = .none
        }
    }
    
    // Pause the currently active player
    func pauseActivePlayer() {
        switch activeDestination {
        case .dead:
            pauseDeadPlayer()
        case .jerry:
            pauseJerryPlayer()
        case .youtube:
            pauseYouTubePlayer()
        case .none:
            break
        }
    }
    
    // Private methods to control players
    private func pauseDeadPlayer() {
        deadPlayer?.pause()
    }
    
    private func pauseJerryPlayer() {
        jerryPlayer?.togglePlayPause()
        if jerryPlayer?.isPlaying == true {
            jerryPlayer?.togglePlayPause()
        }
    }

    private func pauseYouTubePlayer() {
        youtubePlayer?.stopPlayback()
    }
    
    // Update the active player based on playback state
    private func updateActivePlayer() {
        let isDeadPlaying = deadPlayer?.isPlaying ?? false
        let isJerryPlaying = jerryPlayer?.isPlaying ?? false
        let isYouTubePlaying = youtubePlayer?.isPlaying ?? false
        
        if [isDeadPlaying, isJerryPlaying, isYouTubePlaying].filter({ $0 }).count > 1 {
            // Both are playing - this shouldn't happen, but prioritize the most recently activated one
            if activeDestination == .dead {
                pauseJerryPlayer()
                pauseYouTubePlayer()
            } else if activeDestination == .jerry {
                pauseDeadPlayer()
                pauseYouTubePlayer()
            } else if activeDestination == .youtube {
                pauseDeadPlayer()
                pauseJerryPlayer()
            }
        } else if isDeadPlaying {
            activeDestination = .dead
        } else if isJerryPlaying {
            activeDestination = .jerry
        } else if isYouTubePlaying {
            activeDestination = .youtube
        } else if !isDeadPlaying && !isJerryPlaying && deadPlayer?.currentTrack != nil {
            // Keep Dead as active player even when paused if there's a track loaded
            activeDestination = .dead
        } else if !isDeadPlaying && !isJerryPlaying && jerryPlayer?.currentShow != nil {
            // Keep Jerry as active player even when paused if there's a show loaded
            activeDestination = .jerry
        } else if !isYouTubePlaying && youtubePlayer?.currentShow != nil {
            activeDestination = .youtube
        } else {
            // No active player
            activeDestination = .none
        }
    }
} 