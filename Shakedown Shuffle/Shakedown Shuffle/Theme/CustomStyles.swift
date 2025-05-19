import SwiftUI

// MARK: - Custom Style Modifiers

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius)
            .shadow(color: color, radius: radius)
    }
}

struct GlassEffectModifier: ViewModifier {
    let color: Color
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                color.opacity(opacity)
                    .blur(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),
                                .white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct AnimatedGradientModifier: ViewModifier {
    let colors: [Color]
    @State private var start = UnitPoint(x: 0, y: 0)
    @State private var end = UnitPoint(x: 1, y: 1)
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: start, endPoint: end)
                    .onAppear {
                        withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                            start = UnitPoint(x: 1, y: 0)
                            end = UnitPoint(x: 0, y: 1)
                        }
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    func neonGlow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }
    
    func glassEffect(color: Color, opacity: Double = 0.3) -> some View {
        modifier(GlassEffectModifier(color: color, opacity: opacity))
    }
    
    func animatedGradient(colors: [Color]) -> some View {
        modifier(AnimatedGradientModifier(colors: colors))
    }
}

// MARK: - Custom Button Styles

struct NeonButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color, lineWidth: 2)
                    )
            )
            .neonGlow(color: color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .glassEffect(color: color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview Helpers

struct StylePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            // Neon Button
            Button("Neon Button") {}
                .buttonStyle(NeonButtonStyle(color: .purple))
            
            // Glass Button
            Button("Glass Button") {}
                .buttonStyle(GlassButtonStyle(color: .blue))
            
            // Text with effects
            Text("Neon Text")
                .font(.title)
                .foregroundColor(.white)
                .neonGlow(color: .green)
            
            // Card with glass effect
            VStack {
                Text("Glass Card")
                    .font(.headline)
                Text("With glass effect")
                    .font(.subheadline)
            }
            .padding()
            .glassEffect(color: .blue)
            
            // Animated gradient
            Text("Animated Gradient")
                .padding()
                .animatedGradient(colors: [.purple, .blue, .green])
        }
        .padding()
        .background(Color.black)
    }
}

#Preview {
    StylePreview()
}

// MARK: - Additional Themed Style Modifiers

struct PsychedelicWaveModifier: ViewModifier {
    let color: Color
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let midHeight = height / 2
                        
                        path.move(to: CGPoint(x: 0, y: midHeight))
                        
                        for x in stride(from: 0, through: width, by: 1) {
                            let relativeX = x / 50
                            let sine = sin(relativeX + phase)
                            let y = midHeight + sine * 20
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(color.opacity(0.5), lineWidth: 2)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

struct ConcertLightModifier: ViewModifier {
    let color: Color
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .offset(x: isAnimating ? 50 : -50, y: isAnimating ? -30 : 30)
                            .blur(radius: 20)
                            .animation(
                                Animation.easeInOut(duration: 2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                    }
                }
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct VinylRecordModifier: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 200, height: 200)
                    
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                            .frame(width: CGFloat(160 - index * 20), height: CGFloat(160 - index * 20))
                    }
                }
            )
    }
}

// MARK: - Additional View Extensions

extension View {
    func psychedelicWave(color: Color) -> some View {
        modifier(PsychedelicWaveModifier(color: color))
    }
    
    func concertLight(color: Color) -> some View {
        modifier(ConcertLightModifier(color: color))
    }
    
    func vinylRecord(color: Color) -> some View {
        modifier(VinylRecordModifier(color: color))
    }
}

// MARK: - Additional Button Styles

struct PsychedelicWaveButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color, lineWidth: 2)
                    )
            )
            .psychedelicWave(color: color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ConcertLightButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.black)
            .concertLight(color: color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Additional Preview Examples

struct ThemedStylePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            // Psychedelic Wave Button
            Button("Psychedelic Wave") {}
                .buttonStyle(PsychedelicWaveButtonStyle(color: .purple))
            
            // Concert Light Button
            Button("Concert Light") {}
                .buttonStyle(ConcertLightButtonStyle(color: .orange))
            
            // Vinyl Record Effect
            Text("Vinyl Record")
                .font(.title)
                .foregroundColor(.white)
                .vinylRecord(color: .purple)
            
            // Combined Effects
            VStack {
                Text("Combined Effects")
                    .font(.headline)
                Text("Wave + Light")
                    .font(.subheadline)
            }
            .padding()
            .psychedelicWave(color: .blue)
            .concertLight(color: .purple)
        }
        .padding()
        .background(Color.black)
    }
}

#Preview {
    ThemedStylePreview()
}

// MARK: - Advanced Themed Style Modifiers

struct LiquidWaveModifier: ViewModifier {
    let color: Color
    let speed: Double
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let midHeight = height / 2
                        
                        path.move(to: CGPoint(x: 0, y: midHeight))
                        
                        for x in stride(from: 0, through: width, by: 1) {
                            let relativeX = x / 50
                            let sine = sin(relativeX + phase)
                            let cosine = cos(relativeX + phase)
                            let y = midHeight + sine * 20 + cosine * 10
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                }
            )
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

