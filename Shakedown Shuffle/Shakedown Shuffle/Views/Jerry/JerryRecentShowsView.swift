import SwiftUI

struct JerryRecentShowsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = JerryShowViewModel.shared
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.recentShows.isEmpty {
                    ContentUnavailableView(
                        "No Recent Shows",
                        systemImage: "clock",
                        description: Text("Shows you listen to will appear here")
                    )
                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.recentShows) { show in
                        NavigationLink(destination: JerryPlayerView(show: show)) {
                            JerryShowRow(show: show)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Recent Shows")
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
    JerryRecentShowsView()
} 