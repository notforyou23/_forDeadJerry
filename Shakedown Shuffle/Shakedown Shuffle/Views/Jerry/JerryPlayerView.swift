import SwiftUI

/// Improved JerryPlayerView with simplified architecture
/// and manual playback control (no autoplay)
struct JerryPlayerView: View {
    let show: JerryShow
    @StateObject private var viewModel = JerryShowViewModel.shared
    @StateObject private var historyManager = UnifiedHistoryManager.shared
    @State private var showingShowDetails = false
    @State private var showingWebView = false
    @State private var selectedURL: URL? = nil
    @State private var selectedTrackIndex: Int? = nil
    @State private var hasLoadedTrack = false
    @State private var showingShowPicker = false
    @State private var navigationPath = NavigationPath()
    
    // Track displayed show
    @State private var displayedShow: JerryShow
    @State private var playingShowID: String? = nil
    
    init(show: JerryShow) {
        self.show = show
        self._displayedShow = State(initialValue: show)
    }
    
    // Simplified playback adapter
    @MainActor
    class PlaybackAdapter: PlaybackController {
        private let viewModel: JerryShowViewModel
        
        init(viewModel: JerryShowViewModel) {
            self.viewModel = viewModel
        }
        
        var isPlaying: Bool { viewModel.isPlaying }
        var progress: Double { viewModel.progress }
        var currentTime: Double { viewModel.progress * duration }
        var duration: Double { viewModel.duration }
        var section: AppSection { .jerry }
        
        func play() {
            if !viewModel.isPlaying {
                viewModel.togglePlayPause()
            }
        }
        
        func pause() {
            if viewModel.isPlaying {
                viewModel.togglePlayPause()
            }
        }
        
        func togglePlayPause() {
            viewModel.togglePlayPause()
        }
        
        func skipForward() {
            Task {
                try? await viewModel.playNextTrack()
            }
        }
        
        func skipBackward() {
            Task {
                try? await viewModel.playPreviousTrack()
            }
        }
        
        func seekForward(seconds: Double) {
            guard duration > 0 else { return }
            let newProgress = min(max(0, progress + (seconds / duration)), 1.0)
            viewModel.seekToPosition(newProgress)
        }
    }
    
    // Simplified track list controller - no autoplay
    @MainActor
    class TrackController: TrackListController {
        private let viewModel: JerryShowViewModel
        var onTrackSelected: ((Int) -> Void)?
        
        init(viewModel: JerryShowViewModel) {
            self.viewModel = viewModel
        }
        
        var section: AppSection { .jerry }
        var currentTrackIndex: Int { viewModel.currentTrackIndex }
        var isPlaying: Bool { viewModel.isPlaying }
        
        func playTrack(at index: Int) {
            Task {
                // Load the track but don't autoplay using our new method
                if viewModel.currentShow?.id != nil {
                    try? await viewModel.loadTrackWithoutPlaying(at: index)
                    
                    // Notify track was selected
                    DispatchQueue.main.async {
                        self.onTrackSelected?(index)
                    }
                }
            }
        }
        
        func togglePlayPause(at index: Int) {
            if currentTrackIndex == index {
                // If this is already the current track, just toggle play/pause
                viewModel.togglePlayPause()
            } else {
                // Otherwise, load and select the track
                playTrack(at: index)
            }
        }
    }
    
    // Get playback adapter
    private var playbackAdapter: PlaybackAdapter {
        PlaybackAdapter(viewModel: viewModel)
    }
    
    // Get track list controller
    private var trackListController: TrackController {
        let controller = TrackController(viewModel: viewModel)
        controller.onTrackSelected = { index in
            self.selectedTrackIndex = index
            self.hasLoadedTrack = true
        }
        return controller
    }
    
    // Get list of shows with audio
    private var showsWithAudio: [JerryShow] {
        return viewModel.filteredShows.filter { $0.audioFiles?.isEmpty == false }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Show Information
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(displayedShow.date)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                
                                if viewModel.isPlaying && viewModel.currentShow?.id == displayedShow.id {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(AppTheme.accentColor(for: .jerry))
                                        .font(.headline)
                                }
                            }
                            
                            Text(displayedShow.venue)
                                .font(.title2)
                                .bold()
                                .foregroundColor(AppTheme.textPrimary)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            
                            Text(displayedShow.location)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            
                            // Show currently playing indicator if different show is playing
                            if viewModel.isPlaying, let currentShow = viewModel.currentShow, currentShow.id != displayedShow.id {
                                Text("Now Playing: \(currentShow.date) - \(currentShow.venue)")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                                    .foregroundColor(.green)
                            }
                            
