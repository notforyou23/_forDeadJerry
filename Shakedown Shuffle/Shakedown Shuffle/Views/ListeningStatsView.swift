import SwiftUI

struct ListeningStatsView: View {
    @StateObject private var unifiedHistoryManager = UnifiedHistoryManager.shared
    @StateObject private var deadHistoryManager = ShowHistoryManager.shared
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    @StateObject private var jerryViewModel = JerryShowViewModel.shared
    @State private var navigateToShow = false
    @State private var navigateToJerryShow = false
    // Fallback values in case dynamic calculation fails
    private let fallbackDeadShowCount = 2071
    private let fallbackJerryShowCount = 1600
    @State private var showingResetAlert = false
    @State private var selectedSection: AppSection = .dead
    
    // Computed properties for real show counts with fallbacks
    private var deadTotalShows: Int {
        return DatabaseManager.shared.getAllShows()?.count ?? fallbackDeadShowCount
    }
    
    private var jerryTotalShows: Int {
        return jerryViewModel.shows.count > 0 ? jerryViewModel.shows.count : fallbackJerryShowCount
    }
    
    var body: some View {
        ZStack {
            // Enhanced psychedelic gradient background
            ZStack {
                // Base gradient layer
            RadialGradient(
                gradient: Gradient(colors: [
                        selectedSection == .dead ? Color.purple.opacity(0.5) : Color.orange.opacity(0.5),
                        selectedSection == .dead ? Color.blue.opacity(0.3) : Color.purple.opacity(0.3),
                        selectedSection == .dead ? Color.black : Color.black
                ]),
                center: .center,
                    startRadius: 100,
                    endRadius: 650
            )
            .ignoresSafeArea()
                
                // Dynamic animated noise texture for psychedelic effect
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                // Secondary accent gradients
                VStack {
                    HStack {
                        Circle()
                            .fill(
                                selectedSection == .dead ? 
                                    Color.purple.opacity(0.25) : 
                                    Color.orange.opacity(0.25)
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 85)
                            .offset(x: -30, y: -60)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Circle()
                            .fill(
                                selectedSection == .dead ? 
                                    Color.blue.opacity(0.25) : 
                                    Color.purple.opacity(0.25)
                            )
                            .frame(width: 250, height: 250)
                            .blur(radius: 95)
                            .offset(x: 50, y: 100)
                    }
                }
                .ignoresSafeArea()
            }
            
            // Existing content
            ScrollView {
            VStack {
                    // Section picker
                    Picker("Section", selection: $selectedSection) {
                        Text("Grateful Dead").tag(AppSection.dead)
                        Text("Jerry Garcia").tag(AppSection.jerry)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                // List content
                    if selectedSection == .dead {
                        deadStatsList
                    } else {
                        jerryStatsList
                    }
                }
            }
        }
        .navigationTitle("Listening Stats")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToShow) {
            PlayerView(showViewModel: showViewModel, audioPlayer: audioPlayer)
        }
        .navigationDestination(isPresented: $navigateToJerryShow) {
            if let currentShow = jerryViewModel.currentShow {
                JerryPlayerView(show: currentShow)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Dismiss the current view to return to the main landing page
                    // This assumes we're in a NavigationStack and going back to root
                    popToRootView()
                }) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.white)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingResetAlert = true
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Reset Stats", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                if selectedSection == .dead {
                    deadHistoryManager.resetStats()
                } else {
                    // Reset Jerry stats by calling appropriate methods
                    // Replacing direct modification with appropriate method calls
                    jerryViewModel.resetHistory()
                    // Also update UnifiedHistoryManager
                    unifiedHistoryManager.resetJerryHistory()
                }
            }
        } message: {
            Text("This will reset all listening stats for \(selectedSection == .dead ? "Grateful Dead" : "Jerry Garcia") shows, including history, favorites, completed and partial shows. This cannot be undone.")
        }
    }
    
    // Grateful Dead stats list
    private var deadStatsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Enhanced Show Stats Card
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Shows Progress", accentColor: AppTheme.accentColor(for: .dead))
                        .padding(.horizontal)
                    
                    // Progress Cards with visually enhanced styling
                    VStack(spacing: 12) {
                        NavigationLink(destination: ShowListView(
                            shows: deadHistoryManager.getCompletedShows(),
                            emptyMessage: "No Completed Shows",
                            onShowSelected: { show in
                                showViewModel.setShow(show)
                                navigateToShow = true
                            },
                            showViewModel: showViewModel,
                            audioPlayer: audioPlayer
                        )) {
                            EnhancedProgressRow(
                                title: "Complete Shows",
                                count: deadHistoryManager.completedShows.count,
                                total: deadTotalShows,
                                iconName: "checkmark.circle.fill",
                                color: .green,
                                section: .dead
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: ShowListView(
                            shows: deadHistoryManager.getPartialShows(),
                            emptyMessage: "No Partial Shows",
                            onShowSelected: { show in
                                showViewModel.setShow(show)
                                navigateToShow = true
                            },
                            showViewModel: showViewModel,
                            audioPlayer: audioPlayer
                        )) {
                            EnhancedProgressRow(
                                title: "In Progress",
                                count: deadHistoryManager.partialShows.count,
                                total: deadTotalShows,
                                iconName: "clock.fill",
                                color: .orange,
                                section: .dead
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Total Progress
                        EnhancedProgressRow(
                            title: "Total Listening Progress",
                            count: deadHistoryManager.completedShows.count + deadHistoryManager.partialShows.count,
                            total: deadTotalShows,
                            iconName: "headphones",
                            color: Color.purple,
                            section: .dead
                        )
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Collection Stats
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Collection", accentColor: AppTheme.accentColor(for: .dead))
                        .padding(.horizontal)
                    
                    // Stats cards with visual enhancements
                    VStack(spacing: 12) {
                        NavigationLink(destination: ShowListView(
                            shows: deadHistoryManager.recentShows,
                            emptyMessage: "No Recent Shows",
                            onShowSelected: { show in
                                showViewModel.setShow(show)
                                navigateToShow = true
                            },
                            showViewModel: showViewModel,
                            audioPlayer: audioPlayer
                        )) {
                            EnhancedStatCard(
                                title: "Recent Shows",
                                value: "\(deadHistoryManager.recentShows.count)",
                                iconName: "clock.arrow.circlepath",
                                section: .dead
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: ShowListView(
                            shows: deadHistoryManager.favoriteShows,
                            emptyMessage: "No Favorite Shows",
                            onShowSelected: { show in
                                showViewModel.setShow(show)
                                navigateToShow = true
                            },
                            showViewModel: showViewModel,
                            audioPlayer: audioPlayer
                        )) {
                            EnhancedStatCard(
                                title: "Favorite Shows",
                                value: "\(deadHistoryManager.favoriteShows.count)",
                                iconName: "heart.fill",
                                section: .dead
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        EnhancedStatCard(
                            title: "Completion Rate",
                            value: String(format: "%.1f%%", Double(deadHistoryManager.completedShows.count) / Double(deadTotalShows) * 100),
                            iconName: "chart.bar.fill",
                            section: .dead
                        )
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Era Breakdown - NEW SECTION
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Eras Explored", accentColor: AppTheme.accentColor(for: .dead))
                        .padding(.horizontal)
                    
                    // Era breakdown cards
                    VStack(spacing: 12) {
                        let categories = DatabaseManager.shared.getShowCategories()?.categories
                        
                        if let categories = categories {
                            // Pigpen Era (1967-1972)
                            let pigpenShows = categories.byEra.pigpen
                            let pigpenPlayed = deadHistoryManager.completedShows.filter { id in
                                pigpenShows.contains { id.contains($0) }
                            }.count
                            
                            EraProgressView(
                                title: "Pigpen Era",
                                subtitle: "1967-1972",
                                count: pigpenPlayed,
                                total: pigpenShows.count,
                                iconName: "music.quarternote.3",
                                section: .dead
                            )
                            
                            // Keith Era (1971-1979)
                            let keithShows = categories.byEra.keith
                            let keithPlayed = deadHistoryManager.completedShows.filter { id in
                                keithShows.contains { id.contains($0) }
                            }.count
                            
                            EraProgressView(
                                title: "Keith Era",
                                subtitle: "1971-1979",
                                count: keithPlayed,
                                total: keithShows.count,
                                iconName: "pianokeys",
                                section: .dead
                            )
                            
                            // Brent Era (1979-1990)
                            let brentShows = categories.byEra.brent
                            let brentPlayed = deadHistoryManager.completedShows.filter { id in
                                brentShows.contains { id.contains($0) }
                            }.count
                            
                            EraProgressView(
                                title: "Brent Era",
                                subtitle: "1979-1990",
                                count: brentPlayed,
                                total: brentShows.count,
                                iconName: "keyboard",
                                section: .dead
                            )
                            
                            // Vince Era (1990-1995)
                            let vinceShows = categories.byEra.vince
                            let vincePlayed = deadHistoryManager.completedShows.filter { id in
                                vinceShows.contains { id.contains($0) }
                            }.count
                            
                            EraProgressView(
                                title: "Vince Era",
                                subtitle: "1990-1995",
                                count: vincePlayed,
                                total: vinceShows.count,
                                iconName: "music.note.list",
                                section: .dead
                            )
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Browse All Shows Button
                Button(action: {
                    // No action needed - using NavigationLink instead
                }) {
                    NavigationLink(destination: ShowListView(
                        shows: DatabaseManager.shared.getAllShows()?.values.sorted(by: { $0.identifier > $1.identifier }) ?? [],
                        emptyMessage: "No Shows Available",
                        onShowSelected: { show in
                            showViewModel.setShow(show)
                            navigateToShow = true
                        },
                        showViewModel: showViewModel,
                        audioPlayer: audioPlayer
                    )) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                            Text("Browse All Shows")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.accentColor(for: .dead).opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppTheme.accentColor(for: .dead).opacity(0.4), lineWidth: 1)
                                        )
                                )
                        .foregroundColor(AppTheme.accentColor(for: .dead))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Add some space at bottom
                Spacer()
                    .frame(height: 30)
            }
        }
        .background(Color.clear) // Transparent to show gradient
    }
    
    // Jerry Garcia stats list
    private var jerryStatsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Enhanced Show Stats Card
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Shows Progress", accentColor: AppTheme.accentColor(for: .jerry))
                        .padding(.horizontal)
                    
                    // Progress Cards with visually enhanced styling
                    VStack(spacing: 12) {
                        NavigationLink(destination: JerryShowListView(
                            title: "Completed Shows",
                            shows: getJerryCompletedShows(),
                            emptyMessage: "No Completed Shows"
                        )) {
                            EnhancedProgressRow(
                                title: "Complete Shows",
                                count: jerryViewModel.completedShows.count,
                                total: jerryTotalShows,
                                iconName: "checkmark.circle.fill",
                                color: .green,
                                section: .jerry
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: JerryShowListView(
                            title: "Partial Shows",
                            shows: getJerryPartialShows(),
                            emptyMessage: "No Partial Shows"
                        )) {
                            EnhancedProgressRow(
                                title: "In Progress",
                                count: jerryViewModel.partialShows.count,
                                total: jerryTotalShows,
                                iconName: "clock.fill",
                                color: .orange,
                                section: .jerry
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Total Progress
                        EnhancedProgressRow(
                            title: "Total Listening Progress",
                            count: jerryViewModel.completedShows.count + jerryViewModel.partialShows.count,
                            total: jerryTotalShows,
                            iconName: "headphones",
                            color: Color.orange,
                            section: .jerry
                        )
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Collection Stats
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Collection", accentColor: AppTheme.accentColor(for: .jerry))
                        .padding(.horizontal)
                    
                    // Stats cards with visual enhancements
                    VStack(spacing: 12) {
                        NavigationLink(destination: JerryShowListView(
                            title: "Recent Shows",
                            shows: jerryViewModel.recentShows,
                            emptyMessage: "No Recent Shows"
                        )) {
                            EnhancedStatCard(
                                title: "Recent Shows",
                                value: "\(jerryViewModel.recentShows.count)",
                                iconName: "clock.arrow.circlepath",
                                section: .jerry
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: JerryShowListView(
                            title: "Favorite Shows",
                            shows: jerryViewModel.favoriteShows,
                            emptyMessage: "No Favorite Shows"
                        )) {
                            EnhancedStatCard(
                                title: "Favorite Shows",
                                value: "\(jerryViewModel.favoriteShows.count)",
                                iconName: "heart.fill",
                                section: .jerry
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        EnhancedStatCard(
                            title: "Completion Rate",
                            value: String(format: "%.1f%%", Double(jerryViewModel.completedShows.count) / Double(jerryTotalShows) * 100),
                            iconName: "chart.bar.fill",
                            section: .jerry
                        )
                        
                        // Calculate dates range for played shows
                        Group {
                            let playedShows = getJerryCompletedShows().sorted { $0.date < $1.date }
                            if !playedShows.isEmpty, let firstShow = playedShows.first, let lastShow = playedShows.last {
                                EnhancedStatCard(
                                    title: "Era Span",
                                    value: "\(firstShow.date) to \(lastShow.date)",
                                    iconName: "calendar",
                                    section: .jerry
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Bands breakdown - NEW SECTION
                VStack(spacing: 0) {
                    // Header
                    SectionHeaderView(title: "Jerry Band Stats", accentColor: AppTheme.accentColor(for: .jerry))
                        .padding(.horizontal)
                    
                    // Bands breakdown
                    VStack(spacing: 12) {
                        // JGB shows
                        let jgbShows = jerryViewModel.shows.filter { $0.name.contains("Jerry Garcia Band") }
                        let jgbPlayed = getJerryCompletedShows().filter { $0.name.contains("Jerry Garcia Band") }.count
                        
                        EraProgressView(
                            title: "Jerry Garcia Band",
                            subtitle: "JGB",
                            count: jgbPlayed,
                            total: jgbShows.count,
                            iconName: "guitars",
                            section: .jerry
                        )
                        
                        // Legion of Mary
                        let lomShows = jerryViewModel.shows.filter { $0.name.contains("Legion of Mary") }
                        let lomPlayed = getJerryCompletedShows().filter { $0.name.contains("Legion of Mary") }.count
                        
                        EraProgressView(
                            title: "Legion of Mary",
                            subtitle: "1974-1975",
                            count: lomPlayed,
                            total: lomShows.count,
                            iconName: "music.mic",
                            section: .jerry
                        )
                        
                        // Garcia & Saunders
                        let garciaShows = jerryViewModel.shows.filter { $0.name.contains("Garcia & Saunders") }
                        let garciaPlayed = getJerryCompletedShows().filter { $0.name.contains("Garcia & Saunders") }.count
                        
                        EraProgressView(
                            title: "Garcia & Saunders",
                            subtitle: "1970-1974",
                            count: garciaPlayed,
                            total: garciaShows.count,
                            iconName: "music.note.list",
                            section: .jerry
                        )
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Browse All Shows Button
                Button(action: {
                    
                }) {
                    NavigationLink(destination: JerryShowListView(
                        title: "All Jerry Shows",
                        shows: jerryViewModel.shows.filter { $0.audioFiles?.isEmpty == false },
                        emptyMessage: "No Shows Available"
                    )) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                            Text("Browse All Shows")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .appButtonStyle(.concert, color: AppTheme.accentColor(for: .jerry))
                .padding(.top, 8)
                
                // Add some space at bottom
                Spacer()
                    .frame(height: 30)
            }
        }
        .background(Color.clear) // Transparent to show gradient
    }
    
    // Helper functions for Jerry shows
    private func getJerryCompletedShows() -> [JerryShow] {
        return jerryViewModel.shows.filter { show in
            jerryViewModel.completedShows.contains(show.id)
        }
    }
    
    private func getJerryPartialShows() -> [JerryShow] {
        return jerryViewModel.shows.filter { show in
            jerryViewModel.partialShows.contains(show.id) && !jerryViewModel.completedShows.contains(show.id)
        }
    }
}

// Jerry show list view for stats navigation
struct JerryShowListView: View {
    let title: String
    let shows: [JerryShow]
    let emptyMessage: String
    @StateObject private var jerryViewModel = JerryShowViewModel.shared
    @StateObject private var historyManager = UnifiedHistoryManager.shared
    
    // Search and filter state
    @State private var searchText = ""
    @State private var selectedSortOrder = SortOrder.dateDescending
    @State private var navigateToShow = false
    
    // Filtered and sorted shows
    private var filteredShows: [JerryShow] {
        var result = shows
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { show in
                let searchString = "\(show.date) \(show.venue) \(show.location) \(show.name)".lowercased()
                return searchString.contains(searchText.lowercased())
            }
        }
        
        // Apply sort order
        switch selectedSortOrder {
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .venue:
            result.sort { $0.venue < $1.venue }
        case .location:
            result.sort { $0.location < $1.location }
        }
        
        return result
    }
    
    var body: some View {
        if shows.isEmpty {
            ContentUnavailableView(
                emptyMessage,
                systemImage: "music.note",
                description: Text("No shows found")
            )
        } else {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search shows...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Sort controls
                HStack {
                    Spacer()
                    
                    Menu {
                        Picker("Sort Order", selection: $selectedSortOrder) {
                            Text("Newest First").tag(SortOrder.dateDescending)
                            Text("Oldest First").tag(SortOrder.dateAscending)
                            Text("By Venue").tag(SortOrder.venue)
                            Text("By Location").tag(SortOrder.location)
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .foregroundColor(AppTheme.accentColor(for: .jerry))
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // List of shows with count
                List {
                    Section(header: Text("\(filteredShows.count) shows")) {
                        ForEach(filteredShows) { show in
                            NavigationLink(destination: JerryPlayerView(show: show)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(show.date)
                                        .font(AppTheme.headlineStyle)
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Text("\(show.venue), \(show.location)")
                                        .font(AppTheme.subheadlineStyle)
                                        .foregroundColor(AppTheme.textSecondary)
                                    
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
                                        
                                        if show.audioFiles?.isEmpty == false {
                                            Image(systemName: "music.note")
                                                .foregroundColor(AppTheme.accentColor(for: .jerry))
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
        }
    }
    
    // Enum for sort options
    enum SortOrder {
        case dateAscending
        case dateDescending
        case venue
        case location
    }
}

// Enhanced Progress Row with more visual polish
struct EnhancedProgressRow: View {
    let title: String
    let count: Int
    let total: Int
    let iconName: String
    let color: Color
    let section: AppSection
    
    private var progress: Double {
        Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .foregroundColor(color)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(count) of \(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Percentage with circular progress
                ZStack {
                    Circle()
                        .stroke(
                            color.opacity(0.3),
                            lineWidth: 4
                        )
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            color,
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round
                            )
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 10)
                
                // Break up the complex width calculation
                let progressPercentage = CGFloat(progress)
                let screenWidth = UIScreen.main.bounds.width
                let calculatedWidth = progressPercentage * (screenWidth - 70)
                let finalWidth = max(20, calculatedWidth)
                
                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color,
                                color.opacity(0.7)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: finalWidth, height: 10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.6),
                                    color.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// Enhanced Stat Card
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let iconName: String
    let section: AppSection
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(AppTheme.accentColor(for: section).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .foregroundColor(AppTheme.accentColor(for: section))
                    .font(.system(size: 20, weight: .semibold))
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accentColor(for: section))
            }
            
            Spacer()
            
            // Arrow indicator
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.accentColor(for: section).opacity(0.6))
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.accentColor(for: section).opacity(0.6),
                                    AppTheme.accentColor(for: section).opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// Era Progress View
struct EraProgressView: View {
    let title: String
    let subtitle: String
    let count: Int
    let total: Int
    let iconName: String
    let section: AppSection
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(AppTheme.accentColor(for: section).opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .foregroundColor(AppTheme.accentColor(for: section))
                        .font(.system(size: 16, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(count) of \(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accentColor(for: section))
                }
            }
            
            // Progress bar with simplified calculation
                ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                // Break up the complex width calculation
                let progressPercentage = CGFloat(progress)
                let availableWidth = UIScreen.main.bounds.width - 80
                let calculatedWidth = progressPercentage * availableWidth
                let finalWidth = max(10, calculatedWidth)
                
                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppTheme.accentColor(for: section),
                                AppTheme.accentColor(for: section).opacity(0.7)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: finalWidth, height: 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.accentColor(for: section).opacity(0.4),
                                    AppTheme.accentColor(for: section).opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// Search bar component with enhanced styling
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(text.isEmpty ? .gray : Color.theme.primaryAccent)
                .font(.system(size: 18, weight: .medium))
                .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEditing = true
                    }
                }
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.secondarySystemBackground).opacity(0.8))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isEditing ? Color.theme.primaryAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// Enhanced section header view
struct SectionHeaderView: View {
    let title: String
    let accentColor: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                accentColor.opacity(0.1),
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)
            }
        )
        .cornerRadius(8)
    }
}

#Preview {
    ListeningStatsView(
        showViewModel: ShowViewModel(),
        audioPlayer: AudioPlayerService.shared
    )
}

extension View {
    func popToRootView() {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}
