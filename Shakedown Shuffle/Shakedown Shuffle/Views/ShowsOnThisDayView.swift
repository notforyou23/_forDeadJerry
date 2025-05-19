import SwiftUI

struct ShowsOnThisDayView: View {
    @ObservedObject var showViewModel: ShowViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToPlayer = false
    let todaysShows: [EnrichedShow]
    let dateString: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Ambient background effect
                RadialGradient(
                    gradient: AppTheme.mainGradient(for: .dead),
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                VStack {
                    Text("Shows on \(dateString)")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    if todaysShows.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 70))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No shows found for \(dateString)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("The Grateful Dead didn't perform on this day in history or the data is unavailable.")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showViewModel.loadRandomShow()
                                navigateToPlayer = true
                            }) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Try a Random Show Instead")
                                }
                                .padding()
                                .background(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(todaysShows, id: \.identifier) { show in
                                    Button(action: {
                                        showViewModel.setShow(show)
                                        navigateToPlayer = true
                                    }) {
                                        showCard(for: show)
                                    }
                                    .buttonStyle(AppButtonStyle(section: .dead))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToPlayer) {
                PlayerView(showViewModel: showViewModel, audioPlayer: AudioPlayerService.shared)
            }
        }
    }
    
    @ViewBuilder
    private func showCard(for show: EnrichedShow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDate(show.identifier))
                .font(.headline)
                .foregroundColor(.white)
            
            Text(show.location.venue)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(show.location.city), \(show.location.state)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            HStack {
                Label(show.recordingInfo.sourceType, systemImage: "waveform")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption2)
                
                Spacer()
                
                Label(String(format: "%.1f", show.recordingInfo.avgRating), systemImage: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.accentColor(for: .dead).opacity(0.5),
                    AppTheme.accentColor(for: .dead).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ date: String) -> String {
        // Extract YYYY-MM-DD from identifier string
        let components = date.split(separator: "-")
        guard components.count >= 3 else { return date }
        
        let year = components[0]
        let month = components[1]
        let day = components[2].prefix(2) // In case there's more after the day
        
        return "\(month)/\(day)/\(year)"
    }
}

#Preview {
    ShowsOnThisDayView(
        showViewModel: ShowViewModel(),
        todaysShows: [],
        dateString: "May 8"
    )
} 