                            // Action buttons row
                            HStack {
                                Spacer()
                                
                                // External link to jerrygarcia.com
                                if let url = displayedShow.url, !url.isEmpty {
                                    Button(action: {
                                        if let showURL = URL(string: url) {
                                            selectedURL = showURL
                                            showingWebView = true
                                        }
                                    }) {
                                        Image(systemName: "link.circle")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 22))
                                            .padding(8)
                                    }
                                }
                                
                                // Favorite button
                                Button(action: {
                                    viewModel.toggleFavorite(displayedShow)
                                }) {
                                    Image(systemName: viewModel.favoriteShows.contains(where: { $0.id == displayedShow.id }) ? "heart.fill" : "heart")
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
                        if let downloads = displayedShow.sortedAudioFiles, !downloads.isEmpty {
                            // Player controls - only show if this is the current playing show
                            if viewModel.currentShow?.id == displayedShow.id {
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
                            } else if viewModel.isPlaying {
                                // Show a button to switch to this show
                                Button(action: {
                                    loadShow(displayedShow, startPlaying: true)
                                }) {
                                    Text("Play This Show Instead")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(AppTheme.accentColor(for: .jerry))
                                        .cornerRadius(8)
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Track list
                            UnifiedTrackListView(
                                tracks: downloads,
                                controller: trackListController
                            )
                            .padding(.horizontal)
                            .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                        } else {
                            // No audio available message
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text("No audio available for this show")
                            }
                            .foregroundColor(.secondary)
                            .padding()
                            .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                        }
                        
                        // Setlist section
                        if !displayedShow.setlists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Setlist")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(AppTheme.textPrimary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                
                                ForEach(Array(displayedShow.setlists.enumerated()), id: \.offset) { index, set in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Set \(index + 1)")
                                            .font(.headline)
                                            .foregroundColor(AppTheme.textPrimary)
                                            .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                        
                                        ForEach(set, id: \.self) { song in
                                            Text("• \(song)")
                                                .foregroundColor(AppTheme.textSecondary)
                                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                        }
                                    }
                                    .padding(.leading)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        // Notes section
                        if let notes = displayedShow.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(AppTheme.textPrimary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                
                                Text(notes)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .background(
                    RadialGradient(
                        gradient: AppTheme.mainGradient(for: .jerry),
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
                        Text(displayedShow.date)
                            .font(.headline)
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            // Initial setup
            displayedShow = show
            
            // Load the show without autoplaying
            if viewModel.currentShow?.id != show.id {
                loadShow(show, startPlaying: false)
            } else {
                // Already loaded
                hasLoadedTrack = true
            }
        }
        .sheet(isPresented: $showingShowDetails) {
            NavigationView {
                UnifiedShowDetailView(show: displayedShow)
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = selectedURL {
                NavigationView {
                    WebViewContainer(url: url)
                }
            }
        }
        .sheet(isPresented: $showingShowPicker) {
            NavigationView {
                ShowPickerView(
                    shows: showsWithAudio,
                    selectedShow: $displayedShow,
                    onSelectShow: { selectedShow in
                        // Only dismiss the picker if nothing is playing (allows browsing while listening)
                        if !viewModel.isPlaying {
                            showingShowPicker = false
                        }
                        displayedShow = selectedShow
                        
                        // If nothing is playing, load this show
                        if !viewModel.isPlaying {
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
    
    private func loadShow(_ show: JerryShow, startPlaying: Bool) {
        // Update URL for WebView if present
        if let url = show.url, !url.isEmpty, let showURL = URL(string: url) {
            selectedURL = showURL
        }
        
        // If we're already playing something and not starting this show, do nothing
        if viewModel.isPlaying && !startPlaying && viewModel.currentShow?.id != show.id {
            return
        }
        
        // Load the show
        Task {
            // Set the current show
            viewModel.currentShow = show
            
            // Reset track state
            hasLoadedTrack = false
            selectedTrackIndex = nil
            
            // If there are tracks, auto-select the first one
            if let downloads = show.sortedAudioFiles, !downloads.isEmpty {
                if startPlaying {
                    // If we want to start playing, use the original method
                    try? await viewModel.playTrack(at: 0)
                    
                    // Ensure it's playing
                    if !viewModel.isPlaying {
                        viewModel.togglePlayPause()
                    }
                } else {
                    // Use the new method that doesn't trigger playback
                    try? await viewModel.loadTrackWithoutPlaying(at: 0)
                }
                
                selectedTrackIndex = 0
                hasLoadedTrack = true
            }
            
            // Update history when view appears
            historyManager.markJerryShowAsPartial(show)
            historyManager.addJerryShowToHistory(show)
            
            // Update the PlayerCoordinator to ensure it knows this player is active
            PlayerCoordinator.shared.setActivePlayer(.jerry)
        }
    }
}

// Show picker view for selecting different shows
struct ShowPickerView: View {
    let shows: [JerryShow]
    @Binding var selectedShow: JerryShow
    let onSelectShow: (JerryShow) -> Void
    @State private var searchText = ""
    @State private var showYears: [String] = []
    @State private var selectedYear: String = "All"
    
    // Filter shows based on search and year filter
    private var filteredShows: [JerryShow] {
        var filtered = shows
        
        // Filter by year if not "All"
        if selectedYear != "All" {
            filtered = filtered.filter { $0.date.hasPrefix(selectedYear) }
        }
        
        // Filter by search text if not empty
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.date.localizedCaseInsensitiveContains(searchText) ||
                $0.venue.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by date (newest first)
        return filtered.sorted(by: { $0.date > $1.date })
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
                ForEach(filteredShows) { show in
                    Button(action: {
                        selectedShow = show
                        onSelectShow(show)
                    }) {
                        VStack(alignment: .leading) {
                            Text(show.date)
                                .font(.headline)
                            Text(show.venue)
                                .font(.subheadline)
                            Text(show.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Show link indicator if URL exists
                            if let url = show.url, !url.isEmpty {
                                HStack {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text("Has web link")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            // Extract unique years from shows
            let years = Set(shows.compactMap { 
                let components = $0.date.split(separator: "-")
                if components.count > 0 {
                    return String(components[0])
                }
                return nil
            })
            showYears = Array(years).sorted(by: >)
        }
    }
}

#Preview {
    NavigationView {
        JerryPlayerView(show: JerryShow(
            masterData: JerryShowData(
                id: "jgb1980-03-01",
                date: "1980-03-01",
                venue: "Capitol Theatre",
                location: "Passaic, NJ",
                name: "Jerry Garcia Band",
                url: nil,
                setlists: [["Sugaree", "Catfish John"], ["Midnight Moonlight"]],
                notes: "Sample show for preview"
            ),
            folder: "jgb1980-03-01",
            audioFiles: nil
        ))
    }
} 