import SwiftUI

struct JerryShowRow: View {
    let show: JerryShow
    @StateObject private var historyManager = UnifiedHistoryManager.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date and basic info
            HStack(alignment: .center) {
                Text(show.date)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    if show.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.small)
                    } else if show.isPartiallyPlayed {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .imageScale(.small)
                    }
                    
                    if show.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .imageScale(.small)
                    }
                }
            }
            
            // Venue and location
            Text("\(show.venue), \(show.location)")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            
            // Audio availability indicator with improved design
            if show.audioFiles?.isEmpty == false {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    Text("Audio Available")
                        .font(.caption)
                }
                .foregroundColor(AppTheme.accentColor(for: .jerry))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.accentColor(for: .jerry).opacity(0.1))
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isHovered ? 0.3 : 0.1))
                .shadow(color: AppTheme.accentColor(for: .jerry).opacity(isHovered ? 0.15 : 0), radius: 8, x: 0, y: 4)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
        // Apply our new style system
        .appStyle(show.isFavorite ? .psychedelic : .basic, color: AppTheme.accentColor(for: .jerry))
    }
}

#Preview {
    JerryShowRow(show: JerryShow(
        masterData: JerryShowData(
            id: "jgb1980-03-01",
            date: "1980-03-01",
            venue: "Capitol Theatre",
            location: "Passaic, NJ",
            name: "Jerry Garcia Band",
            url: nil,
            setlists: [["Sugaree", "Catfish John"], ["Midnight Moonlight"]],
            notes: "Sample show for preview"
        ),
        folder: "jgb1980-03-01",
        audioFiles: nil
    ))
    .background(Color.black)
    .previewLayout(.sizeThatFits)
} 