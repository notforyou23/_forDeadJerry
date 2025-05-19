//
//  ContentView.swift
//  Shakedown Shuffle
//
//  Created by Jason on 3/18/25.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var showViewModel = ShowViewModel()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.5),
                        Color.blue.opacity(0.4),
                        Color.orange.opacity(0.3),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
                .ignoresSafeArea()
                
                if isLoading {
                    // Loading state
                    VStack {
                        ProgressView("Loading shows...")
                            .tint(.white)
                            .foregroundColor(.white)
                            .font(.headline)
                        Text("Getting ready to jam 🎸")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                } else if let error = error {
                    // Error state
                    ErrorView(error: error)
                } else {
                    // Main content
                    MainContentView(showViewModel: showViewModel, audioPlayer: audioPlayer)
                }
            }
            .navigationTitle("Random Dead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: ShowDetailView(show: showViewModel.currentShow)
                    ) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            do {
                try await DatabaseManager.shared.loadData()
                showViewModel.loadRandomShow()
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
}

struct MainContentView: View {
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    
    var body: some View {
        VStack(spacing: 20) {
            // Show Info Header
            if let show = showViewModel.currentShow {
                ShowHeaderView(show: show, showViewModel: showViewModel)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            
            // Player Controls
            PlayerControlsView(
                audioPlayer: audioPlayer,
                onRandomShow: showViewModel.loadRandomShow
            )
            
            // Track List
            TrackListView(showViewModel: showViewModel, audioPlayer: audioPlayer)
                .padding(.top, 10)
        }
        .padding(.horizontal)
    }
}

struct TrackListView: View {
    @ObservedObject var showViewModel: ShowViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    
    var indexedTracks: [(index: Int, track: Track)] {
        return (showViewModel.currentShow?.tracks ?? []).enumerated().map { (index, track) in
            return (index: index, track: track)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(indexedTracks, id: \.track.filename) { indexedTrack in
                    TrackRowView(
                        track: indexedTrack.track,
                        index: indexedTrack.index,
                        isPlaying: indexedTrack.index == audioPlayer.currentIndex && audioPlayer.isPlaying
                    )
                    .onTapGesture {
                        playTrack(at: indexedTrack.index)
                    }
                    Divider()
                        .background(Color.white.opacity(0.3))
                }
            }
        }
        .padding(.top, 10)
    }
    
    private func playTrack(at index: Int) {
        if audioPlayer.currentIndex != index {
            audioPlayer.playTrack(at: index)
        } else {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
        }
    }
}

struct TrackRowView: View {
    let track: Track
    let index: Int
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .foregroundColor(isPlaying ? .blue : .white)
                    .font(.headline)
            }
            
            Spacer()
            
            Text(track.length)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isPlaying ? Color.purple.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}

struct ShowHeaderView: View {
    let show: EnrichedShow
    @ObservedObject var showViewModel: ShowViewModel
    
    private func formatShowDate(_ identifier: String) -> String {
        // Extract date from identifier (format: gdYY-MM-DD)
        let dateStr = String(identifier.dropFirst(2)) // Remove "gd" prefix
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yy-MM-dd"
        
        if let date = dateFormatter.date(from: dateStr) {
            dateFormatter.dateFormat = "MMMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        
        // Fallback to metadata title if date parsing fails, removing "Grateful Dead Live at" prefix
        if show.metadata.title.hasPrefix("Grateful Dead Live at ") {
            return String(show.metadata.title.dropFirst("Grateful Dead Live at ".count))
        }
        return show.metadata.title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatShowDate(show.identifier))
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            Text("\(show.location.venue), \(show.location.city)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
