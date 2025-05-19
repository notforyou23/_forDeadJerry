import SwiftUI

// Central theme for both Dead and Jerry sections
enum AppSection {
    case dead
    case jerry
    case all // For combined views showing both Dead and Jerry content
}

struct AppTheme {
    // Common colors
    static let background = Color.black
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    
    // Section-specific accent colors
    static func accentColor(for section: AppSection) -> Color {
        switch section {
        case .jerry:
            return Color(red: 0.4, green: 0.6, blue: 0.8) // Softer blue-purple
        case .dead:
            return Color(red: 0.8, green: 0.2, blue: 0.4) // Softer magenta
        case .all:
            return Color.gray
        }
    }
    
    // Gradient backgrounds
    static func mainGradient(for section: AppSection) -> Gradient {
        switch section {
        case .jerry:
            return Gradient(colors: [
                Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.7),   // Purple
                Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.7),   // Blue
                Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.7),   // Light Blue
                Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.7),   // Lavender
                Color(red: 0.8, green: 0.2, blue: 0.6).opacity(0.7),   // Magenta
                Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.7)    // Purple
            ])
        case .dead:
            return Gradient(colors: [
                Color(red: 0.8, green: 0.2, blue: 0.4).opacity(0.7),   // Magenta
                Color(red: 0.6, green: 0.2, blue: 0.6).opacity(0.7),   // Purple
                Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.7),   // Deep Blue
                Color(red: 0.8, green: 0.2, blue: 0.4).opacity(0.7)    // Magenta
            ])
        case .all:
            return Gradient(colors: [
                Color(red: 0.8, green: 0.2, blue: 0.4).opacity(0.7),   // Magenta
                Color(red: 0.6, green: 0.2, blue: 0.6).opacity(0.7),   // Purple
                Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.7),   // Deep Blue
                Color(red: 0.8, green: 0.2, blue: 0.4).opacity(0.7)    // Magenta
            ])
        }
    }
    
    // Enhanced psychedelic gradient
    static func psychedelicGradient(for section: AppSection) -> some View {
        let accent = accentColor(for: section)
        let secondaryColor = section == .dead ? Color.blue : Color.purple
        
        return ZStack {
            // Base radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    accent.opacity(0.5),
                    secondaryColor.opacity(0.3),
                    Color.black
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 650
            )
            .ignoresSafeArea()
            
            // Secondary accent gradients for visual depth
            VStack {
                HStack {
                    Circle()
                        .fill(accent.opacity(0.25))
                        .frame(width: 200, height: 200)
                        .blur(radius: 85)
                        .offset(x: -30, y: -60)
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Circle()
                        .fill(secondaryColor.opacity(0.25))
                        .frame(width: 250, height: 250)
                        .blur(radius: 95)
                        .offset(x: 50, y: 100)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // Button styling
    static func buttonGradient(for section: AppSection) -> LinearGradient {
        let accent = accentColor(for: section)
        return LinearGradient(
            colors: [
                accent.opacity(0.9),
                accent.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Progress bar styling
    static func progressBarStyle(for section: AppSection) -> Color {
        accentColor(for: section)
    }
    
    // Common text styles
    static let titleStyle = Font.system(size: 44, weight: .bold, design: .rounded)
    static let headlineStyle = Font.headline
    static let subheadlineStyle = Font.subheadline
    
    // Enhanced transition animations
    static func pageTransition(for section: AppSection) -> AnyTransition {
        let direction: Edge = [.leading, .trailing, .top, .bottom].randomElement() ?? .trailing
        
        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: direction))
                .combined(with: .scale(scale: 0.95)),
            removal: .opacity
                .combined(with: .scale(scale: 1.05))
        )
    }
    
    // Card styling
    static func cardStyle(for section: AppSection) -> some ViewModifier {
        CardStyleModifier(section: section)
    }
}

// Card style modifier for consistent styling
struct CardStyleModifier: ViewModifier {
    let section: AppSection
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppTheme.accentColor(for: section).opacity(0.4),
                                        AppTheme.accentColor(for: section).opacity(0.1)
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
    }
}

// Common button style used across the app
struct AppButtonStyle: ButtonStyle {
    let section: AppSection
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.buttonGradient(for: section))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(
                color: AppTheme.accentColor(for: section).opacity(0.3),
                radius: 10, 
                x: 0, 
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Extension to easily apply card style
extension View {
    func cardStyle(for section: AppSection) -> some View {
        self.modifier(AppTheme.cardStyle(for: section))
    }
} 