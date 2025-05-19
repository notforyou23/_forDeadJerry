import SwiftUI

struct JerryStatsView: View {
    @StateObject private var viewModel = JerryShowStatsViewModel()
    @State private var selectedSong: JerryShowStatsViewModel.SongStat?
    @State private var expandedSongId: String?
    
    var body: some View {
        List {
            // Aggregate Stats Section
            Section(header: Text("Overall Statistics")
                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))) {
                if viewModel.isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    HStack(spacing: 0) {
                        StatBox(title: "Total Shows", value: viewModel.totalShows)
                        StatBox(title: "Unique Songs", value: viewModel.uniqueSongs)
                        StatBox(title: "Song Plays", value: viewModel.totalSongPlays)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            
            // Song Search and Filtering
            Section(header: Text("Song Statistics")
                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))) {
                if viewModel.isLoading {
                    ProgressView("Loading songs...")
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error Loading Statistics")
                            .font(.title)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    // Sorting options
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(JerryShowStatsViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    
                    // Songs list
                    ForEach(viewModel.filteredSongs) { song in
                        SongRow(song: song, expandedSongId: $expandedSongId)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search songs...")
        .navigationTitle("Jerry Statistics")
        .task {
            if viewModel.songStats.isEmpty {
                await viewModel.loadStatistics()
            }
        }
    }
}

// Statistic Box Component
struct StatBox: View {
    let title: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(value.formatted())")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.accentColor(for: .jerry))
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
        .padding(4)
    }
}

// Song Row Component
struct SongRow: View {
    let song: JerryShowStatsViewModel.SongStat
    @Binding var expandedSongId: String?
    
    private var isExpanded: Bool {
        expandedSongId == song.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content
            Button(action: {
                withAnimation {
                    expandedSongId = isExpanded ? nil : song.id
                }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(AppTheme.accentColor(for: .jerry))
                    
                    Text(song.song)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(song.count)")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("plays")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details section
            if isExpanded {
                VStack(spacing: 16) {
                    // Stats summary
                    HStack(spacing: 0) {
                        StatBox(title: "Total Plays", value: song.count)
                        StatBox(title: "Show Openers", value: song.openCount)
                        StatBox(title: "Unique Shows", value: song.uniqueShowCount)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("First Played:")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(song.firstPlayed)
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                                
                            Spacer()
                            
                            Text("Last Played:")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(song.lastPlayed)
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Occurrences list
                    SongOccurrencesView(occurrences: song.occurrences)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 8)
            }
        }
        .background(Color.black.opacity(isExpanded ? 0.15 : 0))
        .cornerRadius(isExpanded ? 8 : 0)
        .padding(.vertical, isExpanded ? 4 : 0)
    }
}

// Song Occurrences List Component
struct SongOccurrencesView: View {
    let occurrences: [JerryShowStatsViewModel.SongOccurrence]
    @State private var showingAllOccurrences = false
    @State private var showingWebView = false
    @State private var selectedURL: URL? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var sortedOccurrences: [JerryShowStatsViewModel.SongOccurrence] {
        occurrences.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Occurrences")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingAllOccurrences.toggle()
                    }
                }) {
                    Text(showingAllOccurrences ? "Show Less" : "Show All")
                        .font(.caption)
                        .foregroundColor(AppTheme.accentColor(for: .jerry))
                }
            }
            .padding(.horizontal)
            
            // Occurrences table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Date")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .leading)
                    
                    Text("Venue")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                    Text("Location")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 120, alignment: .leading)
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                
                // List of occurrences
                ForEach(showingAllOccurrences ? sortedOccurrences : Array(sortedOccurrences.prefix(5))) { occurrence in
                    Button(action: {
                        // Use the app's WebView to show the show details
                        openShowDetails(for: occurrence)
                    }) {
                        HStack {
                            Text(occurrence.date)
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(occurrence.venue)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                            Text(occurrence.location)
                                .font(.caption)
                                .frame(width: 120, alignment: .leading)
                                .lineLimit(1)
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showingAllOccurrences || sortedOccurrences.firstIndex(where: { $0.id == occurrence.id }) != sortedOccurrences.count - 1 {
                        Divider()
                            .padding(.horizontal)
                            .background(Color.black.opacity(0.1))
                    }
                }
                
                // "Show more" indicator if there are more occurrences
                if !showingAllOccurrences && sortedOccurrences.count > 5 {
                    Button(action: {
                        withAnimation {
                            showingAllOccurrences = true
                        }
                    }) {
                        Text("+ \(sortedOccurrences.count - 5) more occurrences")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentColor(for: .jerry))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingWebView) {
            if let url = selectedURL {
                NavigationView {
                    WebViewContainer(url: url)
                }
            }
        }
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    private func openShowDetails(for occurrence: JerryShowStatsViewModel.SongOccurrence) {
        // Default URL if the show doesn't have a specific URL
        let fallbackURL = "https://jerrygarcia.com/shows/"
        
        // Try to use the show-specific URL first
        if let urlString = occurrence.url, !urlString.isEmpty {
            // Clean the URL string to make sure it's valid
            let cleanedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let url = URL(string: cleanedURLString) {
                selectedURL = url
                showingWebView = true
            } else {
                // If the URL is invalid, use the fallback URL with the date
                let dateComponents = occurrence.date.components(separatedBy: "-")
                if dateComponents.count >= 3 {
                    let year = dateComponents[0]
                    let searchURL = "\(fallbackURL)?years=\(year)"
                    if let url = URL(string: searchURL) {
                        selectedURL = url
                        showingWebView = true
                    } else {
                        // Use the base fallback URL if everything else fails
                        selectedURL = URL(string: fallbackURL)
                        showingWebView = true
                    }
                } else {
                    // Use the base fallback URL if we couldn't parse the date
                    selectedURL = URL(string: fallbackURL)
                    showingWebView = true
                }
            }
        } else {
            // Show alert that no URL is available
            alertMessage = "No online information available for this show."
            showingAlert = true
        }
    }
}

struct JerryStatsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            JerryStatsView()
                .preferredColorScheme(.dark)
        }
    }
} 

