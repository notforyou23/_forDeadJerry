import SwiftUI

// Unified protocol for show display requirements
protocol DisplayableShow {
    var displayTitle: String { get }
    var subtitle: String { get }
    var hasAudio: Bool { get }
    var displaySection: AppSection { get }
}

// Extension for EnrichedShow to conform to DisplayableShow
extension EnrichedShow: DisplayableShow {
    var displayTitle: String {
        // Extract date from identifier (format: gdYY-MM-DD)
        // Handle more complex identifiers
        if identifier.hasPrefix("gd") && identifier.count >= 10 {
            // Extract just YY-MM-DD part
            let components = identifier.dropFirst(2).components(separatedBy: "-")
            if components.count >= 3 {
                let year = components[0]
                let month = components[1]
                let day = String(components[2].prefix(2)) // Just get the first 2 digits
                
                let dateStr = "\(year)-\(month)-\(day)"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yy-MM-dd"
                
                if let date = dateFormatter.date(from: dateStr) {
                    dateFormatter.dateFormat = "MMMM d, yyyy"
                    return dateFormatter.string(from: date)
                }
            }
        }
        
        // Fallback to metadata title if date parsing fails, removing "Grateful Dead Live at" prefix
        if metadata.title.hasPrefix("Grateful Dead Live at ") {
            return String(metadata.title.dropFirst("Grateful Dead Live at ".count))
        }
        return metadata.title
    }
    
    var subtitle: String {
        return "\(location.venue), \(location.city)"
    }
    
    var hasAudio: Bool {
        return tracks.isEmpty == false
    }
    
    var displaySection: AppSection {
        return .dead
    }
}

// Extension for JerryShow to conform to DisplayableShow
extension JerryShow: DisplayableShow {
    var displayTitle: String {
        return date
    }
    
    var subtitle: String {
        return "\(venue), \(location)"
    }
    
    var hasAudio: Bool {
        return audioFiles?.isEmpty == false
    }
    
    var displaySection: AppSection {
        return .jerry
    }
}

// Unified row view for both show types
struct ShowRowView: View {
    let show: DisplayableShow
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Date/identifier with icon
                HStack(spacing: 8) {
                    // Calendar icon with accent background
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentColor(for: show.displaySection).opacity(0.2))
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: "calendar")
                            .foregroundColor(AppTheme.accentColor(for: show.displaySection))
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Text(show.displayTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
            }
            
            // Venue and location
            Text(show.subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            
            // Audio availability indicator with improved design
            if show.hasAudio {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    Text("Audio Available")
                        .font(.caption)
                }
                .foregroundColor(AppTheme.accentColor(for: show.displaySection))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.accentColor(for: show.displaySection).opacity(0.1))
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isHovered ? 0.3 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.accentColor(for: show.displaySection).opacity(0.6),
                                    AppTheme.accentColor(for: show.displaySection).opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
} 