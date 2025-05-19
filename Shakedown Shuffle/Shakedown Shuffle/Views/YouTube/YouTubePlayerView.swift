import SwiftUI

struct YouTubePlayerView: View {
    let show: YouTubeShowViewModel.YouTubeShow
    @StateObject private var viewModel = YouTubeShowViewModel.shared

    var body: some View {
        VStack {
            if let url = show.youtubeURL {
                WebViewContainer(url: url, coordinator: viewModel.coordinator)
                    .frame(height: 300)
            } else {
                Text("Invalid video URL")
            }

            Text("\(show.date) - \(show.venue)")
                .font(.headline)
                .padding(.top)
            Text(show.location)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.play(show: show)
        }
        .onDisappear {
            // Keep playback running when navigating away
        }
    }
}

#Preview {
    NavigationStack {
        let demo = YouTubeShowViewModel.YouTubeShow(id: "1", date: "1/1/2000", venue: "Venue", location: "City, ST", name: "Demo", urlString: "https://youtube.com/watch?v=dQw4w9WgXcQ")
        YouTubePlayerView(show: demo)
    }
}
