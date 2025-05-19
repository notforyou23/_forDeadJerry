import Foundation
import Combine
import AVFoundation
import MediaPlayer

@MainActor
class JerryShowViewModel: ObservableObject {
    static let shared = JerryShowViewModel()
    
    // MARK: - Published Properties
    @Published private(set) var shows: [JerryShow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var currentShow: JerryShow?
    @Published var isPlaying = false
    @Published var currentTrackIndex: Int = 0
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var showOnlyWithAudio = true  // Changed default to true
    @Published var randomShow: JerryShow? // Store random show for persistence
    
    var filteredShows: [JerryShow] {
        if showOnlyWithAudio {
            return shows.filter { $0.audioFiles?.isEmpty == false }
        }
        return shows
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var audioSession: AVAudioSession { .sharedInstance() }
    private let baseServerURL = "https://randomdead.com"
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var preloadedItems: [Int: AVPlayerItem] = [:]
    private let preloadLimit = 2  // Number of tracks to preload ahead
    
    // UserDefaults keys
    private let recentShowsKey = "jerryRecentShows"
    private let favoriteShowsKey = "jerryFavoriteShows"
    private let completedShowsKey = "jerryCompletedShows"
    private let partialShowsKey = "jerryPartialShows"
    private let maxHistoryItems = 50
    
    // MARK: - Published Properties for History
    @Published private(set) var recentShows: [JerryShow] = []
    @Published private(set) var favoriteShows: [JerryShow] = []
    @Published private(set) var completedShows: Set<String> = []
    @Published private(set) var partialShows: Set<String> = []
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupRemoteControls()
        loadHistory()
    }
    
    // MARK: - Public Methods
    func loadShows() async {
        isLoading = true
        error = nil
        
        do {
            print("🎸 Loading Jerry shows...")
            
            // Load both JSON files
            print("🎸 Loading master jerry data...")
            let masterShows = try await loadMasterJerryData()
            print("🎸 Loaded \(masterShows.count) shows from master data")
            
            print("🎸 Loading show files...")
            let showFiles = try await loadShowFiles()
            print("🎸 Loaded \(showFiles.count) show files")
            
            // Combine the data
            shows = masterShows.map { masterShow in
                if let showFile = showFiles[masterShow.id] {
                    // Create audio files array from the files data
                    let audioFiles = showFile.files.audio.map { filename in
                        JerryAudioFile(
                            name: filename,
                            path: "\(showFile.folder)/\(filename)",
                            songTitle: nil,
                            set: nil,
                            position: nil,
                            trackNumber: nil
                        )
                    }
                    
                    // Create combined show object with audio
                    return JerryShow(
                        masterData: masterShow,
                        folder: showFile.folder,
                        audioFiles: audioFiles
                    )
                } else {
                    // Create show object without audio
                    return JerryShow(
                        masterData: masterShow,
                        folder: "",
                        audioFiles: nil
                    )
                }
            }
            
            let showsWithAudio = shows.filter { $0.audioFiles?.isEmpty == false }
            print("🎸 Successfully combined data:")
            print("  - Total shows: \(shows.count)")
            print("  - Shows with audio: \(showsWithAudio.count)")
            
        } catch {
            self.error = error
            print("❌ Error loading Jerry shows: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // New method to load a track without automatically playing it
    func loadTrackWithoutPlaying(at index: Int) async throws {
        guard let currentShow = currentShow,
              let audioFiles = currentShow.sortedAudioFiles,
              index >= 0 && index < audioFiles.count else {
            return
        }
        
        // Add to history when starting playback
        if index == 0 {
            addToHistory(currentShow)
            markShowAsPartial(currentShow)
        }
        
        let audioFile = audioFiles[index]
        currentTrackIndex = index
        
        // Construct URL using server path for audio only
        let audioURLString = "\(baseServerURL)/recordings/Jerry/Jerry Garcia Shows/\(currentShow.folder)/\(audioFile.name)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
        guard let audioURL = URL(string: audioURLString) else {
            print("❌ Failed to create URL: \(audioURLString)")
            throw URLError(.badURL)
        }
        
        print("🎸 Loading audio from: \(audioURL)")
        print("🎸 Audio file name: \(audioFile.name)")
        print("🎸 Show folder: \(currentShow.folder)")
        if let trackNum = audioFile.extractedTrackNumber {
            print("🎸 Track number: \(trackNum)")
        }
        
        // Remove existing time observer and notification observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Remove existing notification observer
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // Check if we have a preloaded item
        if let preloadedItem = preloadedItems[index] {
            print("Using preloaded item for track \(index)")
            player = AVPlayer(playerItem: preloadedItem)
            preloadedItems.removeValue(forKey: index)
        } else {
            // Create and configure new player
            let isLikelySingleLargeFile = audioFile.name.contains(".mp3") && 
                                        !audioFile.name.contains("track") && 
                                        !audioFile.name.contains("d1t") &&
                                        !audioFile.name.contains("d2t")
            
            // Configure asset options based on file type
            var assetOptions: [String: Any] = [
                "AVURLAssetUsesProtocolCacheKey": true
            ]
            
            if isLikelySingleLargeFile {
                print("🎸 Detected large single file - optimizing for streaming")
                // For large files, enable HTTP live streaming and disable precise duration calculation
                assetOptions["AVURLAssetPreferPreciseDurationAndTimingKey"] = false
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-500000"] // Just get the first part to start playing
            } else {
                // For smaller files, normal loading is fine
                assetOptions["AVURLAssetPreferPreciseDurationAndTimingKey"] = false
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-"]
            }
            
            let asset = AVURLAsset(url: audioURL, options: assetOptions)
            
            let playerItem = AVPlayerItem(asset: asset)
            
            // Configure buffer settings based on file type
            if isLikelySingleLargeFile {
                playerItem.preferredForwardBufferDuration = 15 // Smaller buffer for faster start
                // Enable loading while paused for better stream performance
                playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            } else {
                playerItem.preferredForwardBufferDuration = 30 // Normal buffer for track files
                playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            }
            
            player = AVPlayer(playerItem: playerItem)
        }
        
        // Configure player for improved buffering
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Setup time observer for progress updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration.seconds,
                  duration.isFinite else {
                return
            }
            
            Task { @MainActor in
                self.progress = time.seconds / duration
                self.duration = duration
                
                // Update now playing info periodically
                if time.seconds.truncatingRemainder(dividingBy: 5) < 0.5 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        // Add end of track notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // Activate audio session before playing
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        // Don't auto-start playing or set isPlaying state
        player?.pause()
        
        updateNowPlayingInfo()
        
        // Start preloading next tracks
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await self.preloadNextTracks()
        }
    }
    
    func playShow(_ show: JerryShow) async {
        currentShow = show  // Set current show first
        guard let audioFiles = show.audioFiles, !audioFiles.isEmpty else { return }
        try? await playTrack(at: 0)
    }
    
    func togglePlayPause() {
        // If Grateful Dead player is active, pause it first
        if PlayerCoordinator.shared.getActivePlayerDestination() == .dead {
            AudioPlayerService.shared.pause()
        }
        
        if isPlaying {
            // Fade out and then pause
            fadeOutAndPause()
        } else {
            // Restore volume gradually
            player?.volume = 0.0
            player?.play()
            isPlaying = true
            
            // Fade in volume
            let fadeInDuration = 0.3
            let steps = 10
            let volumeIncrement = 1.0 / Double(steps)
            let timeInterval = fadeInDuration / Double(steps)
            
            for i in 1...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval * Double(i)) { [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    let newVolume = min(1.0, volumeIncrement * Double(i))
                    self.player?.volume = Float(newVolume)
                }
            }
        }
        updateNowPlayingInfo()
    }
    
    private func fadeOutAndPause() {
        guard let player = player else { return }
        
        let originalVolume = player.volume
        let fadeOutDuration = 0.3
        let steps = 10
        let volumeDecrement = originalVolume / Float(steps)
        let timeInterval = fadeOutDuration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval * Double(i)) { [weak self] in
                guard let self = self else { return }
                if i == steps {
                    // On final step, actually pause and update state
                    self.player?.pause()
                    self.isPlaying = false
                    // Reset volume for next play
                    self.player?.volume = originalVolume
                } else {
                    // Gradually reduce volume
                    let newVolume = max(0.0, originalVolume - (volumeDecrement * Float(i)))
                    self.player?.volume = newVolume
                }
            }
        }
    }
    
    func playTrack(at index: Int) async throws {
        guard let currentShow = currentShow,
              let audioFiles = currentShow.sortedAudioFiles,
              index >= 0 && index < audioFiles.count else {
            return
        }
        
        // Add to history when starting playback
        if index == 0 {
            addToHistory(currentShow)
            markShowAsPartial(currentShow)
        }
        
        let audioFile = audioFiles[index]
        currentTrackIndex = index
        
        // Construct URL using server path for audio only
        let audioURLString = "\(baseServerURL)/recordings/Jerry/Jerry Garcia Shows/\(currentShow.folder)/\(audioFile.name)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
        guard let audioURL = URL(string: audioURLString) else {
            print("❌ Failed to create URL: \(audioURLString)")
            throw URLError(.badURL)
        }
        
        print("🎸 Loading audio from: \(audioURL)")
        print("🎸 Audio file name: \(audioFile.name)")
        print("🎸 Show folder: \(currentShow.folder)")
        if let trackNum = audioFile.extractedTrackNumber {
            print("🎸 Track number: \(trackNum)")
        }
        
        // Remove existing time observer and notification observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Remove existing notification observer
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // Check if we have a preloaded item
        if let preloadedItem = preloadedItems[index] {
            print("Using preloaded item for track \(index)")
            player = AVPlayer(playerItem: preloadedItem)
            preloadedItems.removeValue(forKey: index)
        } else {
            // Create and configure new player
            let isLikelySingleLargeFile = audioFile.name.contains(".mp3") && 
                                        !audioFile.name.contains("track") && 
                                        !audioFile.name.contains("d1t") &&
                                        !audioFile.name.contains("d2t")
            
            // Configure asset options based on file type
            var assetOptions: [String: Any] = [
                "AVURLAssetUsesProtocolCacheKey": true
            ]
            
            if isLikelySingleLargeFile {
                print("🎸 Detected large single file - optimizing for streaming")
                // For large files, enable HTTP live streaming and disable precise duration calculation
                assetOptions["AVURLAssetPreferPreciseDurationAndTimingKey"] = false
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-500000"] // Just get the first part to start playing
            } else {
                // For smaller files, normal loading is fine
                assetOptions["AVURLAssetPreferPreciseDurationAndTimingKey"] = false
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-"]
            }
            
            let asset = AVURLAsset(url: audioURL, options: assetOptions)
            
            let playerItem = AVPlayerItem(asset: asset)
            
            // Configure buffer settings based on file type
            if isLikelySingleLargeFile {
                playerItem.preferredForwardBufferDuration = 15 // Smaller buffer for faster start
                // Enable loading while paused for better stream performance
                playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            } else {
                playerItem.preferredForwardBufferDuration = 30 // Normal buffer for track files
                playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            }
            
            player = AVPlayer(playerItem: playerItem)
        }
        
        // Configure player for improved buffering
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Setup time observer for progress updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration.seconds,
                  duration.isFinite else {
                return
            }
            
            Task { @MainActor in
                self.progress = time.seconds / duration
                self.duration = duration
                
                // Update now playing info periodically
                if time.seconds.truncatingRemainder(dividingBy: 5) < 0.5 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        // Add end of track notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // Activate audio session before playing
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        // Start playback with a smooth fade-in
        player?.volume = 0.0
        player?.play()
        isPlaying = true
        
        // Fade in volume
        let fadeInDuration = 0.3
        let steps = 10
        let volumeIncrement = 1.0 / Double(steps)
        let timeInterval = fadeInDuration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval * Double(i)) { [weak self] in
                guard let self = self, self.isPlaying else { return }
                let newVolume = min(1.0, volumeIncrement * Double(i))
                self.player?.volume = Float(newVolume)
            }
        }
        
        updateNowPlayingInfo()
        
        // Start preloading next tracks
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await self.preloadNextTracks()
        }
    }
    
    private func preloadNextTracks() async {
        beginBackgroundTask()
        defer { endBackgroundTask() }
        
        guard let currentShow = currentShow,
              let audioFiles = currentShow.sortedAudioFiles else { return }
        
        for offset in 1...preloadLimit {
            let nextIndex = currentTrackIndex + offset
            guard nextIndex < audioFiles.count else { break }
            
            // Construct URL for the next track
            let audioFile = audioFiles[nextIndex]
            let audioURLString = "\(baseServerURL)/recordings/Jerry/Jerry Garcia Shows/\(currentShow.folder)/\(audioFile.name)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
            guard let audioURL = URL(string: audioURLString) else { continue }
            
            // Determine if it's a large single file
            let isLikelySingleLargeFile = audioFile.name.contains(".mp3") && 
                                       !audioFile.name.contains("track") && 
                                       !audioFile.name.contains("d1t") &&
                                       !audioFile.name.contains("d2t")
            
            // Configure asset options based on file type
            var assetOptions: [String: Any] = [
                "AVURLAssetUsesProtocolCacheKey": true,
                "AVURLAssetPreferPreciseDurationAndTimingKey": false
            ]
            
            if isLikelySingleLargeFile {
                // For large files, just prepare headers without actually loading content
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-50000"]
            } else {
                // For regular track files
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-"]
            }
            
            // Create asset and player item
            let asset = AVURLAsset(url: audioURL, options: assetOptions)
            
            // Start preloading the asset
            Task.detached {
                // Load key asset properties to start buffering
                let keys = ["playable", "tracks"]
                do {
                    // Using the older style API for better compatibility
                    _ = try await asset.loadValues(forKeys: keys)
                } catch {
                    print("Preloading error for track \(nextIndex): \(error)")
                }
            }
            
            let item = AVPlayerItem(asset: asset)
            
            // Configure buffer settings based on file type
            if isLikelySingleLargeFile {
                item.preferredForwardBufferDuration = 15
            } else {
                item.preferredForwardBufferDuration = 30
            }
            
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            
            await MainActor.run {
                preloadedItems[nextIndex] = item
            }
            
            print("Preloaded track at index \(nextIndex)")
        }
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        print("Jerry player track ended, trying to play next track")
        Task {
            // Check if there's a next track available
            guard let currentShow = currentShow,
                  let audioFiles = currentShow.sortedAudioFiles,
                  currentTrackIndex < audioFiles.count - 1 else {
                print("No more tracks to play in this show")
                // Mark show as complete if this was the last track
                if let currentShow = currentShow {
                    markShowAsCompleted(currentShow)
                }
                return
            }
            
            // Play the next track
            print("Auto-advancing to next Jerry track")
            try? await playTrack(at: currentTrackIndex + 1)
        }
    }
    
    func playNextTrack() async throws {
        guard let currentShow = currentShow,
              let audioFiles = currentShow.sortedAudioFiles,
              currentTrackIndex < audioFiles.count - 1 else {
            return
        }
        
        try await playTrack(at: currentTrackIndex + 1)
    }
    
    func playPreviousTrack() async throws {
        guard currentTrackIndex > 0 else { return }
        try await playTrack(at: currentTrackIndex - 1)
    }
    
    // Public method to access the currentShow
    @MainActor
    func getCurrentShow() -> JerryShow? {
        return currentShow
    }
    
    // Method to seek to a specific position in the current track
    func seekToPosition(_ position: Double) {
        guard let player = player, 
              let duration = player.currentItem?.duration.seconds, 
              duration.isFinite else {
            return
        }
        
        let targetTime = CMTime(seconds: position * duration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime) { [weak self] finished in
            if finished {
                // Update now playing info with new position
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadMasterJerryData() async throws -> [JerryShowData] {
        print("🎸 Loading master jerry data from bundle...")
        guard let url = Bundle.main.url(forResource: "full_master_jerry", withExtension: "json") else {
            print("❌ full_master_jerry.json not found in bundle")
            throw NSError(domain: "JerryShowViewModel", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "full_master_jerry.json not found in bundle"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([JerryShowData].self, from: data)
    }
    
    private func loadShowFiles() async throws -> [String: ShowFile] {
        print("🎸 Loading show files from bundle...")
        guard let url = Bundle.main.url(forResource: "show_files", withExtension: "json") else {
            print("❌ show_files.json not found in bundle")
            throw NSError(domain: "JerryShowViewModel", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "show_files.json not found in bundle"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: ShowFile].self, from: data)
    }
    
    private func updateNowPlayingInfo() {
        guard let currentShow = currentShow,
              let audioFiles = currentShow.sortedAudioFiles,
              currentTrackIndex < audioFiles.count else { return }
        
        var nowPlayingInfo = [String: Any]()
        let currentTrack = audioFiles[currentTrackIndex]
        
        // Try to find matching setlist song if available
        var songTitle = currentTrack.songTitle ?? currentTrack.name
        if let trackNum = currentTrack.extractedTrackNumber,
           let setlistSong = findSetlistSong(forTrackNumber: trackNum, in: currentShow) {
            songTitle = setlistSong
        }
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = songTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentShow.name
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "\(currentShow.date) - \(currentShow.venue)"
        
        // Add app icon as artwork
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { _ in appIcon }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Add timing info
        if let player = player {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            if let duration = player.currentItem?.duration.seconds, duration.isFinite {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func findSetlistSong(forTrackNumber trackNum: Int, in show: JerryShow) -> String? {
        var songIndex = 0
        for set in show.setlists {
            for song in set {
                songIndex += 1
                if songIndex == trackNum {
                    return song
                }
            }
        }
        return nil
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Add interruption observer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            
            // Add background/foreground observers
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        } catch {
            print("Failed to setup audio session:", error)
        }
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            if isPlaying {
                player?.pause()
                isPlaying = false
            }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) && !isPlaying {
                player?.play()
                isPlaying = true
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleEnterBackground() {
        beginBackgroundTask()
        // Ensure audio session stays active
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    @objc private func handleEnterForeground() {
        endBackgroundTask()
        // Refresh audio session
        try? audioSession.setActive(true)
    }
    
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.togglePlayPause()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.togglePlayPause()
            }
            return .success
        }
        
        // Skip forward
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task {
                try? await self.playNextTrack()
            }
            return .success
        }
        
        // Skip backward
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task {
                try? await self.playPreviousTrack()
            }
            return .success
        }
        
        // Seek within track
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seekToPosition(event.positionTime / self.duration)
            return .success
        }
    }
    
    // MARK: - History Management
    private func loadHistory() {
        if let recentData = UserDefaults.standard.data(forKey: recentShowsKey),
           let recentShows = try? JSONDecoder().decode([JerryShow].self, from: recentData) {
            self.recentShows = recentShows
            print("📂 Loaded \(recentShows.count) recent Jerry shows")
        }
        
        if let favoritesData = UserDefaults.standard.data(forKey: favoriteShowsKey),
           let favoriteShows = try? JSONDecoder().decode([JerryShow].self, from: favoritesData) {
            self.favoriteShows = favoriteShows
            print("📂 Loaded \(favoriteShows.count) favorite Jerry shows")
        }
        
        if let completedData = UserDefaults.standard.data(forKey: completedShowsKey),
           let completedShows = try? JSONDecoder().decode(Set<String>.self, from: completedData) {
            self.completedShows = completedShows
            print("📂 Loaded \(completedShows.count) completed Jerry shows")
        }
        
        if let partialData = UserDefaults.standard.data(forKey: partialShowsKey),
           let partialShows = try? JSONDecoder().decode(Set<String>.self, from: partialData) {
            self.partialShows = partialShows
            print("📂 Loaded \(partialShows.count) partial Jerry shows")
        }
    }
    
    private func saveHistory() {
        if let recentData = try? JSONEncoder().encode(recentShows) {
            UserDefaults.standard.set(recentData, forKey: recentShowsKey)
        }
        
        if let favoritesData = try? JSONEncoder().encode(favoriteShows) {
            UserDefaults.standard.set(favoritesData, forKey: favoriteShowsKey)
        }
        
        if let completedData = try? JSONEncoder().encode(completedShows) {
            UserDefaults.standard.set(completedData, forKey: completedShowsKey)
        }
        
        if let partialData = try? JSONEncoder().encode(partialShows) {
            UserDefaults.standard.set(partialData, forKey: partialShowsKey)
        }
    }
    
    func addToHistory(_ show: JerryShow) {
        var updatedShow = show
        updatedShow.lastPlayedDate = Date()
        updatedShow.playCount += 1
        
        // Remove if already exists
        recentShows.removeAll { $0.id == show.id }
        
        // Add to beginning
        recentShows.insert(updatedShow, at: 0)
        
        // Trim if needed
        if recentShows.count > maxHistoryItems {
            recentShows = Array(recentShows.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func toggleFavorite(_ show: JerryShow) {
        if let index = favoriteShows.firstIndex(where: { $0.id == show.id }) {
            favoriteShows.remove(at: index)
        } else {
            var updatedShow = show
            updatedShow.isFavorite = true
            favoriteShows.append(updatedShow)
        }
        saveHistory()
    }
    
    func markShowAsCompleted(_ show: JerryShow) {
        completedShows.insert(show.id)
        partialShows.remove(show.id)
        saveHistory()
    }
    
    func markShowAsPartial(_ show: JerryShow) {
        partialShows.insert(show.id)
        saveHistory()
    }
    
    func resetHistory() {
        recentShows.removeAll()
        favoriteShows.removeAll()
        completedShows.removeAll()
        partialShows.removeAll()
        saveHistory()
        print("📂 Reset all Jerry history data")
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
        
        // Ensure background task is ended on the main actor
        Task { @MainActor in
            self.endBackgroundTask()
        }
    }
}

// MARK: - Supporting Types
struct ShowFile: Codable {
    let id: String
    let folder: String
    let files: ShowFiles
}

struct ShowFiles: Codable {
    let audio: [String]
    let metadata: JerryShowMetadata?
} 