import SwiftUI

struct LandingView: View {
    @StateObject private var showViewModel = ShowViewModel()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var jerryViewModel = JerryShowViewModel.shared
    @StateObject private var youtubeViewModel = YouTubeShowViewModel.shared
    @StateObject private var playerCoordinator = PlayerCoordinator.shared
    @State private var isLoading = true
    @State private var error: Error?
    @State private var navigateToShow = false
    @State private var navigateToJerryShow = false
    @State private var navigateToYouTubeShow = false
    @State private var selectedSection: AppSection = .dead // Default section for background styles
    
    // Create adapters for unified player controls
    private var deadPlaybackAdapter: DeadPlaybackAdapter {
        DeadPlaybackAdapter(audioPlayer: audioPlayer)
    }
    
    private var jerryPlaybackAdapter: JerryPlaybackAdapter {
        JerryPlaybackAdapter(viewModel: jerryViewModel)
    }

    // Determine the section for the currently active player
    private var activePlayerSection: AppSection {
        switch playerCoordinator.getActivePlayerDestination() {
        case .dead:
            return .dead
        case .jerry:
            return .jerry
        case .youtube:
            return .youtube
        case .none:
            return .dead
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Enhanced psychedelic gradient background
                ZStack {
                    // Use AppTheme.mainGradient for background
                    RadialGradient(
                        gradient: AppTheme.mainGradient(for: selectedSection),
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
                                    AppTheme.accentColor(for: selectedSection).opacity(0.25)
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
                                    AppTheme.accentColor(for: selectedSection).opacity(0.25)
                                )
                                .frame(width: 250, height: 250)
                                .blur(radius: 95)
                                .offset(x: 50, y: 100)
                        }
                    }
                    .ignoresSafeArea()
                }
                
                // Content
                if isLoading {
                    ProgressView("Loading shows...")
                        .tint(.white)
                        .foregroundColor(AppTheme.textPrimary)
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 25) {
                                // Enhanced App Title
                                Text("Shakedown\nShuffle")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .shadow(color: AppTheme.accentColor(for: selectedSection).opacity(0.8), radius: 20, x: 0, y: 0)
                                    .shadow(color: AppTheme.accentColor(for: selectedSection).opacity(0.4), radius: 40, x: 0, y: 0)
                                    .padding(.vertical, 24)
                                    .appStyle(.basic, color: AppTheme.accentColor(for: selectedSection))
                                
                                // Main Buttons Container with enhanced styling
                                VStack(spacing: 18) {
                                    // Now Playing Button (only show if something is playing)
                                    if playerCoordinator.hasActivePlayer() {
                                        let activeSection = activePlayerSection
                                        
                                        Button(action: {
                                            // Navigate to appropriate player
                                            navigateToActivePlayer()
                                            
                                            // Update selected section based on active player
                                            withAnimation(.easeInOut(duration: 0.5)) {
                                                selectedSection = activeSection
                                            }
                                        }) {
                                            enhancedButtonContent(
                                                icon: "play.circle.fill",
                                                text: "Now Playing",
                                                section: activeSection
                                            )
                                        }
                                        .buttonStyle(EnhancedButtonStyle(section: activeSection))
                                    }
                                    
                                    // Grateful Dead Button
                                    NavigationLink(destination: GratefulDeadLandingView(
                                        showViewModel: showViewModel,
                                        audioPlayer: audioPlayer
                                    )) {
                                        enhancedButtonContent(
                                            icon: "music.note.list",
                                            text: "Grateful Dead",
                                            section: .dead
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .dead))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .dead
                                        }
                                    }
                                    
                                    // Jerry Garcia Button
                                    NavigationLink(destination: JerryLandingView()) {
                                        enhancedButtonContent(
                                            icon: "guitars.fill",
                                            text: "Jerry Garcia",
                                            section: .jerry
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .jerry))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .jerry
                                        }
                                    }

                                    // YouTube Button
                                    NavigationLink(destination: YouTubeLandingView()) {
                                        enhancedButtonContent(
                                            icon: "play.rectangle", 
                                            text: "YouTube", 
                                            section: .youtube
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .youtube))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .youtube
                                        }
                                    }
                                    
                                    // Today's Shows Button
                                    NavigationLink(destination: UnifiedShowsOnThisDayView(showViewModel: showViewModel)) {
                                        enhancedButtonContent(
                                            icon: "calendar.circle.fill",
                                            text: "Today's Shows",
                                            section: .dead
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .dead))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .dead
                                        }
                                    }
                                    .onAppear {
                                        _ = showViewModel.loadTodaysShows()
                                    }
                                    
                                    // Stats Button
                                    NavigationLink(destination: ListeningStatsView(showViewModel: showViewModel, audioPlayer: audioPlayer)) {
                                        enhancedButtonContent(
                                            icon: "chart.bar.fill",
                                            text: "Listening Stats",
                                            section: .dead
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .dead))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .dead
                                        }
                                    }
                                    
                                    // Jerry Statistics Button
                                    NavigationLink(destination: JerryStatsView()) {
                                        enhancedButtonContent(
                                            icon: "chart.pie.fill",
                                            text: "Jerry Statistics",
                                            section: .jerry
                                        )
                                    }
                                    .buttonStyle(EnhancedButtonStyle(section: .jerry))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            selectedSection = .jerry
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToShow) {
                PlayerView(showViewModel: showViewModel, audioPlayer: audioPlayer)
            }
            .navigationDestination(isPresented: $navigateToJerryShow) {
                if let currentShow = jerryViewModel.currentShow {
                    JerryPlayerView(show: currentShow)
                }
            }
            .navigationDestination(isPresented: $navigateToYouTubeShow) {
                if let current = YouTubeShowViewModel.shared.currentShow {
                    YouTubePlayerView(show: current)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            do {
                // Load Dead, Jerry, and YouTube data in parallel
                async let deadData: Void = DatabaseManager.shared.loadData()
                async let jerryData: Void = jerryViewModel.loadShows()
                async let ytData: Void = YouTubeShowViewModel.shared.loadShows()

                // Wait for all to complete
                _ = try await (deadData, jerryData, ytData)
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    // Helper function to navigate to the currently active player
    private func navigateToActivePlayer() {
        switch playerCoordinator.getActivePlayerDestination() {
        case .dead:
            navigateToShow = true
        case .jerry:
            // Always use the new improved player for the Now Playing button
            navigateToJerryShow = true
        case .youtube:
            navigateToYouTubeShow = true
        case .none:
            break // Do nothing
        }
    }
    
    // Enhanced button content matching ListeningStatsView aesthetic
    @ViewBuilder
    private func enhancedButtonContent(icon: String, text: String, section: AppSection) -> some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(AppTheme.accentColor(for: section).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .foregroundColor(AppTheme.accentColor(for: section))
                    .font(.system(size: 20, weight: .semibold))
            }
            
            Text(text)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.accentColor(for: section).opacity(0.6))
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
    
    // Legacy button content for backwards compatibility
    @ViewBuilder
    private func buttonContent(icon: String, text: String, section: AppSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
            Text(text)
                .font(.system(size: 24, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }
}

// Enhanced button style that matches ListeningStatsView aesthetic
struct EnhancedButtonStyle: ButtonStyle {
    let section: AppSection
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppTheme.accentColor(for: section).opacity(0.6),
                                        AppTheme.accentColor(for: section).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: AppTheme.accentColor(for: section).opacity(0.3),
                        radius: 10, 
                        x: 0, 
                        y: 5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    LandingView()
}
