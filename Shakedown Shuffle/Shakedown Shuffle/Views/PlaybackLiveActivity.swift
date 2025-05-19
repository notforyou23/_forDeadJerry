import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.1, *)
struct PlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackAttributes.self) { context in
            // Lock screen/banner UI
            VStack {
                HStack {
                    // App icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                        .padding(.trailing, 8)
                    
                    Text(context.state.trackTitle)
                        .bold()
                    Spacer()
                    Text(formatTime(context.state.currentTime))
                }
                
                ProgressView(value: context.state.progress)
                    .tint(.purple)
                
                Text(context.state.showTitle)
                    .font(.caption)
            }
            .padding()
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        // App icon
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                        
                        Text(context.state.trackTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.currentTime))
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(.purple)
                }
            } compactLeading: {
                // Compact leading
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            } compactTrailing: {
                // Compact trailing
                Text(formatTime(context.state.currentTime))
                    .font(.caption2)
            } minimal: {
                // Minimal UI
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            }
            .keylineTint(.purple)
            .contentMargins(.all, 4, for: .expanded)
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 