import SwiftUI

/// Floating mini player that persists YouTube playback across the app.
struct FloatingYouTubePlayerView: View {
    @StateObject private var viewModel = YouTubeShowViewModel.shared
    @State private var showFullPlayer = false

    var body: some View {
        // Show only when a video is actively playing and the full player isn't visible
        if let show = viewModel.currentShow, viewModel.isPlaying, !viewModel.isPlayerPresented {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.stopPlayback()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .padding(4)
                    }
                }

                if let url = show.youtubeURL {
                    WebViewContainer(url: url, fallbackURL: show.watchURL, coordinator: viewModel.coordinator)
                        .frame(width: 200, height: 112)
                        .cornerRadius(8)
                        .onTapGesture { showFullPlayer = true }
                }
            }
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .shadow(radius: 5)
            .padding()
            .sheet(isPresented: $showFullPlayer, onDismiss: {
                viewModel.dismissPlayer()
            }) {
                YouTubePlayerView(show: show)
                    .onAppear { viewModel.presentPlayer() }
            }
        }
    }
}

#Preview {
    FloatingYouTubePlayerView()
}
