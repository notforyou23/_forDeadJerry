import SwiftUI

struct YouTubePlayerView: View {
    let show: YouTubeShowViewModel.YouTubeShow
    @StateObject private var viewModel = YouTubeShowViewModel.shared
    @State private var showingShowDetails = false
    @State private var showingWebView = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let url = show.youtubeURL {
                    WebViewContainer(url: url, fallbackURL: show.watchURL, coordinator: viewModel.coordinator)
                        .frame(height: 300)
                } else {
                    Text("Invalid video URL")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(show.date) - \(show.venue)")
                        .font(.headline)
                    Text(show.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Spacer()
                    if let url = show.url, !url.isEmpty {
                        Button(action: { showingWebView = true }) {
                            Image(systemName: "link.circle")
                                .font(.title2)
                        }
                        .padding(.horizontal)
                    }

                    Button(action: { viewModel.toggleFavorite(show) }) {
                        Image(systemName: viewModel.favoriteShows.contains(where: { $0.id == show.id }) ? "heart.fill" : "heart")
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)

                    Button(action: { showingShowDetails = true }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                    }
                    .padding(.horizontal)
                    Spacer()
                }

                if !show.setlists.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Setlist")
                            .font(.headline)
                        ForEach(Array(show.setlists.enumerated()), id: \.offset) { index, set in
                            VStack(alignment: .leading) {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                ForEach(set, id: \.self) { song in
                                    Text("• \(song)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if let notes = show.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.play(show: show)
            viewModel.presentPlayer()
        }
        .onDisappear {
            viewModel.dismissPlayer()
        }
        .sheet(isPresented: $showingWebView) {
            if let url = show.url, let external = URL(string: url) {
                NavigationView {
                    WebViewContainer(url: external)
                }
            }
        }
        .sheet(isPresented: $showingShowDetails) {
            NavigationView {
                UnifiedShowDetailView(show: show)
            }
        }
    }
}

#Preview {
    NavigationStack {
        let demo = YouTubeShowViewModel.YouTubeShow(id: "1",
                                                   date: "1/1/2000",
                                                   venue: "Venue",
                                                   location: "City, ST",
                                                   name: "Demo",
                                                   urlString: "https://youtube.com/watch?v=dQw4w9WgXcQ",
                                                   url: "https://example.com",
                                                   setlists: [["Song A", "Song B"]],
                                                   notes: "Demo notes")
        YouTubePlayerView(show: demo)
    }
}
