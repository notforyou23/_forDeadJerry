import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Combine
import ActivityKit
import Network

@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer? {
        willSet {
            // Remove time observer
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
            }
            // Remove observers for the current player item
            if let currentItem = player?.currentItem {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                currentItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            }
        }
    }
    private var playerItem: AVPlayerItem?
    private var nextPlayerItem: AVPlayerItem?  // For pre-loading next track
    private(set) var currentIndex = 0
    @Published private(set) var currentTrack: Track?
    private var playlist: [URL] = []
    @Published private(set) var trackList: [Track] = []
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAirPlayActive = false
    @Published var isSeekInProgress = false
    
    private var timeObserver: Any?
    private var retryCount = 0
    private let maxRetries = 3
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Queue management
    private var preloadedItems: [Int: AVPlayerItem] = [:]
    private let preloadLimit = 2  // Number of tracks to preload ahead
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.randomdead.networkMonitor")
    @Published private(set) var isNetworkAvailable = true
    @Published private(set) var networkType: NWInterface.InterfaceType = .other
    
    struct ArchiveMetadata: Codable {
        let files: [ArchiveFile]
        let metadata: ShowMetadata?
    }
    
    struct ShowMetadata: Codable {
        let title: String?
        let venue: String?
        let coverage: String?
        let date: String?
    }
    
    struct ArchiveFile: Codable {
        let name: String
        let format: String
        let title: String?
        let length: String?
        let size: String?
        let bitrate: String?
    }
    
    private let historyManager = ShowHistoryManager.shared
    private var currentShow: EnrichedShow?
    
    @Published private(set) var progress: Double = 0
    private var timeObserverToken: Any?
    private var currentActivity: Activity<PlaybackAttributes>?
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
        setupAirPlayRouting()
        setupNetworkMonitoring()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Configure audio session for playback
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            
            // Only activate the session when needed, not during initialization
            // We'll activate it when playback actually starts
            
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
            
            // Add route change observer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
        } catch {
            print("Failed to set up audio session for AirPlay: \(error)")
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
            // Interruption began, save state and pause
            let wasPlaying = isPlaying
            if wasPlaying {
                pause()
                // Save that we were playing before interruption
                UserDefaults.standard.set(true, forKey: "wasPlayingBeforeInterruption")
            }
        case .ended:
            // Interruption ended, check if we should resume
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                // Check if we were playing before interruption
                if UserDefaults.standard.bool(forKey: "wasPlayingBeforeInterruption") {
                    play()
                    UserDefaults.standard.removeObject(forKey: "wasPlayingBeforeInterruption")
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            // New output device (like headphones or bluetooth)
            print("New audio route available")
            // Update AirPlay status
            updateAirPlayStatus()
        case .oldDeviceUnavailable:
            // Output device was removed (like headphones unplugged)
            print("Audio route removed")
            
            // Get previous route info
            guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
            
            // Check if we were using headphones/AirPods before
            let wasUsingHeadphones = previousRoute.outputs.contains { output in
                output.portType == .headphones || 
                output.portType == .bluetoothA2DP || 
                output.portType == .bluetoothHFP
            }
            
            // If headphones were unplugged while playing, pause playback
            if wasUsingHeadphones && isPlaying {
                pause()
            }
            
            // Update AirPlay status
            updateAirPlayStatus()
        case .categoryChange:
            // Audio session category changed
            print("Audio session category changed")
        default:
            break
        }
    }
    
    private func updateAirPlayStatus() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let isAirPlayActive = currentRoute.outputs.contains { output in
            output.portType == .airPlay
        }
        
        Task { @MainActor in
            self.isAirPlayActive = isAirPlayActive
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.currentIndex < self.playlist.count - 1 {
                self.playTrack(at: self.currentIndex + 1)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.currentIndex > 0 {
                self.playTrack(at: self.currentIndex - 1)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { 
                return .commandFailed 
            }
            self.seek(to: event.positionTime)
            return .success
        }
    }
    
    private func setupAirPlayRouting() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    func loadShow(identifier: String, tracks: [Track], show: EnrichedShow) async throws {
        // Stop any existing playback
        player?.pause()
        isPlaying = false
        isLoading = true
        
        self.currentShow = show
        self.trackList = tracks
        self.currentIndex = 0
        self.currentTrack = tracks.first
        
        // Clear existing preloaded items
        preloadedItems.removeAll()
        
        // 1. Get metadata from Archive.org
        let url = URL(string: "https://archive.org/metadata/\(identifier)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        
        // 2. Filter for MP3 files and create playlist URLs immediately
        playlist = metadata.files
            .filter { file in
                (file.format == "VBR MP3" || file.format == "MP3") &&
                !file.name.contains("_vbr") &&
                file.name.hasSuffix(".mp3")
            }
            .sorted { $0.name < $1.name }
            .map { file in
                URL(string: "https://archive.org/download/\(identifier)/\(file.name)")!
            }
        
        // 3. Set up first track with optimized loading
        if let firstTrackURL = playlist.first {
            playerItem = createPlayerItem(with: firstTrackURL)
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
            player?.volume = 1.0
            
            setupTimeObserver()
            setupPlayerObservers()
            updateNowPlayingInfo(metadata: metadata.metadata)
            
            // Preload next tracks in background
            Task.detached(priority: .background) {
                await self.preloadNextTracks()
            }
        }
        
        isLoading = false
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
    
    @objc private func handleEnterBackground() {
        beginBackgroundTask()
        // Ensure audio session stays active
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    @objc private func handleEnterForeground() {
        endBackgroundTask()
        // Refresh audio session
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func preloadNextTracks() async {
        beginBackgroundTask()
        defer { endBackgroundTask() }
        
        // Don't preload if network is unavailable
        guard isNetworkAvailable else {
            print("Network unavailable, skipping preloading")
            return
        }
        
        // Skip preloading on cellular network if we have at least one track preloaded already
        if networkType == .cellular && !preloadedItems.isEmpty {
            print("On cellular network with existing preloaded items, limiting further preloading")
            return
        }
        
        // Preload more tracks ahead
        for offset in 1...preloadLimit {
            let nextIndex = currentIndex + offset
            guard nextIndex < playlist.count else { break }
            
            // Skip if already preloaded
            if preloadedItems[nextIndex] != nil {
                continue
            }
            
            let url = playlist[nextIndex]
            
            // Configure asset options based on network type
            var assetOptions: [String: Any] = [
                "AVURLAssetUsesProtocolCacheKey": true,
                "AVURLAssetPreferPreciseDurationAndTimingKey": false
            ]
            
            if networkType != .wifi {
                // Simpler loading for non-WiFi connections
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-128000"] // Just load the beginning
            } else {
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-"]
            }
            
            let asset = AVURLAsset(url: url, options: assetOptions)
            
            // Start preloading the asset
            Task.detached {
                // Load key asset properties to start buffering
                if #available(iOS 16.0, *) {
                    do {
                        _ = try await asset.load(.isPlayable, .tracks, .duration)
                    } catch {
                        print("Asset loading error: \(error)")
                    }
                } else {
                    // Fallback for older iOS versions
                    do {
                        _ = try await asset.loadValues(forKeys: ["playable", "tracks", "duration"])
                    } catch {
                        print("Preloading error for track \(nextIndex): \(error)")
                    }
                }
            }
            
            let item = AVPlayerItem(asset: asset)
            
            // Configure buffer duration based on network
            if networkType == .wifi {
                item.preferredForwardBufferDuration = 60
            } else {
                item.preferredForwardBufferDuration = 30
            }
            
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            
            await MainActor.run {
                preloadedItems[nextIndex] = item
            }
        }
    }
    
    private func updateNowPlayingInfo(metadata: ShowMetadata?) {
        var nowPlayingInfo = [String: Any]()
        
        if let currentTrack = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.title
        }
        
        if let metadata = metadata {
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Grateful Dead"
            // Remove "Grateful Dead Live at" prefix if present
            let albumTitle = metadata.title?.hasPrefix("Grateful Dead Live at ") == true
                ? String(metadata.title!.dropFirst("Grateful Dead Live at ".count))
                : (metadata.title ?? "Live at \(metadata.venue ?? "")")
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        
        // Add app icon as artwork
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { _ in appIcon }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfo() {
        guard let currentTrack = currentTrack,
              let show = currentShow else { return }
        
        var nowPlayingInfo = [String: Any]()
        
        // Basic track info
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Grateful Dead"
        
        // Remove "Grateful Dead Live at" prefix if present
        let albumTitle = show.metadata.title.hasPrefix("Grateful Dead Live at ") 
            ? String(show.metadata.title.dropFirst("Grateful Dead Live at ".count))
            : show.metadata.title
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        
        // Add app icon as artwork
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { _ in appIcon }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Timing info
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupTimeObserver() {
        // Remove any existing observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Only update if we're not in the middle of a seek
                if !self.isSeekInProgress {
                    let newTime = time.seconds
                    self.currentTime = newTime
                    
                    if let duration = self.player?.currentItem?.duration.seconds, 
                       duration.isFinite && duration > 0 {
                        self.duration = duration
                        self.progress = newTime / duration
                    }
                    
                    // Update now playing info
                    self.updateNowPlayingInfo(metadata: nil)
                }
            }
        }
    }
    
    @available(iOS 16.1, *)
    private func updateLiveActivity() async {
        // Check if Live Activities are supported on this device
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let currentTrack = currentTrack,
              let show = currentShow else { return }
        
        let state = PlaybackAttributes.ContentState(
            trackTitle: currentTrack.title,
            showTitle: show.metadata.title,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            progress: progress
        )
        
        if let activity = currentActivity {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            } else {
                // Fallback for iOS 16.1
                await activity.update(using: state)
            }
        } else {
            // Only try to create a new activity if we haven't failed before
            do {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: state, staleDate: nil)
                    currentActivity = try await Activity<PlaybackAttributes>.request(
                        attributes: PlaybackAttributes(),
                        content: content,
                        pushType: nil
                    )
                } else {
                    // Fallback for iOS 16.1
                    currentActivity = try Activity<PlaybackAttributes>.request(
                        attributes: PlaybackAttributes(),
                        contentState: state,
                        pushType: nil
                    )
                }
            } catch {
                // Only log the error once when trying to create
                if error._domain != "com.apple.activitykit.error" || 
                   error._code != 1 { // Don't log unsupportedTarget
                    print("Error starting live activity: \(error)")
                }
                currentActivity = nil
            }
        }
    }
    
    private func setupPlayerObservers() {
        guard let playerItem = player?.currentItem else { return }
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem)
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        print("playerItemDidPlayToEndTime called for track at index \(currentIndex)")
        Task { @MainActor in
            if let currentShow = currentShow {
                if currentIndex == playlist.count - 1 {
                    // Last track finished
                    historyManager.markShowAsCompleted(currentShow)
                    return // Don't try to play next track if we're at the end
                }
            }
            
            if currentIndex < playlist.count - 1 {
                // Move to next track
                currentIndex += 1
                currentTrack = trackList[currentIndex]
                
                if let preloadedItem = preloadedItems[currentIndex] {
                    print("AudioPlayerService: Using preloaded track for auto-advance")
                    player = AVPlayer(playerItem: preloadedItem)
                    preloadedItems.removeValue(forKey: currentIndex)
                } else {
                    print("AudioPlayerService: Loading next track URL: \(playlist[currentIndex])")
                    let asset = AVURLAsset(url: playlist[currentIndex], options: [
                        "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-"],
                        "AVURLAssetUsesProtocolCacheKey": true,
                        "AVURLAssetPreferPreciseDurationAndTimingKey": false
                    ])
                    
                    playerItem = AVPlayerItem(asset: asset)
                    player = AVPlayer(playerItem: playerItem)
                }
                
                player?.automaticallyWaitsToMinimizeStalling = true
                setupTimeObserver()
                setupPlayerObservers()
                play()
                
                // Preload next tracks in background
                Task.detached(priority: .background) {
                    await self.preloadNextTracks()
                }
                
                // Mark show as partial when advancing tracks
                if let currentShow = currentShow {
                    historyManager.markShowAsPartial(currentShow)
                }
            }
        }
    }
    
    func loadTracks(_ tracks: [Track]) {
        // Stop any existing playback
        player?.pause()
        isPlaying = false
        isLoading = true
        
        self.trackList = tracks
        self.currentIndex = 0
        self.currentTrack = tracks.first
        
        // Create playlist by constructing Archive.org URLs
        if let identifier = currentShow?.identifier {
            self.playlist = tracks.map { track in
                URL(string: "https://archive.org/download/\(identifier)/\(track.filename)")!
            }
        } else {
            // If no identifier is available, we can't create the URLs
            print("AudioPlayerService: Error - No show identifier available to create URLs")
            self.playlist = []
        }
        
        // Clear existing preloaded items
        preloadedItems.removeAll()
        
        isLoading = false
    }
    
    func loadTrack(at index: Int) {
        print("Loading track at index \(index)")
        guard index >= 0 && index < playlist.count else {
            print("AudioPlayerService: Invalid track index")
            return
        }
        
        Task { @MainActor in
            isLoading = true
            self.currentIndex = index
            self.currentTrack = trackList[index]
            
            if let preloadedItem = preloadedItems[index] {
                print("AudioPlayerService: Using preloaded track")
                player = AVPlayer(playerItem: preloadedItem)
                preloadedItems.removeValue(forKey: index)
            } else {
                print("AudioPlayerService: Loading track URL: \(playlist[index])")
                let asset = AVURLAsset(url: playlist[index], options: [
                    "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-"],
                    "AVURLAssetUsesProtocolCacheKey": true,
                    "AVURLAssetPreferPreciseDurationAndTimingKey": false
                ])
                
                playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                player?.automaticallyWaitsToMinimizeStalling = true
            }
            
            setupTimeObserver()
            setupPlayerObservers()
            
            // Always start loading the next tracks
            await preloadNextTracks()
            
            isLoading = false
        }
    }
    
    func playTrack(at index: Int) {
        print("Playing track at index \(index)")
        guard index >= 0 && index < playlist.count else {
            print("AudioPlayerService: Invalid track index")
            return
        }
        
        Task { @MainActor in
            isLoading = true
            self.currentIndex = index
            self.currentTrack = trackList[index]
            
            if let currentShow = currentShow {
                historyManager.markShowAsPartial(currentShow)
            }
            
            if let preloadedItem = preloadedItems[index] {
                print("AudioPlayerService: Using preloaded track")
                player = AVPlayer(playerItem: preloadedItem)
                preloadedItems.removeValue(forKey: index)
                setupTimeObserver()
                setupPlayerObservers()
                play()
                
                // Preload next tracks
                await preloadNextTracks()
            } else {
                print("AudioPlayerService: Loading track URL: \(playlist[index])")
                let asset = AVURLAsset(url: playlist[index], options: [
                    "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-"],
                    "AVURLAssetUsesProtocolCacheKey": true,
                    "AVURLAssetPreferPreciseDurationAndTimingKey": false
                ])
                
                playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                player?.automaticallyWaitsToMinimizeStalling = true
                setupTimeObserver()
                setupPlayerObservers()
                play()
                
                await preloadNextTracks()
            }
            isLoading = false
        }
    }
    
    @MainActor
    func play() {
        // If Jerry player is active, pause it first (PlayerCoordinator will handle the state update)
        if PlayerCoordinator.shared.getActivePlayerDestination() == .jerry {
            JerryShowViewModel.shared.togglePlayPause()
        }
        
        // Ensure audio session is active before playing
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        guard let player = player else { return }
        
        // Apply a subtle fade-in for smoother start
        player.volume = 0.0
        
        isPlaying = true
        player.play()
        
        // Fade in volume over 0.3 seconds
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
        
        // Update play count and track history
        if let currentTrack = currentTrack {
            print("Playing track: \(currentTrack.title)")
        }
    }
    
    func pause() {
        print("AudioPlayerService: Pausing")
        fadeOutAndPause()
    }
    
    private func fadeOutAndPause() {
        guard let player = player, isPlaying else { return }
        
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
                    
                    // Deactivate audio session if needed to save power
                    if !self.isAirPlayActive { // Keep session active during AirPlay
                        do {
                            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                        } catch {
                            print("Failed to deactivate audio session: \(error)")
                        }
                    }
                    
                    Task { @MainActor in
                        self.updateNowPlayingInfo(metadata: nil)
                    }
                } else {
                    // Gradually reduce volume
                    let newVolume = max(0.0, originalVolume - (volumeDecrement * Float(i)))
                    self.player?.volume = newVolume
                }
            }
        }
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingInfo(metadata: nil)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            DispatchQueue.main.async {
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.retryCount = 0
                    // Start preloading next tracks when current track is ready
                    Task {
                        await self.preloadNextTracks()
                    }
                case .failed:
                    self.isLoading = false
                    self.error = self.playerItem?.error
                    self.handlePlaybackError()
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func handlePlaybackError() {
        print("Handling playback error, retry count: \(retryCount)")
        guard retryCount < maxRetries else {
            error = NSError(domain: "com.randomdead", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to play track after multiple attempts"
            ])
            return
        }
        
        retryCount += 1
        guard currentIndex < playlist.count else { return }
        
        beginBackgroundTask()
        
        let currentURL = playlist[currentIndex]
        let retryDelay = UInt64(retryCount) * 1_000_000_000 // Exponential backoff could be considered
        
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: retryDelay)
                let asset = AVURLAsset(url: currentURL, options: [
                    "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-"],
                    "AVURLAssetUsesProtocolCacheKey": true,
                    "AVURLAssetPreferPreciseDurationAndTimingKey": false
                ])
                
                playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                player?.automaticallyWaitsToMinimizeStalling = true
                setupTimeObserver()
                setupPlayerObservers()
                play()
                
                endBackgroundTask()
            } catch {
                print("Error during playback retry: \(error)")
                endBackgroundTask()
            }
        }
    }
    
    private func createPlayerItem(with url: URL) -> AVPlayerItem {
        // Configure asset loading options based on network type
        var assetOptions: [String: Any] = [
            "AVURLAssetUsesProtocolCacheKey": true,
            "AVURLAssetPreferPreciseDurationAndTimingKey": false
        ]
        
        // Add range header for better network performance
        assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Range": "bytes=0-"]
        
        // Adjust options based on network conditions
        if networkType == .cellular {
            // Conservative settings for cellular networks
            assetOptions["AVURLAssetUsesProtocolCacheKey"] = true
        }
        
        let asset = AVURLAsset(url: url, options: assetOptions)
        
        // Load essential keys asynchronously
        Task.detached {
            // Load key asset properties to start buffering
            if #available(iOS 16.0, *) {
                do {
                    _ = try await asset.load(.isPlayable, .tracks, .duration)
                } catch {
                    print("Asset loading error: \(error)")
                }
            } else {
                // Fallback for older iOS versions
                do {
                    _ = try await asset.loadValues(forKeys: ["playable", "tracks", "duration"])
                } catch {
                    print("Asset loading error: \(error)")
                }
            }
        }
        
        let item = AVPlayerItem(asset: asset)
        
        // Adjust buffer settings based on network type
        if self.networkType == .wifi {
            item.preferredForwardBufferDuration = 60 // Buffer 1 minute ahead on WiFi
        } else {
            item.preferredForwardBufferDuration = 30 // Buffer 30 seconds on other networks
        }
        
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        return item
    }
    
    private func setupSingleTimeObserver() {
        // Remove any existing observer
        removeTimeObserver()
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            Task { @MainActor in
                if !self.isSeekInProgress {
                    let newTime = time.seconds
                    
                    // Update current time
                    self.currentTime = newTime
                    
                    // Update duration if needed
                    if let duration = self.player?.currentItem?.duration.seconds,
                       duration.isFinite {
                        self.duration = duration
                        // Calculate progress
                        self.progress = duration > 0 ? newTime / duration : 0
                    }
                    
                    // Update now playing info
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func setupAirPlayObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // Setup network monitoring to adapt playback behavior
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let isAvailable = path.status == .satisfied
                self.isNetworkAvailable = isAvailable
                
                // Get the network type (cellular, wifi, etc.)
                if let currentInterface = path.availableInterfaces.first {
                    self.networkType = currentInterface.type
                } else {
                    self.networkType = .other
                }
                
                // Adapt buffering strategy based on network type
                self.updateBufferingStrategy()
                
                // Handle network changes during playback
                if !isAvailable && self.isPlaying {
                    // Network lost during playback
                    print("Network connection lost during playback")
                    // No need to pause - let the AVPlayer's buffer play out
                    // Just don't try to preload more tracks
                } else if isAvailable && !self.isPlaying && self.error != nil {
                    // Network regained after an error
                    print("Network regained, attempting to recover playback")
                    self.retryPlayback()
                }
            }
        }
        
        // Start monitoring
        networkMonitor.start(queue: networkQueue)
    }
    
    private func updateBufferingStrategy() {
        // Adjust buffering based on network type
        switch networkType {
        case .cellular:
            // Reduce buffer size on cellular to save data
            player?.automaticallyWaitsToMinimizeStalling = true
        case .wifi:
            // Increase buffer on WiFi for smoother playback
            player?.automaticallyWaitsToMinimizeStalling = true
        default:
            // Default behavior
            player?.automaticallyWaitsToMinimizeStalling = true
        }
    }
    
    private func retryPlayback() {
        guard let currentTrack = currentTrack, error != nil else { return }
        
        // Reset error state
        error = nil
        
        // Retry current track
        if let currentIndex = trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
            playTrack(at: currentIndex)
        }
    }
    
    deinit {
        // Stop network monitoring
        networkMonitor.cancel()
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // Method to set the current show
    func setCurrentShow(_ show: EnrichedShow) {
        self.currentShow = show
    }
    
    // New method to load a track without automatically starting playback
    func loadTrackWithoutPlaying(at index: Int) {
        print("Loading track at index \(index) without playing")
        guard index >= 0 && index < playlist.count else {
            print("AudioPlayerService: Invalid track index")
            return
        }
        
        Task { @MainActor in
            isLoading = true
            self.currentIndex = index
            self.currentTrack = trackList[index]
            
            if let preloadedItem = preloadedItems[index] {
                print("AudioPlayerService: Using preloaded track")
                player = AVPlayer(playerItem: preloadedItem)
                preloadedItems.removeValue(forKey: index)
            } else {
                print("AudioPlayerService: Loading track URL: \(playlist[index])")
                let asset = AVURLAsset(url: playlist[index], options: [
                    "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-"],
                    "AVURLAssetUsesProtocolCacheKey": true,
                    "AVURLAssetPreferPreciseDurationAndTimingKey": false
                ])
                
                playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                player?.automaticallyWaitsToMinimizeStalling = true
            }
            
            setupTimeObserver()
            setupPlayerObservers()
            
            // Ensure the player is paused
            player?.pause()
            isPlaying = false
            
            // Preload next tracks in background
            await preloadNextTracks()
            
            isLoading = false
        }
    }
} 

