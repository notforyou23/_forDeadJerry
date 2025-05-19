import SwiftUI

// Protocol for track display requirements
protocol DisplayableTrack: Identifiable {
    var displayTitle: String { get }
    var subtitle: String? { get }
    var duration: String? { get }
}

// Protocol for track list management
@MainActor protocol TrackListController {
    var section: AppSection { get }
    var currentTrackIndex: Int { get }
    var isPlaying: Bool { get }
    
    func playTrack(at index: Int)
    func togglePlayPause(at index: Int)
}

// Extension for Dead tracks
extension Track: DisplayableTrack, Identifiable {
    var displayTitle: String { self.title }
    var subtitle: String? { nil }
    var duration: String? { self.length }
    var id: String { self.filename }  // Add explicit id property to conform to Identifiable
}

// Extension for Jerry audio files
extension JerryAudioFile: DisplayableTrack {
    var displayTitle: String { self.songTitle ?? self.name }
    var subtitle: String? { self.set }
    var duration: String? { nil }
    // JerryAudioFile already has an id property
}

// Controller for Dead tracks
@MainActor
class DeadTrackListController: TrackListController {
    private let audioPlayer: AudioPlayerService
    
    var section: AppSection { .dead }
    
    var currentTrackIndex: Int {
        guard let currentTrack = audioPlayer.currentTrack,
              let index = audioPlayer.trackList.firstIndex(where: { $0.filename == currentTrack.filename }) else {
            return -1
        }
        return index
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    init(audioPlayer: AudioPlayerService) {
        self.audioPlayer = audioPlayer
    }
    
    func playTrack(at index: Int) {
        audioPlayer.playTrack(at: index)
    }
    
    func togglePlayPause(at index: Int) {
        if currentTrackIndex == index {
            if isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
        } else {
            playTrack(at: index)
        }
    }
}

// Controller for Jerry tracks
@MainActor
class JerryTrackListController: TrackListController {
    private let viewModel: JerryShowViewModel
    private var playbackTasks: [Int: Task<Void, Never>] = [:]
    
    var section: AppSection { .jerry }
    
    var currentTrackIndex: Int {
        viewModel.currentTrackIndex
    }
    
    var isPlaying: Bool {
        viewModel.isPlaying
    }
    
    init(viewModel: JerryShowViewModel) {
        self.viewModel = viewModel
    }
    
    func playTrack(at index: Int) {
        // Cancel any existing playback tasks to avoid conflicts
        playbackTasks.values.forEach { $0.cancel() }
        playbackTasks.removeAll()
        
        // Create a new task for this track
        let task = Task {
            do {
                try await viewModel.playTrack(at: index)
            } catch {
                print("Error playing track at index \(index): \(error)")
            }
            // Remove task reference when completed
            playbackTasks.removeValue(forKey: index)
        }
        
        // Store the task reference
        playbackTasks[index] = task
    }
    
    func togglePlayPause(at index: Int) {
        if currentTrackIndex == index {
            // If this is the current track, just toggle play/pause
            viewModel.togglePlayPause()
        } else {
            // Otherwise play the new track
            playTrack(at: index)
        }
    }
    
    deinit {
        // Clean up any remaining tasks
        playbackTasks.values.forEach { $0.cancel() }
    }
}

// Unified track list view with enhanced styling
struct UnifiedTrackListView<T: DisplayableTrack>: View {
    let tracks: [T]
    @MainActor let controller: TrackListController
    @State private var hoveredIndex: Int? = nil
    
    // Extract computed properties for colors and styling to simplify view hierarchy
    private func trackNumberColor(isHovered: Bool) -> Color {
        isHovered ? AppTheme.accentColor(for: controller.section) : AppTheme.textSecondary
    }
    
    private func titleColor(isCurrentTrack: Bool, isHovered: Bool) -> Color {
        (isCurrentTrack || isHovered) ? AppTheme.accentColor(for: controller.section) : AppTheme.textPrimary
    }
    
    private func subtitleColor(isCurrentTrack: Bool, isHovered: Bool) -> Color {
        (isCurrentTrack || isHovered) ? 
            AppTheme.accentColor(for: controller.section).opacity(0.8) : 
            AppTheme.textSecondary
    }
    
    private func durationColor(isCurrentTrack: Bool, isHovered: Bool) -> Color {
        (isCurrentTrack || isHovered) ? 
            AppTheme.accentColor(for: controller.section).opacity(0.9) : 
            AppTheme.textSecondary
    }
    
    private func trackBackgroundColor(isCurrentTrack: Bool, isHovered: Bool) -> Color {
        if isCurrentTrack {
            return AppTheme.accentColor(for: controller.section).opacity(0.15)
        } else if isHovered {
            return Color.white.opacity(0.03)
        } else {
            return Color.clear
        }
    }
    
    private func borderColor(isCurrentTrack: Bool) -> Color {
        isCurrentTrack ? AppTheme.accentColor(for: controller.section).opacity(0.3) : Color.clear
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let isCurrentTrack = controller.currentTrackIndex == index && controller.isPlaying
                let isHovered = hoveredIndex == index
                
                TrackRow(
                    track: track,
                    index: index,
                    isCurrentTrack: isCurrentTrack,
                    isHovered: isHovered,
                    controller: controller,
                    accentColor: AppTheme.accentColor(for: controller.section),
                    trackNumberColor: trackNumberColor(isHovered: isHovered),
                    titleColor: titleColor(isCurrentTrack: isCurrentTrack, isHovered: isHovered),
                    subtitleColor: subtitleColor(isCurrentTrack: isCurrentTrack, isHovered: isHovered),
                    durationColor: durationColor(isCurrentTrack: isCurrentTrack, isHovered: isHovered),
                    backgroundColor: trackBackgroundColor(isCurrentTrack: isCurrentTrack, isHovered: isHovered),
                    borderColor: borderColor(isCurrentTrack: isCurrentTrack)
                )
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.hoveredIndex = isHovered ? index : nil
                    }
                }
                
                if index < tracks.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 60)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// Extracted row component for better performance
struct TrackRow<T: DisplayableTrack>: View {
    let track: T
    let index: Int
    let isCurrentTrack: Bool
    let isHovered: Bool
    let controller: TrackListController
    let accentColor: Color
    let trackNumberColor: Color
    let titleColor: Color
    let subtitleColor: Color
    let durationColor: Color
    let backgroundColor: Color
    let borderColor: Color
    
    var body: some View {
        Button(action: {
            controller.togglePlayPause(at: index)
        }) {
            HStack(spacing: 16) {
                // Track number/indicator
                ZStack {
                    if isCurrentTrack {
                        // Animated equalizer bars for currently playing track
                        HStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(accentColor)
                                    .frame(width: 2, height: i == 1 ? 10 : 6)
                                    .opacity(0.8)
                            }
                        }
                    } else {
                        // Track number for non-playing tracks
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(trackNumberColor)
                            .frame(width: 20)
                    }
                }
                .frame(width: 24)
                
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                    
                    if let subtitle = track.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration and controls
                HStack(spacing: 12) {
                    if let duration = track.duration {
                        Text(duration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(durationColor)
                            .monospacedDigit()
                    }
                    
                    // Play/Pause button
                    Image(systemName: isCurrentTrack ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accentColor)
                        .opacity(isCurrentTrack || isHovered ? 1.0 : 0.0)
                        .frame(width: 22)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(TrackButtonStyle())
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }
}

// Create a custom button style to improve touch response
struct TrackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle()) // Ensure the entire area is tappable
            .opacity(configuration.isPressed ? 0.7 : 1.0) // Simple press animation
    }
} 