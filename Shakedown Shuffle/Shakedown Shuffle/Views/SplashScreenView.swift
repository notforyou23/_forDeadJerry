import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Ambient background effect
            RadialGradient(
                gradient: AppTheme.mainGradient(for: .dead),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack {
                // Logo
                Image("SplashImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 1 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Random Dead")
                    .font(AppTheme.titleStyle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.textPrimary, AppTheme.textSecondary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isAnimating ? 1 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.top, 20)
                
                // Loading indicator
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                    .padding(.top, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
} 