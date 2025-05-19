import SwiftUI

struct UnifiedShowsOnThisDayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var showViewModel: ShowViewModel
    @StateObject private var jerryViewModel = JerryShowViewModel.shared
    @State private var selectedDate = Date()
    @State private var navigateToShow = false
    @State private var navigateToJerryShow = false
    @State private var selectedSection: AppSection = .all
    @State private var selectedJerryShow: JerryShow?
    
    // MARK: - Computed Properties
    
    // Dead shows on selected date
    private var deadShowsOnSelectedDate: [EnrichedShow] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        
        guard let shows = DatabaseManager.shared.getAllShows() else { return [] }
        
        return shows.values.filter { show in
            let components = show.identifier.split(separator: "-")
            guard components.count >= 2 else { return false }
            
            let showMonth = String(components[1])
            let showDayComponent = components[2]
            let showDay = String(showDayComponent.prefix(2))
            
            let showMMDD = "\(showMonth)-\(showDay)"
            return showMMDD == dateKey
        }
        .sorted { $0.identifier < $1.identifier }
    }
    
    // Jerry shows on selected date
    private var jerryShowsOnSelectedDate: [JerryShow] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        
        return jerryViewModel.shows.filter { show in
            let components = show.date.split(separator: "/")
            guard components.count >= 2,
                  let showMonth = Int(components[0]),
                  let showDay = Int(components[1]) else {
                return false
            }
            return showMonth == month && showDay == day
        }
    }
    
    private var totalShowsCount: Int {
        deadShowsOnSelectedDate.count + jerryShowsOnSelectedDate.count
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Main View
    var body: some View {
        // Simple linear structure to avoid nested ZStacks that can cause overlap
        VStack(spacing: 0) {
            // Background - only as a color, gradient handled differently
            Color.black
                .ignoresSafeArea()
                .overlay(
                    // Gradient background
                    RadialGradient(
                        gradient: selectedSection == .dead ? 
                            AppTheme.mainGradient(for: .dead) : 
                            selectedSection == .jerry ? 
                                AppTheme.mainGradient(for: .jerry) : 
                                Gradient(colors: [.purple.opacity(0.4), .blue.opacity(0.3), .orange.opacity(0.3)]),
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 400
                    )
                    .ignoresSafeArea()
                )
                .overlay(
                    // Main content overlay
                    VStack(spacing: 0) {
                        // Top fixed header
                        headerSection
                        
                        // Bottom content section (empty state or shows list)
                        if totalShowsCount == 0 {
                            emptyStateSection
                        } else {
                            listSection
                        }
                    }
                )
        }
        .navigationTitle("Shows On This Day")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToShow) {
            PlayerView(showViewModel: showViewModel, audioPlayer: AudioPlayerService.shared)
        }
        .navigationDestination(isPresented: $navigateToJerryShow) {
            if let show = selectedJerryShow {
                JerryPlayerView(show: show)
            }
        }
    }
    
    // MARK: - View Sections
    
    // Header section with date picker and filter
    private var headerSection: some View {
        VStack(spacing: 8) {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .onChange(of: selectedDate) { oldValue, newValue in
                selectedSection = .all
            }
            
            Picker("Section", selection: $selectedSection) {
                Text("All").tag(AppSection.all)
                Text("Dead").tag(AppSection.dead)
                Text("Jerry").tag(AppSection.jerry)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.black.opacity(0.3))
    }
    
    // Empty state when no shows found
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No shows found for \(dateString)")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Neither the Grateful Dead nor Jerry Garcia performed on this day in history, or the data is unavailable.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal, 40)
            
            Button(action: {
                showViewModel.loadRandomShow()
                navigateToShow = true
            }) {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Try a Random Show")
                }
                .padding()
                .background(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
    }
    
    // Shows list section
    private var listSection: some View {
        // Single scrollview with no nested scrollable areas
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Shows count header
                Text("\(totalShowsCount) show\(totalShowsCount == 1 ? "" : "s") on \(dateString)")
                    .appStyle(.basic)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // Dead shows section
                if (selectedSection == .dead || selectedSection == .all) && !deadShowsOnSelectedDate.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Grateful Dead", count: deadShowsOnSelectedDate.count)
                        
                        ForEach(deadShowsOnSelectedDate, id: \.identifier) { show in
                            Button(action: {
                                showViewModel.setShow(show)
                                navigateToShow = true
                            }) {
                                deadShowCard(for: show)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Jerry shows section
                if (selectedSection == .jerry || selectedSection == .all) && !jerryShowsOnSelectedDate.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Jerry Garcia", count: jerryShowsOnSelectedDate.count)
                        
                        ForEach(jerryShowsOnSelectedDate) { show in
                            Button(action: {
                                selectedJerryShow = show
                                navigateToJerryShow = true
                            }) {
                                jerryShowCard(for: show)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Bottom spacer to ensure content isn't cut off
                Spacer(minLength: 80)
            }
        }
    }
    
    // Section header
    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("(\(count))")
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // Dead show card
    @ViewBuilder
    private func deadShowCard(for show: EnrichedShow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Remove "Grateful Dead Live at" prefix if present
            let title = show.metadata.title.hasPrefix("Grateful Dead Live at ") 
                ? String(show.metadata.title.dropFirst("Grateful Dead Live at ".count))
                : show.metadata.title
            
            Text(title)
                .appStyle(.basic)
                .padding(.bottom, 2)
            
            Text(show.location.venue)
                .appStyle(.basic)
                .lineLimit(1)
            
            Text("\(show.location.city), \(show.location.state)")
                .appStyle(.basic)
                .lineLimit(1)
            
            HStack {
                Label(show.recordingInfo.sourceType, systemImage: "waveform")
                    .appStyle(.basic)
                    .lineLimit(1)
                
                Spacer()
                
                Label(String(format: "%.1f", show.recordingInfo.avgRating), systemImage: "star.fill")
                    .appStyle(.basic)
            }
            .padding(.top, 4)
        }
        .padding(12)
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
    
    // Jerry show card
    @ViewBuilder
    private func jerryShowCard(for show: JerryShow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(show.date)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            Text(show.venue)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            
            Text(show.location)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
            
            // Status indicators
            HStack(spacing: 8) {
                if show.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if show.isPartiallyPlayed {
                    Label("In Progress", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if show.isFavorite {
                    Label("Favorite", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appStyle(show.isFavorite ? .concert : .basic, color: AppTheme.accentColor(for: .jerry))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    
    // Format Dead show date
    private func formatDeadDate(_ date: String) -> String {
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
    UnifiedShowsOnThisDayView(showViewModel: ShowViewModel())
} 