import SwiftUI

struct JerryLandingView: View {
    @StateObject private var viewModel = JerryShowViewModel.shared
    @State private var searchText = ""
    @State private var showingOnThisDay = false
    @State private var showingRecents = false
    @State private var showingFavorites = false
    @State private var selectedShowId: String? = nil
    
    var filteredShows: [JerryShow] {
        let shows = viewModel.showOnlyWithAudio ? viewModel.shows.filter { $0.audioFiles?.isEmpty == false } : viewModel.shows
        if searchText.isEmpty {
            return shows
        }
        return shows.filter { show in
            let searchString = "\(show.date) \(show.venue) \(show.location) \(show.name)".lowercased()
            return searchString.contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading shows...")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Error Loading Shows")
                        .font(.title)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
            } else {
                // Random Show Section
                if let show = viewModel.randomShow {
                    Section(header: Text("Random Show")
                        .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))) {
                        NavigationLink(destination: JerryPlayerView(show: show)) {
                            randomShowRow(for: show)
                        }
                    }
                }
                
                // All Shows Section
                Section(header: Text("All Shows (\(filteredShows.count))")
                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))) {
                    // Get new random show button
                    Button(action: loadNewRandomShow) {
                        HStack {
                            Image(systemName: "shuffle.circle.fill")
                                .font(.title2)
                            Text("New Random Show")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .appButtonStyle(.concert, color: AppTheme.accentColor(for: .jerry))
                    
                    ForEach(filteredShows) { show in
                        NavigationLink(destination: JerryPlayerView(show: show)) {
                            JerryShowRow(show: show)
                        }
                        .listRowBackground(
                            selectedShowId == show.id ? 
                                Color.green.opacity(0.2) : 
                                Color.clear
                        )
                        .onAppear {
                            // If this is the selected show and it's just appeared in the list, 
                            // we want to scroll to it
                            if selectedShowId == show.id {
                                // Add a slight delay to ensure UI is ready
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Show a highlight toast to help user find the show
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search shows")
        .navigationTitle("Jerry Garcia")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle(isOn: $viewModel.showOnlyWithAudio) {
                        Label("Shows with Audio", systemImage: "music.note")
                    }
                    
                    Divider()
                    
                    Button(action: { showingRecents = true }) {
                        Label("Recent Shows", systemImage: "clock")
                    }
                    .appButtonStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                    
                    Button(action: { showingFavorites = true }) {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .appButtonStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                    
                    Button(action: { showingOnThisDay = true }) {
                        Label("On This Day", systemImage: "calendar")
                    }
                    .appButtonStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                }
            }
        }
        .sheet(isPresented: $showingOnThisDay) {
            NavigationStack {
                UnifiedShowsOnThisDayView(showViewModel: ShowViewModel())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { showingOnThisDay = false }
                                .appButtonStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecents) {
            JerryRecentShowsView()
        }
        .sheet(isPresented: $showingFavorites) {
            JerryFavoriteShowsView()
        }
        .task {
            // Load shows if needed
            if viewModel.shows.isEmpty {
                await viewModel.loadShows()
            }
            
            // Only set a random show if the view model doesn't have one yet
            if viewModel.randomShow == nil {
                loadNewRandomShow()
            }
            
            // Check for a selected show ID from stats view
            if let savedShowId = UserDefaults.standard.string(forKey: "last_selected_jerry_show_id") {
                // Clear the saved ID so we don't keep accessing it
                UserDefaults.standard.removeObject(forKey: "last_selected_jerry_show_id")
                
                // Set as selected show to highlight in the UI
                selectedShowId = savedShowId
            }
        }
    }
    
    // Load a new random show
    private func loadNewRandomShow() {
        // Only select from shows with audio
        let availableShows = viewModel.shows.filter { $0.audioFiles?.isEmpty == false }
        if let show = availableShows.randomElement() {
            viewModel.randomShow = show
        }
    }
    
    // Custom row for the random show with highlight styling
    @ViewBuilder
    private func randomShowRow(for show: JerryShow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shuffle.circle.fill")
                    .foregroundColor(AppTheme.accentColor(for: .jerry))
                    .font(.title3)
                
                Text("\(show.date) - \(show.name)")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                // Only show play icon if this show is currently playing
                if viewModel.isPlaying && viewModel.currentShow?.id == show.id {
                    Image(systemName: "play.circle")
                        .foregroundColor(AppTheme.accentColor(for: .jerry))
                        .font(.title3)
                }
            }
            
            Text(show.venue)
                .font(AppTheme.subheadlineStyle)
                .foregroundColor(AppTheme.textSecondary)
            
            Text(show.location)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary.opacity(0.8))
            
            // Show status indicators
            HStack(spacing: 8) {
                if show.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if show.isPartiallyPlayed {
                    Label("In Progress", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if show.isFavorite {
                    Label("Favorite", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .appStyle(show.isFavorite ? .psychedelic : .concert, color: AppTheme.accentColor(for: .jerry))
    }
}

#Preview {
    NavigationView {
        JerryLandingView()
    }
} 