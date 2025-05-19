import SwiftUI

struct ShowHistoryView: View {
    @StateObject private var historyManager = ShowHistoryManager.shared
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    @State private var selectedTab = 0
    @State private var navigateToShow = false
    
    var body: some View {
        VStack {
            Picker("View", selection: $selectedTab) {
                Text("History").tag(0)
                Text("Favorites").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                ShowListView(
                    shows: historyManager.recentShows,
                    emptyMessage: "No Recent Shows",
                    onShowSelected: { show in
                        showViewModel.setShow(show)
                        navigateToShow = true
                    },
                    showViewModel: showViewModel,
                    audioPlayer: audioPlayer
                )
            } else {
                ShowListView(
                    shows: historyManager.favoriteShows,
                    emptyMessage: "No Favorite Shows",
                    onShowSelected: { show in
                        showViewModel.setShow(show)
                        navigateToShow = true
                    },
                    showViewModel: showViewModel,
                    audioPlayer: audioPlayer
                )
            }
            
            // Mini player removed
        }
        .navigationTitle(selectedTab == 0 ? "History" : "Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToShow) {
            PlayerView(showViewModel: showViewModel, audioPlayer: audioPlayer)
        }
    }
} 