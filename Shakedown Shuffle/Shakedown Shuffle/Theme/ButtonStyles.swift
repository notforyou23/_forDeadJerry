import SwiftUI

struct PsychedelicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                ZStack {
                    Color.theme.primaryGradient
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                    
                    // Add subtle shimmer effect
                    Color.white.opacity(0.1)
                        .blur(radius: 3)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .white.opacity(0.5), location: 0.45),
                                            .init(color: .white.opacity(0.5), location: 0.55),
                                            .init(color: .clear, location: 1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(70))
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: Color.theme.primaryAccent.opacity(configuration.isPressed ? 0.2 : 0.4),
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlowingButtonStyle: ButtonStyle {
    @State private var isAnimating = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                ZStack {
                    Color.theme.background
                    
                    // Inner glow
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.theme.primaryAccent.opacity(0.5),
                            Color.theme.primaryAccent.opacity(0.1),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
                    .blur(radius: configuration.isPressed ? 5 : 8)
                    
                    // Additional subtle effects
                    Color.theme.secondaryAccent.opacity(0.1)
                        .blur(radius: 5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.theme.primaryAccent,
                                Color.theme.secondaryAccent.opacity(0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(
                color: Color.theme.primaryAccent.opacity(0.5),
                radius: configuration.isPressed ? 10 : 15,
                x: 0,
                y: 0
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// A new iconic button style for smaller action buttons
struct IconicButtonStyle: ButtonStyle {
    var tint: Color = Color.theme.primaryAccent
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(
                Circle()
                    .fill(configuration.isPressed ? tint.opacity(0.15) : .clear)
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(configuration.isPressed ? 0.3 : 0.2), lineWidth: 1)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
            )
            .foregroundColor(tint)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func psychedelicButtonStyle() -> some View {
        self.buttonStyle(PsychedelicButtonStyle())
    }
    
    func glowingButtonStyle() -> some View {
        self.buttonStyle(GlowingButtonStyle())
    }
    
    func iconicButtonStyle(tint: Color = Color.theme.primaryAccent) -> some View {
        self.buttonStyle(IconicButtonStyle(tint: tint))
    }
} 