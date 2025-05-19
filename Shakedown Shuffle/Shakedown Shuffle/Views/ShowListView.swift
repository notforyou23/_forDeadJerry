import SwiftUI

struct ShowListView: View {
    let shows: [EnrichedShow]
    let emptyMessage: String
    let onShowSelected: (EnrichedShow) -> Void
    @StateObject private var historyManager = ShowHistoryManager.shared
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    @State private var navigateToShow = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Enhanced psychedelic background
            AppTheme.psychedelicGradient(for: .dead)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Shows count header
                HStack {
                    SectionHeaderView(
                        title: "\(shows.count) Shows",
                        accentColor: AppTheme.accentColor(for: .dead)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                if shows.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.accentColor(for: .dead).opacity(0.7))
                            .padding(.top, 40)
                        
                        Text(emptyMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(shows, id: \.identifier) { show in
                                Button(action: {
                                    onShowSelected(show)
                                    navigateToShow = true
                                }) {
                                    HStack {
                                        ShowRowView(show: show)
                                        
                                        Button(action: {
                                            historyManager.toggleFavorite(show)
                                        }) {
                                            Image(systemName: historyManager.isFavorite(show) ? "heart.fill" : "heart")
                                                .foregroundColor(historyManager.isFavorite(show) ? .red : .gray)
                                                .font(.system(size: 18))
                                                .padding(8)
                                                .background(Circle().fill(Color.black.opacity(0.3)))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 8)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToShow) {
            PlayerView(showViewModel: showViewModel, audioPlayer: audioPlayer)
        }
    }
} 
#Preview {
    PlayerControlsView(
        audioPlayer: AudioPlayerService.shared,
        onRandomShow: {}
    )
    .preferredColorScheme(.dark)
}
