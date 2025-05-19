//
//  Shakedown_ShuffleApp.swift
//  Shakedown Shuffle
//
//  Created by Jason on 3/18/25.
//
import SwiftUI

@main
struct Shakedown_ShuffleApp: App {
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    SplashScreenView()
                } else {
                    LandingView()
                }
                // Floating YouTube mini player overlay
                FloatingYouTubePlayerView()
            }
            .onAppear {
                // Simulate loading time - in real app this would be actual data loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        isLoading = false
                    }
                }
            }
        }
    }
}
