import Foundation
import ActivityKit
import SwiftUI

struct PlaybackAttributes: ActivityAttributes {
    public typealias LiveActivityAttributes = Self
    
    public struct ContentState: Codable, Hashable {
        var trackTitle: String
        var showTitle: String
        var isPlaying: Bool
        var currentTime: Double
        var duration: Double
        var progress: Double
    }
} 