import SwiftUI

struct GratefulDeadLandingView: View {
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    @StateObject private var historyManager = ShowHistoryManager.shared
    @StateObject private var playerCoordinator = PlayerCoordinator.shared
    @State private var searchText = ""
    @State private var showingOnThisDay = false
    @State private var showingRecents = false
    @State private var showingFavorites = false
    @State private var navigateToPlayer = false
    @State private var randomShow: EnrichedShow?
    @State private var showAudioOnly = true
    
    var filteredShows: [EnrichedShow] {
        guard let allShows = DatabaseManager.shared.getAllShows() else { return [] }
        
        var shows = allShows.values.sorted(by: { $0.identifier > $1.identifier })
        
        // Filter for shows with audio if enabled
        if showAudioOnly {
            shows = shows.filter { !$0.tracks.isEmpty }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            shows = shows.filter { show in
                let searchString = "\(show.identifier) \(show.metadata.title) \(show.location.venue) \(show.location.city) \(show.location.state)".lowercased()
                return searchString.contains(searchText.lowercased())
            }
        }
        
        return shows
    }
    
    var body: some View {
        List {
            // Random Show Section
            if let show = randomShow {
                Section(header: Text("Random Show").appStyle(.basic)) {
                    Button(action: {
                        handleShowSelection(show)
                    }) {
                        randomShowRow(for: show)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            // All Shows Section
            Section(header: Text("All Shows (\(filteredShows.count))").appStyle(.basic)) {
                ForEach(filteredShows, id: \.identifier) { show in
                    Button(action: {
                        handleShowSelection(show)
                    }) {
                        ShowRowView(show: show)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search shows")
        .navigationTitle("Grateful Dead")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle(isOn: $showAudioOnly) {
                        Label("Shows with Audio", systemImage: "music.note")
                    }
                    
                    Divider()
                    
                    Button(action: { showingRecents = true }) {
                        Label("Recent Shows", systemImage: "clock")
                    }
                    Button(action: { showingFavorites = true }) {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    Button(action: { showingOnThisDay = true }) {
                        Label("On This Day", systemImage: "calendar")
                    }
                    
                    Divider()
                    
                    Button(action: loadNewRandomShow) {
                        Label("New Random Show", systemImage: "shuffle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingOnThisDay) {
            NavigationStack {
                UnifiedShowsOnThisDayView(showViewModel: showViewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { showingOnThisDay = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecents) {
            ShowListView(
                shows: historyManager.recentShows,
                emptyMessage: "No Recent Shows",
                onShowSelected: { show in
                    showViewModel.setShow(show)
                    navigateToPlayer = true
                },
                showViewModel: showViewModel,
                audioPlayer: audioPlayer
            )
        }
        .sheet(isPresented: $showingFavorites) {
            ShowListView(
                shows: historyManager.favoriteShows,
                emptyMessage: "No Favorite Shows",
                onShowSelected: { show in
                    showViewModel.setShow(show)
                    navigateToPlayer = true
                },
                showViewModel: showViewModel,
                audioPlayer: audioPlayer
            )
        }
        .navigationDestination(isPresented: $navigateToPlayer) {
            PlayerView(showViewModel: showViewModel, audioPlayer: audioPlayer)
        }
        .task {
            // Load a random show when the view appears
            loadNewRandomShow()
        }
    }
    
    // Load a new random show
    private func loadNewRandomShow() {
        guard let show = DatabaseManager.shared.getRandomShow() else { return }
        randomShow = show
    }
    
    // Handle show selection with proper player coordination
    private func handleShowSelection(_ show: EnrichedShow) {
        // Check if Jerry player is currently active and playing
        if playerCoordinator.getActivePlayerDestination() == .jerry && JerryShowViewModel.shared.isPlaying {
            // Just store the show reference without loading or stopping Jerry playback
            showViewModel.setShowReferenceOnly(show)
        } else {
            // No active playback, safe to load show
            showViewModel.setShowWithoutPlaying(show)
        }
        navigateToPlayer = true
    }
    
    // Custom row for the random show with highlight styling
    @ViewBuilder
    private func randomShowRow(for show: EnrichedShow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shuffle.circle.fill")
                    .foregroundColor(AppTheme.accentColor(for: .dead))
                    .font(.title3)
                
                // Remove "Grateful Dead Live at" prefix if present
                let title = show.metadata.title.hasPrefix("Grateful Dead Live at ") 
                    ? String(show.metadata.title.dropFirst("Grateful Dead Live at ".count))
                    : show.metadata.title
                
                // Also add formatted date if not part of the title
                let formattedDate = formatDate(show.identifier)
                let displayTitle = title.contains(formattedDate) ? title : "\(formattedDate) - \(title)"
                
                Text(displayTitle)
                    .appStyle(.basic)
                
                Spacer()
                
                Image(systemName: "play.circle")
                    .foregroundColor(AppTheme.accentColor(for: .dead))
                    .font(.title3)
            }
            
            Text(show.location.venue)
                .appStyle(.basic)
            
            Text("\(show.location.city), \(show.location.state)")
                .appStyle(.basic)
            
            // Show additional info
            HStack(spacing: 8) {
                if historyManager.completedShows.contains(show.identifier) {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .appStyle(.basic)
                } else if historyManager.partialShows.contains(show.identifier) {
                    Label("In Progress", systemImage: "clock.fill")
                        .appStyle(.basic)
                }
                
                if historyManager.isFavorite(show) {
                    Label("Favorite", systemImage: "heart.fill")
                        .appStyle(.basic)
                }
                
                Spacer()
                
                Label(String(format: "%.1f", show.score), systemImage: "star.fill")
                    .appStyle(.basic)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.accentColor(for: .dead).opacity(0.1))
                .padding(-8)
        )
    }
    
    // Format show date
    private func formatDate(_ identifier: String) -> String {
        // Handle identifiers like "gd80-05-14-sbd.hjshsj"
        if identifier.hasPrefix("gd") && identifier.count >= 10 {
            // Extract just YY-MM-DD part
            let startIndex = identifier.index(identifier.startIndex, offsetBy: 2)
            let endIndex = identifier.index(startIndex, offsetBy: 8)
            let dateString = String(identifier[startIndex..<endIndex])
            
            // Check if this has the expected format
            let components = dateString.split(separator: "-")
            if components.count >= 3 {
                let year = components[0]
                let month = components[1]
                let day = components[2]
                return "\(month)/\(day)/19\(year)"
            }
        }
        
        // Fallback to the original method
        let components = identifier.split(separator: "-")
        guard components.count >= 3 else { return identifier }
        
        let year = components[0]
        let month = components[1]
        let day = components[2].prefix(2) // In case there's more after the day
        
        return "\(month)/\(day)/\(year)"
    }
}

#Preview {
    NavigationView {
        GratefulDeadLandingView(
            showViewModel: ShowViewModel(),
            audioPlayer: AudioPlayerService.shared
        )
    }
} 