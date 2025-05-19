import SwiftUI

/// Improved PlayerView with simplified architecture and manual playback control
/// Made to match JerryPlayerView functionality
struct PlayerView: View {
    let show: EnrichedShow?
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    @StateObject private var historyManager = UnifiedHistoryManager.shared
    @State private var showingShowDetails = false
    @State private var selectedTrackIndex: Int? = nil
    @State private var hasLoadedTrack = false
    @State private var showingShowPicker = false
    
    // Track displayed show
    @State private var displayedShow: EnrichedShow?
    
    init(showViewModel: ShowViewModel, audioPlayer: AudioPlayerService) {
        self.showViewModel = showViewModel
        self.audioPlayer = audioPlayer
        self.show = showViewModel.currentShow
        self._displayedShow = State(initialValue: showViewModel.currentShow)
    }
    
    // Create an adapter for unified player controls - simplified like in JerryPlayerView
    @MainActor
    class PlaybackAdapter: PlaybackController {
        private let audioPlayer: AudioPlayerService
        
        init(audioPlayer: AudioPlayerService) {
            self.audioPlayer = audioPlayer
        }
        
        var isPlaying: Bool { audioPlayer.isPlaying }
        var progress: Double { 
            guard audioPlayer.duration > 0 else { return 0 }
            return audioPlayer.currentTime / audioPlayer.duration 
        }
        var currentTime: Double { audioPlayer.currentTime }
        var duration: Double { audioPlayer.duration }
        var section: AppSection { .dead }
        
        func play() {
            if !audioPlayer.isPlaying {
                audioPlayer.play()
            }
        }
        
        func pause() {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            }
        }
        
        func togglePlayPause() {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
        }
        
