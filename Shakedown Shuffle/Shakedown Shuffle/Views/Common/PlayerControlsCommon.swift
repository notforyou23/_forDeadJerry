import SwiftUI
import AVKit

// Protocol defining minimum requirements for a player control interface
@MainActor protocol PlaybackController {
    var isPlaying: Bool { get }
    var progress: Double { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var section: AppSection { get }
    
    func play()
    func pause()
    func togglePlayPause()
    func skipForward()
    func skipBackward()
    func seekForward(seconds: Double)
}

// Adapter for AudioPlayerService to conform to PlaybackController
@MainActor
class DeadPlaybackAdapter: PlaybackController {
    private let audioPlayer: AudioPlayerService
    
    init(audioPlayer: AudioPlayerService) {
        self.audioPlayer = audioPlayer
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    var progress: Double {
        guard audioPlayer.duration > 0 else { return 0 }
        return audioPlayer.currentTime / audioPlayer.duration
    }
    
    var currentTime: Double {
        audioPlayer.currentTime
    }
    
    var duration: Double {
        audioPlayer.duration
    }
    
    var section: AppSection {
        .dead
    }
    
    func play() {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func togglePlayPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }
    
    func skipForward() {
        // Find the next track based on the current index
        if let currentTrack = audioPlayer.currentTrack, 
           let currentIndex = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
            let nextIndex = min(currentIndex + 1, audioPlayer.trackList.count - 1)
            if nextIndex != currentIndex {
                audioPlayer.playTrack(at: nextIndex)
            }
        }
    }
    
    func skipBackward() {
        // Find the previous track based on the current index
        if let currentTrack = audioPlayer.currentTrack,
           let currentIndex = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) {
            let prevIndex = max(currentIndex - 1, 0)
            if prevIndex != currentIndex {
                audioPlayer.playTrack(at: prevIndex)
            }
        }
    }
    
    func seekForward(seconds: Double) {
        // Calculate new time and ensure it doesn't exceed duration
        let newTime = min(audioPlayer.currentTime + seconds, audioPlayer.duration)
        audioPlayer.seek(to: newTime)
    }
}

// Adapter for JerryShowViewModel to conform to PlaybackController
@MainActor
class JerryPlaybackAdapter: PlaybackController {
    private let viewModel: JerryShowViewModel
    private var task: Task<Void, Never>?
    
    init(viewModel: JerryShowViewModel) {
        self.viewModel = viewModel
    }
    
    var isPlaying: Bool {
        viewModel.isPlaying
    }
    
    var progress: Double {
        viewModel.progress
    }
    
    var currentTime: Double {
        // JerryShowViewModel doesn't directly expose currentTime, so we calculate from progress
        return viewModel.progress * duration
    }
    
    var duration: Double {
        viewModel.duration
    }
    
    var section: AppSection {
        .jerry
    }
    
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
        // Cancel any previous task to avoid multiple concurrent operations
        task?.cancel()
        task = Task {
            do {
                try await viewModel.playNextTrack()
            } catch {
                print("Error skipping forward: \(error)")
            }
        }
    }
    
    func skipBackward() {
        // Cancel any previous task to avoid multiple concurrent operations
        task?.cancel()
        task = Task {
            do {
                try await viewModel.playPreviousTrack()
            } catch {
                print("Error skipping backward: \(error)")
            }
        }
    }
    
    func seekForward(seconds: Double) {
        // Calculate the new position as a percentage and set through available API
        // Adding basic error checking to prevent invalid calculations
        guard duration > 0 else { return }
        
        let newProgress = min(max(0, progress + (seconds / duration)), 1.0)
        viewModel.seekToPosition(newProgress)
    }
    
    deinit {
        // Ensure tasks are cancelled when the adapter is deallocated
        task?.cancel()
    }
}

// Common player controls view
struct CommonPlayerControls: View {
    @MainActor let controller: PlaybackController
    var compactMode: Bool = false
    @State private var isDragging = false
    @State private var progressOverride: Double?
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: compactMode ? 6 : 12) {
            // Progress Bar with improved visual design
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: compactMode ? 4 : 6)
                    
                    // Progress fill
                    Capsule()
                        .fill(AppTheme.accentColor(for: controller.section))
                        .frame(width: geo.size.width * (progressOverride ?? controller.progress), height: compactMode ? 4 : 6)
                    
                    // Thumb indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: (geo.size.width * (progressOverride ?? controller.progress)) - (isDragging ? 8 : 6))
                        .opacity(compactMode ? 0 : 1)
                }
                .contentShape(Rectangle()) // Ensure the entire area is tappable
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            progressOverride = min(max(0, value.location.x / geo.size.width), 1.0)
                        }
                        .onEnded { _ in
                            isDragging = false
                            if let progress = progressOverride {
                                let seekTime = progress * controller.duration
                                let currentTime = controller.currentTime
                                // Seek to the new position directly without wrapping in a Task
                                if seekTime > currentTime {
                                    let secondsToSeek = seekTime - currentTime
                                    controller.seekForward(seconds: secondsToSeek)
                                } else if seekTime < currentTime {
                                    let secondsToSeek = currentTime - seekTime
                                    controller.seekForward(seconds: -secondsToSeek)
                                }
                            }
                            // Reset after a delay to show animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    progressOverride = nil
                                }
                            }
                        }
                )
            }
            .frame(height: compactMode ? 4 : 24)
            
            if !compactMode {
                // Time indicators with improved typography
                HStack {
                    Text(formatTime(controller.currentTime))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    Text(formatTime(controller.duration))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            // Main controls row - simplified for better responsiveness
            HStack(spacing: compactMode ? 40 : 60) {
                // Skip backward track button - simplified
                Button {
                    controller.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: compactMode ? 22 : 26))
                        .foregroundColor(AppTheme.accentColor(for: controller.section))
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play/Pause button - simplified for reliability
                Button {
                    controller.togglePlayPause()
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compactMode ? 30 : 34, weight: .bold))
                        .foregroundColor(AppTheme.accentColor(for: controller.section))
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Skip forward track button - simplified
                Button {
                    controller.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: compactMode ? 22 : 26))
                        .foregroundColor(AppTheme.accentColor(for: controller.section))
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Bottom row with 10-second skip buttons - simplified
            if !compactMode {
                HStack {
                    // Back 10 seconds button - simplified
                    Button {
                        controller.seekForward(seconds: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.accentColor(for: controller.section))
                            .frame(width: 50, height: 50)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // AirPlay button
                    AirPlayButton()
                        .frame(width: 50, height: 50)
                    
                    Spacer()
                    
                    // Forward 10 seconds button - simplified
                    Button {
                        controller.seekForward(seconds: 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.accentColor(for: controller.section))
                            .frame(width: 50, height: 50)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
    }
}

// Responsive control wrapper with unified styling
struct ResponsiveControlWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
            )
            .padding(.vertical, 4)
    }
} 