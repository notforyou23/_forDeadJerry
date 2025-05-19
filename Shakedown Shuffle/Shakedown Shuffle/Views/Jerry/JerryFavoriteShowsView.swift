import SwiftUI

struct JerryFavoriteShowsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = JerryShowViewModel.shared
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.favoriteShows.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "heart",
                        description: Text("Your favorite shows will appear here")
                    )
                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.favoriteShows) { show in
                        NavigationLink(destination: JerryPlayerView(show: show)) {
                            JerryShowRow(show: show)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Favorite Shows")
            .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    JerryFavoriteShowsView()
} 