        func skipForward() {
            // Find the next track based on the current index
            if let currentTrack = audioPlayer.currentTrack, 
               let currentIndex = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
                let nextIndex = min(currentIndex + 1, audioPlayer.trackList.count - 1)
                if nextIndex != currentIndex {
                    audioPlayer.playTrack(at: nextIndex)
                }
            }
        }
        
        func skipBackward() {
            // Find the previous track based on the current index
            if let currentTrack = audioPlayer.currentTrack,
               let currentIndex = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
                let prevIndex = max(currentIndex - 1, 0)
                if prevIndex != currentIndex {
                    audioPlayer.playTrack(at: prevIndex)
                }
            }
        }
        
        func seekForward(seconds: Double) {
            // Calculate new time and ensure it doesn't exceed duration
            let newTime = min(audioPlayer.currentTime + seconds, audioPlayer.duration)
            audioPlayer.seek(to: newTime)
        }
    }
    
    // Simplified track list controller - no autoplay
    @MainActor
    class TrackController: TrackListController {
        private let audioPlayer: AudioPlayerService
        var onTrackSelected: ((Int) -> Void)?
        
        init(audioPlayer: AudioPlayerService) {
            self.audioPlayer = audioPlayer
        }
        
        var section: AppSection { .dead }
        
        var currentTrackIndex: Int {
            guard let currentTrack = audioPlayer.currentTrack,
                  let index = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) else {
                return -1
            }
            return index
        }
        
        var isPlaying: Bool {
            audioPlayer.isPlaying
        }
        
        func playTrack(at index: Int) {
            // Load the track but don't autoplay using our new method
            audioPlayer.loadTrackWithoutPlaying(at: index)
            
            // Notify track was selected
            DispatchQueue.main.async {
                self.onTrackSelected?(index)
            }
        }
        
        func togglePlayPause(at index: Int) {
            if currentTrackIndex == index {
                // If this is already the current track, just toggle play/pause
                if isPlaying {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play()
                }
            } else {
                // Otherwise, load and select the track
                playTrack(at: index)
            }
        }
    }
    
    // Get playback adapter
    private var playbackAdapter: PlaybackAdapter {
        PlaybackAdapter(audioPlayer: audioPlayer)
    }
    
    // Get track list controller
    private var trackListController: TrackController {
        let controller = TrackController(audioPlayer: audioPlayer)
        controller.onTrackSelected = { index in
            self.selectedTrackIndex = index
            self.hasLoadedTrack = true
        }
        return controller
    }
    
    // Get shows with audio
    private var showsWithAudio: [EnrichedShow] {
        guard let allShows = DatabaseManager.shared.getAllShows() else { return [] }
        return allShows.values.filter { !$0.tracks.isEmpty }.sorted(by: { $0.identifier > $1.identifier })
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Show Information
                        if let show = displayedShow {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    let formattedDate = formatShowDate(show.identifier)
                                    Text(formattedDate)
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .appStyle(.basic, color: AppTheme.accentColor(for: .dead))
                                    
                                    if audioPlayer.isPlaying {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(AppTheme.accentColor(for: .dead))
                                            .font(.headline)
                                    }
                                }
                                
                                Text(show.location.venue)
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(AppTheme.textPrimary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .dead))
                                
                                Text("\(show.location.city), \(show.location.state)")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .dead))
                                
                                // Action buttons row
                                HStack {
                                    Spacer()
                                    
                                    // External link to archive.org
                                    if let url = URL(string: "https://archive.org/details/\(show.identifier)") {
                                        Link(destination: url) {
                                            Image(systemName: "link.circle")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 22))
                                                .padding(8)
                                        }
                                    }
                                    
                                    // Favorite button
                                    Button(action: {
                                        historyManager.toggleDeadShowFavorite(show)
                                    }) {
                                        Image(systemName: historyManager.isFavorite(show) ? "heart.fill" : "heart")
                                            .foregroundColor(.red)
                                            .font(.system(size: 22))
                                            .padding(8)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Info button
                                    Button(action: { showingShowDetails = true }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 22))
                                            .padding(8)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Audio Player
                            if !show.tracks.isEmpty {
                                // Player controls - only show if tracks are loaded
                                ResponsiveControlWrapper {
                                    CommonPlayerControls(controller: playbackAdapter)
                                }
                                .padding(.horizontal)
                                .overlay(
                                    Group {
                                        if !hasLoadedTrack {
                                            // Show hint overlay if no track has been loaded yet
                                            Text("Tap a track to select it, then press play")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(8)
                                                .padding(.top, 8)
                                        }
                                    }
                                )
                                
                                // Track list
                                UnifiedTrackListView(
                                    tracks: show.tracks,
                                    controller: trackListController
                                )
                                .padding(.horizontal)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .dead))
                            }
                        }
                        
                        // Add space at the bottom for scrolling
                        Spacer()
                            .frame(height: 30)
                    }
                    .padding(.bottom, 20)
                }
                .background(
                    RadialGradient(
                        gradient: AppTheme.mainGradient(for: .dead),
                        center: .top,
                        startRadius: 0,
                        endRadius: 500
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    // Show a sheet with show selector
                    showingShowPicker = true
                }) {
                    HStack {
                        if let show = displayedShow {
                            Text(formatShowDate(show.identifier))
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text("No Show Selected")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            // Initial setup
            if let currentShow = showViewModel.currentShow {
                displayedShow = currentShow
                
                // Check if there's already something playing (e.g., Jerry show)
                let activePlayer = PlayerCoordinator.shared.getActivePlayerDestination()
                let isJerryPlaying = activePlayer == .jerry && JerryShowViewModel.shared.isPlaying
                
                if !isJerryPlaying {
                    // Set the current show before loading tracks
                    audioPlayer.setCurrentShow(currentShow)
                    
                    // Just load the tracks without playing
                    if !currentShow.tracks.isEmpty {
                        audioPlayer.loadTracks(currentShow.tracks)
                        
                        // Reset track state
                        hasLoadedTrack = false
                        selectedTrackIndex = nil
                        
                        // Auto-select the first track without playing
                        audioPlayer.loadTrackWithoutPlaying(at: 0)
                        selectedTrackIndex = 0
                        hasLoadedTrack = true
                    }
                }
            }
            
            // Update history when view appears
            if let show = displayedShow {
                // Mark the show as partially played and add to history
                historyManager.markDeadShowAsPartial(show)
                historyManager.addDeadShowToHistory(show)
                
                // Only update the PlayerCoordinator if no other player is active
                if !JerryShowViewModel.shared.isPlaying {
                    PlayerCoordinator.shared.setActivePlayer(.dead)
                }
            }
        }
        .sheet(isPresented: $showingShowDetails) {
            NavigationView {
                if let show = displayedShow {
                    UnifiedShowDetailView(show: show)
                }
            }
        }
        .sheet(isPresented: $showingShowPicker) {
            NavigationView {
                DeadShowPickerView(
                    shows: showsWithAudio,
                    selectedShow: Binding(
                        get: { self.displayedShow },
                        set: { self.displayedShow = $0 }
                    ),
                    onSelectShow: { selectedShow in
                        // Only dismiss the picker if nothing is playing (allows browsing while listening)
                        if !audioPlayer.isPlaying {
                            showingShowPicker = false
                        }
                        displayedShow = selectedShow
                        
                        // If nothing is playing, load this show
                        if !audioPlayer.isPlaying {
                            loadShow(selectedShow, startPlaying: false)
                        }
                    }
                )
                .navigationTitle("Select a Show")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingShowPicker = false
                        }
                    }
                }
            }
        }
    }
    
    private func loadShow(_ show: EnrichedShow, startPlaying: Bool) {
        // Check if Jerry player is currently active and playing
        let isJerryPlaying = PlayerCoordinator.shared.getActivePlayerDestination() == .jerry && 
                             JerryShowViewModel.shared.isPlaying
        
        if isJerryPlaying && !startPlaying {
            // Only update the view model's reference without loading audio
            showViewModel.currentShow = show
            
            // Update history still
            historyManager.markDeadShowAsPartial(show)
            historyManager.addDeadShowToHistory(show)
            return
        }
        
        // Reset track state
        hasLoadedTrack = false
        selectedTrackIndex = nil
        
        // Update the view model and set currentShow in AudioPlayerService
        showViewModel.setShowWithoutPlaying(show)
        audioPlayer.setCurrentShow(show)
        
        // Set tracks in audio player
        if !show.tracks.isEmpty {
            audioPlayer.loadTracks(show.tracks)
            
            // Start playing if requested, otherwise just load the track without playing
            if startPlaying {
                audioPlayer.playTrack(at: 0)
            } else {
                audioPlayer.loadTrackWithoutPlaying(at: 0)
            }
            
            selectedTrackIndex = 0
            hasLoadedTrack = true
        }
        
        // Update history
        historyManager.markDeadShowAsPartial(show)
        historyManager.addDeadShowToHistory(show)
        
        // Update the PlayerCoordinator only if we're actually starting playback or nothing else is playing
        if startPlaying || !isJerryPlaying {
            PlayerCoordinator.shared.setActivePlayer(.dead)
        }
    }
    
    private func formatShowDate(_ identifier: String) -> String {
        // Extract date from identifier (format: gdYY-MM-DD)
        // First ensure we get just the core date part
        let prefix = identifier.hasPrefix("gd") ? 2 : 0
        let dateComponents = identifier.dropFirst(prefix).components(separatedBy: "-")
        
        // Make sure we have at least year, month, day
        if dateComponents.count >= 3 {
            let year = dateComponents[0] 
            let month = dateComponents[1]
            let day = String(dateComponents[2].prefix(2)) // Just take the first 2 chars in case there's more
            
            let dateStr = "\(year)-\(month)-\(day)"
            
            // Parse with the right format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yy-MM-dd"
            
            if let date = dateFormatter.date(from: dateStr) {
                dateFormatter.dateFormat = "MMMM d, yyyy"
                return dateFormatter.string(from: date)
            }
        }
        
        // If parsing failed, at least show a clean version without the prefix
        if identifier.hasPrefix("gd") {
            let dateStr = identifier.dropFirst(2).components(separatedBy: "-").prefix(3).joined(separator: "-")
            return dateStr
        }
        
        return identifier
    }
}

