import SwiftUI

struct StylePlaygroundView: View {
    @State private var selectedSection: AppSection = .dead
    @State private var customColor = Color.purple
    @State private var opacity: Double = 0.7
    @State private var cornerRadius: Double = 16
    @State private var blurRadius: Double = 10
    @State private var waveSpeed: Double = 2.0
    @State private var lightIntensity: Double = 0.5
    @State private var selectedStyle: String = "Basic"
    @State private var showPreview = false
    @State private var showAdvancedPreview = false
    @State private var rotationSpeed: Double = 10.0
    @State private var fogIntensity: Double = 0.3
    @State private var laserCount: Double = 5
    
    let styleOptions = ["Basic", "Psychedelic", "Concert", "Vinyl", "Liquid", "Laser", "Combined", "Advanced"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    Text("Dead").tag(AppSection.dead)
                    Text("Jerry").tag(AppSection.jerry)
                    Text("All").tag(AppSection.all)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Style Picker
                Picker("Style", selection: $selectedStyle) {
                    ForEach(styleOptions, id: \.self) { style in
                        Text(style).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                
                // Color Picker
                ColorPicker("Custom Color", selection: $customColor)
                    .padding()
                
                // Basic Controls
                Group {
                    HStack {
                        Text("Opacity")
                        Slider(value: $opacity, in: 0...1)
                    }
                    
                    HStack {
                        Text("Corner Radius")
                        Slider(value: $cornerRadius, in: 0...30)
                    }
                    
                    HStack {
                        Text("Blur Radius")
                        Slider(value: $blurRadius, in: 0...20)
                    }
                }
                .padding()
                
                // Advanced Controls
                Group {
                    HStack {
                        Text("Wave Speed")
                        Slider(value: $waveSpeed, in: 0.5...5)
                    }
                    
                    HStack {
                        Text("Light Intensity")
                        Slider(value: $lightIntensity, in: 0...1)
                    }
                    
                    HStack {
                        Text("Rotation Speed")
                        Slider(value: $rotationSpeed, in: 5...20)
                    }
                    
                    HStack {
                        Text("Fog Intensity")
                        Slider(value: $fogIntensity, in: 0...1)
                    }
                    
                    HStack {
                        Text("Laser Count")
                        Slider(value: $laserCount, in: 1...8, step: 1)
                    }
                }
                .padding()
                
                // Style Examples
                Group {
                    // Basic Button
                    if selectedStyle == "Basic" {
                        Button("Basic Button") {}
                            .buttonStyle(AppButtonStyle(section: selectedSection))
                    }
                    
                    // Psychedelic Button
                    if selectedStyle == "Psychedelic" {
                        Button("Psychedelic Button") {}
                            .buttonStyle(PsychedelicWaveButtonStyle(color: customColor))
                    }
                    
                    // Concert Button
                    if selectedStyle == "Concert" {
                        Button("Concert Button") {}
                            .buttonStyle(ConcertLightButtonStyle(color: customColor))
                    }
                    
                    // Vinyl Button
                    if selectedStyle == "Vinyl" {
                        Button("Vinyl Button") {}
                            .padding()
                            .background(Color.black)
                            .vinylRecord(color: customColor)
                    }
                    
                    // Liquid Wave Button
                    if selectedStyle == "Liquid" {
                        Button("Liquid Wave") {}
                            .buttonStyle(LiquidWaveButtonStyle(color: customColor, speed: waveSpeed))
                    }
                    
                    // Laser Button
                    if selectedStyle == "Laser" {
                        Button("Laser Beam") {}
                            .buttonStyle(LaserBeamButtonStyle(color: customColor))
                    }
                    
                    // Combined Effects
                    if selectedStyle == "Combined" {
                        VStack(spacing: 15) {
                            Button("Combined Button") {}
                                .buttonStyle(PsychedelicWaveButtonStyle(color: customColor))
                                .concertLight(color: customColor.opacity(lightIntensity))
                            
                            Text("Combined Text")
                                .font(.title)
                                .foregroundColor(.white)
                                .psychedelicWave(color: customColor)
                                .concertLight(color: customColor.opacity(lightIntensity))
                        }
                    }
                    
                    // Advanced Combined
                    if selectedStyle == "Advanced" {
                        VStack(spacing: 15) {
                            Button("Advanced Button") {}
                                .buttonStyle(LiquidWaveButtonStyle(color: customColor, speed: waveSpeed))
                                .laserBeam(color: customColor)
                                .stageFog(color: customColor.opacity(fogIntensity))
                            
                            Text("Advanced Text")
                                .font(.title)
                                .foregroundColor(.white)
                                .liquidWave(color: customColor, speed: waveSpeed)
                                .laserBeam(color: customColor)
                                .stageFog(color: customColor.opacity(fogIntensity))
                        }
                    }
                    
                    // Custom Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Custom Card")
                            .font(.headline)
                        Text("This is a card with custom styling")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                customColor.opacity(opacity),
                                                customColor.opacity(opacity * 0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: customColor.opacity(opacity * 0.3), radius: blurRadius)
                }
                .padding(.horizontal)
                
                // Preview Toggles
                VStack {
                    Toggle("Show Basic Preview", isOn: $showPreview)
                    Toggle("Show Advanced Preview", isOn: $showAdvancedPreview)
                }
                .padding()
                
                if showPreview {
                    ThemedStylePreview()
                        .padding()
                }
                
                if showAdvancedPreview {
                    AdvancedStylePreview()
                        .padding()
                }
            }
        }
        .background(
            RadialGradient(
                gradient: AppTheme.mainGradient(for: selectedSection),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    StylePlaygroundView()
} 