struct LaserBeamModifier: ViewModifier {
    let color: Color
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(color.opacity(0.3))
                            .frame(width: 2, height: 200)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .offset(x: isAnimating ? 50 : -50)
                            .blur(radius: 2)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct VinylSpinModifier: ViewModifier {
    let color: Color
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 200, height: 200)
                    
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                            .frame(width: CGFloat(160 - index * 20), height: CGFloat(160 - index * 20))
                    }
                    
                    // Vinyl grooves
                    ForEach(0..<20) { index in
                        Circle()
                            .stroke(color.opacity(0.1), lineWidth: 0.5)
                            .frame(width: CGFloat(180 - index * 8), height: CGFloat(180 - index * 8))
                    }
                }
                .rotationEffect(.degrees(rotation))
            )
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct StageFogModifier: ViewModifier {
    let color: Color
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .offset(y: isAnimating ? -20 : 20)
                            .blur(radius: 30)
                            .animation(
                                Animation.easeInOut(duration: 3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.5),
                                value: isAnimating
                            )
                    }
                }
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Additional View Extensions

extension View {
    func liquidWave(color: Color, speed: Double = 2.0) -> some View {
        modifier(LiquidWaveModifier(color: color, speed: speed))
    }
    
    func laserBeam(color: Color) -> some View {
        modifier(LaserBeamModifier(color: color))
    }
    
    func vinylSpin(color: Color) -> some View {
        modifier(VinylSpinModifier(color: color))
    }
    
    func stageFog(color: Color) -> some View {
        modifier(StageFogModifier(color: color))
    }
}

// MARK: - Advanced Button Styles

struct LiquidWaveButtonStyle: ButtonStyle {
    let color: Color
    let speed: Double
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color, lineWidth: 2)
                    )
            )
            .liquidWave(color: color, speed: speed)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct LaserBeamButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.black)
            .laserBeam(color: color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Advanced Preview Examples

struct AdvancedStylePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            // Liquid Wave Button
            Button("Liquid Wave") {}
                .buttonStyle(LiquidWaveButtonStyle(color: .purple, speed: 2.0))
            
            // Laser Beam Button
            Button("Laser Beam") {}
                .buttonStyle(LaserBeamButtonStyle(color: .red))
            
            // Vinyl Spin Effect
            Text("Vinyl Spin")
                .font(.title)
                .foregroundColor(.white)
                .vinylSpin(color: .purple)
            
            // Stage Fog Effect
            VStack {
                Text("Stage Fog")
                    .font(.headline)
                Text("With fog effect")
                    .font(.subheadline)
            }
            .padding()
            .stageFog(color: .blue)
            
            // Combined Advanced Effects
            VStack {
                Text("Combined Advanced")
                    .font(.headline)
                Text("Wave + Laser + Fog")
                    .font(.subheadline)
            }
            .padding()
            .liquidWave(color: .purple, speed: 1.5)
            .laserBeam(color: .red)
            .stageFog(color: .blue)
        }
        .padding()
        .background(Color.black)
    }
}

#Preview {
    AdvancedStylePreview()
}

// MARK: - Global Style System

struct AppStyle {
    static let shared = AppStyle()
    
    // Default colors
    let primaryColor: Color = .purple
    let secondaryColor: Color = .blue
    let accentColor: Color = .orange
    
    // Default speeds
    let waveSpeed: Double = 2.0
    let rotationSpeed: Double = 10.0
    
    // Default intensities
    let lightIntensity: Double = 0.5
    let fogIntensity: Double = 0.3
    
    // Style presets
    enum StylePreset {
        case basic
        case psychedelic
        case concert
        case vinyl
        case liquid
        case laser
        case combined
        case advanced
    }
}

// MARK: - Global View Extensions

extension View {
    func appStyle(_ preset: AppStyle.StylePreset, color: Color? = nil) -> some View {
        let styleColor = color ?? AppStyle.shared.primaryColor
        
        return Group {
            switch preset {
            case .basic:
                self.foregroundColor(styleColor)
            case .psychedelic:
                self.psychedelicWave(color: styleColor)
            case .concert:
                self.concertLight(color: styleColor.opacity(AppStyle.shared.lightIntensity))
            case .vinyl:
                self.vinylSpin(color: styleColor)
            case .liquid:
                self.liquidWave(color: styleColor, speed: AppStyle.shared.waveSpeed)
            case .laser:
                self.laserBeam(color: styleColor)
            case .combined:
                self
                    .psychedelicWave(color: styleColor)
                    .concertLight(color: styleColor.opacity(AppStyle.shared.lightIntensity))
            case .advanced:
                self
                    .liquidWave(color: styleColor, speed: AppStyle.shared.waveSpeed)
                    .laserBeam(color: styleColor)
                    .stageFog(color: styleColor.opacity(AppStyle.shared.fogIntensity))
            }
        }
    }
    
    func appButtonStyle(_ preset: AppStyle.StylePreset, color: Color? = nil) -> some View {
        let styleColor = color ?? AppStyle.shared.primaryColor
        
        return self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(styleColor, lineWidth: 2)
                    )
            )
            .appStyle(preset, color: styleColor)
    }
}

// MARK: - Usage Example

struct StyleExample: View {
    var body: some View {
        VStack(spacing: 20) {
            // Apply style to text
            Text("Psychedelic Text")
                .appStyle(.psychedelic)
            
            // Apply style to button
            Button("Psychedelic Button") {}
                .appButtonStyle(.psychedelic)
            
            // Apply style to card
            VStack {
                Text("Advanced Card")
                Text("With combined effects")
            }
            .padding()
            .appStyle(.advanced)
            
            // Apply custom color
            Text("Custom Color")
                .appStyle(.liquid, color: .red)
        }
    }
}

#Preview {
    StyleExample()
} 