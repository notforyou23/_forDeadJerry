import SwiftUI

extension View {
    /// A background modifier that attempts to load an image from the app bundle
    func backgroundImage(named imageName: String, opacity: Double = 0.7) -> some View {
        self.background(
            ZStack {
                Color.black
                
                // First try UIImage named
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(opacity)
                } 
                // Next try loading from the bundle
                else if let path = Bundle.main.path(forResource: imageName, ofType: "jpg"),
                        let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(opacity)
                }
                // Finally, fallback to a gradient
                else {
                    RadialGradient(
                        gradient: AppTheme.mainGradient(for: .dead),
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 400
                    )
                }
                
                // Overlay to ensure text readability
                Color.black.opacity(0.4)
            }
            .ignoresSafeArea()
        )
    }
} 