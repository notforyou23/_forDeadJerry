import SwiftUI

extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    let background = Color("Background")
    let primaryAccent = Color("PrimaryAccent")
    let secondaryAccent = Color("SecondaryAccent")
    let highlight = Color("Highlight")
    let text = Color("Text")
    
    // Gradients
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var highlightGradient: LinearGradient {
        LinearGradient(
            colors: [highlight.opacity(0.8), primaryAccent],
            startPoint: .top,
            endPoint: .bottom
        )
    }
} 