import SwiftUI

struct JerryPlayerViewold: View {
    let show: JerryShow
    @StateObject private var viewModel = JerryShowViewModel.shared
    @StateObject private var historyManager = UnifiedHistoryManager.shared
    @State private var showingShowDetails = false
    @State private var showingWebView = false
    @State private var selectedURL: URL?
    
    // Create playback adapter
    private var playbackAdapter: JerryPlaybackAdapter {
        JerryPlaybackAdapter(viewModel: viewModel)
    }
    
    // Create track list controller
    private var trackListController: JerryTrackListController {
        JerryTrackListController(viewModel: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Show Information
                        VStack(alignment: .leading, spacing: 8) {
                            Text(show.date)
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            
                            Text(show.venue)
                                .font(.title2)
                                .bold()
                                .foregroundColor(AppTheme.textPrimary)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            
                            Text(show.location)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                            
                            // Restore action buttons row (heart, info, link)
                            HStack {
                                Spacer()
                                
                                // External link to jerrygarcia.com
                                if let url = show.url, let showURL = URL(string: url) {
                                    Button(action: {
                                        selectedURL = showURL
                                        showingWebView = true
                                    }) {
                                        Image(systemName: "link.circle")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 22))
                                            .padding(8)
                                    }
                                }
                                
                                // Favorite button - updated to use the viewModel's favorite list
                                Button(action: {
                                    viewModel.toggleFavorite(show)
                                }) {
                                    Image(systemName: viewModel.favoriteShows.contains(where: { $0.id == show.id }) ? "heart.fill" : "heart")
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
                        if let downloads = show.sortedAudioFiles, !downloads.isEmpty {
                            // Use our new unified player controls with responsive wrapper
                            ResponsiveControlWrapper {
                                CommonPlayerControls(controller: playbackAdapter)
                            }
                            .padding(.horizontal)
                            
                            // Track List with unified component
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
                        if !show.setlists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Setlist")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(AppTheme.textPrimary)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                                
                                ForEach(Array(show.setlists.enumerated()), id: \.offset) { index, set in
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
                        if let notes = show.notes, !notes.isEmpty {
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
        .onAppear {
            // Load the show when the view appears
            if viewModel.currentShow?.id != show.id {
                Task {
                    await viewModel.playShow(show)
                }
            }
            
            // Update history when view appears
            historyManager.markJerryShowAsPartial(show)
            historyManager.addJerryShowToHistory(show)
            
            // Update the PlayerCoordinator to ensure it knows this player is active
            PlayerCoordinator.shared.setActivePlayer(.jerry)
        }
        .sheet(isPresented: $showingShowDetails) {
            // Use the unified show detail view
            NavigationView {
                UnifiedShowDetailView(show: show)
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = selectedURL {
                NavigationView {
                    WebViewContainer(url: url)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        JerryPlayerViewold(show: JerryShow(
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
