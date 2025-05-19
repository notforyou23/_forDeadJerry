import SwiftUI

struct JerryShowsOnThisDayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = JerryShowViewModel.shared
    @State private var selectedDate = Date()
    
    private var showsOnSelectedDate: [JerryShow] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        
        return viewModel.shows.filter { show in
            let components = show.date.split(separator: "/")
            guard components.count >= 2,
                  let showMonth = Int(components[0]),
                  let showDay = Int(components[1]) else {
                return false
            }
            return showMonth == month && showDay == day
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                if showsOnSelectedDate.isEmpty {
                    ContentUnavailableView(
                        "No Shows Found",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("There are no Jerry Garcia shows on this date")
                    )
                    .appStyle(.basic, color: AppTheme.accentColor(for: .jerry))
                } else {
                    List(showsOnSelectedDate) { show in
                        NavigationLink(destination: JerryPlayerView(show: show)) {
                            JerryShowRow(show: show)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Shows On This Day")
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
    JerryShowsOnThisDayView()
} 