// Show picker view for selecting different shows - mirrors the Jerry implementation
struct DeadShowPickerView: View {
    let shows: [EnrichedShow]
    @Binding var selectedShow: EnrichedShow?
    let onSelectShow: (EnrichedShow) -> Void
    @State private var searchText = ""
    @State private var showYears: [String] = []
    @State private var selectedYear: String = "All"
    
    // Filter shows based on search and year filter
    private var filteredShows: [EnrichedShow] {
        var filtered = shows
        
        // Filter by year if not "All"
        if selectedYear != "All" {
            filtered = filtered.filter { show in
                show.identifier.contains(selectedYear)
            }
        }
        
        // Filter by search text if not empty
        if !searchText.isEmpty {
            filtered = filtered.filter { show in
                let searchString = "\(show.identifier) \(show.metadata.title) \(show.location.venue) \(show.location.city)"
                return searchString.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Sort by date (newest first)
        return filtered.sorted(by: { $0.identifier > $1.identifier })
    }
    
    var body: some View {
        VStack {
            // Year picker
            Picker("Year", selection: $selectedYear) {
                Text("All Years").tag("All")
                ForEach(showYears, id: \.self) { year in
                    Text(year).tag(year)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
            
            // Search field
            TextField("Search shows", text: $searchText)
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Show list
            List {
                ForEach(filteredShows, id: \.identifier) { show in
                    Button(action: {
                        selectedShow = show
                        onSelectShow(show)
                    }) {
                        VStack(alignment: .leading) {
                            Text(formatShowTitle(show))
                                .font(.headline)
                            Text(show.location.venue)
                                .font(.subheadline)
                            Text("\(show.location.city), \(show.location.state)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            // Extract unique years from shows
            let years = Set(shows.compactMap { show in
                if show.identifier.count >= 4 {
                    let start = show.identifier.index(show.identifier.startIndex, offsetBy: 2)
                    let end = show.identifier.index(start, offsetBy: 2)
                    return String(show.identifier[start..<end])
                }
                return nil
            })
            showYears = Array(years).sorted(by: >)
        }
    }
    
    private func formatShowTitle(_ show: EnrichedShow) -> String {
        // Get just the date part, handle longer identifiers
        let prefix = show.identifier.hasPrefix("gd") ? 2 : 0
        let dateComponents = show.identifier.dropFirst(prefix).components(separatedBy: "-")
        
        // Make sure we have at least year, month, day
        if dateComponents.count >= 3 {
            let year = dateComponents[0]
            let month = dateComponents[1] 
            let day = String(dateComponents[2].prefix(2)) // Take first 2 chars in case there's more
            
            // Format as YYYY-MM-DD
            if year.count == 2 {
                return "19\(year)-\(month)-\(day)"
            } else {
                return "\(year)-\(month)-\(day)"
            }
        }
        
        // Fallback to a clean version of the identifier
        if show.identifier.hasPrefix("gd") {
            return show.identifier.dropFirst(2).components(separatedBy: "-").prefix(3).joined(separator: "-")
        }
        
        return show.identifier
    }
}

#Preview {
    NavigationView {
        PlayerView(
            showViewModel: ShowViewModel(),
            audioPlayer: AudioPlayerService.shared
        )
    }
    .preferredColorScheme(.dark)
}
