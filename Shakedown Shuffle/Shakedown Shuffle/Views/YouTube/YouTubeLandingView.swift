import SwiftUI

struct YouTubeLandingView: View {
    @StateObject private var viewModel = YouTubeShowViewModel.shared
    @State private var searchText = ""

    private var filteredShows: [YouTubeShowViewModel.YouTubeShow] {
        if searchText.isEmpty { return viewModel.shows }
        return viewModel.shows.filter { show in
            let string = "\(show.date) \(show.venue) \(show.location)".lowercased()
            return string.contains(searchText.lowercased())
        }
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading shows...")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            } else {
                ForEach(filteredShows) { show in
                    NavigationLink(destination: YouTubePlayerView(show: show)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(show.date) - \(show.venue)")
                                    .font(.headline)
                                Text(show.location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.favoriteShows.contains(where: { $0.id == show.id }) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search shows")
        .navigationTitle("YouTube Shows")
        .task {
            if viewModel.shows.isEmpty {
                await viewModel.loadShows()
            }
        }
    }
}

#Preview {
    NavigationStack {
        YouTubeLandingView()
    }
}
