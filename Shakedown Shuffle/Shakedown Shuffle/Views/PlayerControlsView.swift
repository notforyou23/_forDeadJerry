import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = .white
        routePicker.activeTintColor = .purple
        return routePicker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct PlayerControlsView: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    let onRandomShow: () -> Void

    var body: some View {
        VStack(spacing: 20) { // Spacing between elements
            // Progress Bar
            ProgressBar(
                value: audioPlayer.progress,
                onSeek: { position in
                    let time = position * audioPlayer.duration
                    audioPlayer.seek(to: time)
                }
            )
            .padding(.horizontal)

            // Time Labels
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .foregroundColor(.white)
                Spacer()
                Text(formatTime(audioPlayer.duration))
                    .foregroundColor(.white)
            }
            .font(.caption)
            .padding(.horizontal)

            // Playback Controls with AirPlay Button Inline
            HStack(spacing: 40) { // Adjust spacing for even layout
                Spacer()

                // Previous Button
                Button(action: {
                    if audioPlayer.currentIndex > 0 {
                        audioPlayer.playTrack(at: audioPlayer.currentIndex - 1)
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(audioPlayer.currentIndex == 0 || audioPlayer.isLoading)

                // Play/Pause Button
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48)) // Larger button for emphasis
                        .foregroundColor(.white)
                }
                .disabled(audioPlayer.isLoading)

                // Next Button
                Button(action: {
                    if audioPlayer.currentIndex < audioPlayer.trackList.count - 1 {
                        audioPlayer.playTrack(at: audioPlayer.currentIndex + 1)
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(audioPlayer.currentIndex == audioPlayer.trackList.count - 1 || audioPlayer.isLoading)

                // AirPlay Button
                AirPlayButton()
                    .frame(width: 30, height: 30)

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite, !time.isNaN else { return "0:00" }
        let minutes = Int(max(0, time)) / 60
        let seconds = Int(max(0, time)) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ProgressBar: View {
    let value: Double
    let onSeek: (Double) -> Void
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                // Progress
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: geometry.size.width * (isDragging ? dragValue : value), height: 4)
            }
            .cornerRadius(2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragValue = min(max(value.location.x / geometry.size.width, 0), 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onSeek(dragValue)
                    }
            )
        }
        .frame(height: 4)
    }
}

#Preview {
    PlayerControlsView(
        audioPlayer: AudioPlayerService.shared,
        onRandomShow: {}
    )
    .preferredColorScheme(.dark)
}
