//
//  SplashScreenView.swift
//  EL-Modras
//
//  Animated Arabic letters splash screen for kids
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var lettersVisible: [Bool] = Array(repeating: false, count: 10)
    @State private var showAppName = false
    @State private var showSubtitle = false
    @State private var backgroundHue: Double = 0.55
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = 0
    
    // Arabic letters to animate (common Arabic letters)
    private let arabicLetters = ["أ", "ب", "ت", "ج", "د", "س", "ع", "ف", "م", "ن"]
    
    // Fun colors for each letter
    private let letterColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan,
        .blue, .purple, .pink, .mint, .indigo
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground
            
            // Floating bubbles
            FloatingBubbles()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Animated Arabic letters in a circle
                ZStack {
                    // Glowing background circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 50,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // Arabic letters arranged in a circle
                    ForEach(0..<arabicLetters.count, id: \.self) { index in
                        AnimatedArabicLetter(
                            letter: arabicLetters[index],
                            color: letterColors[index],
                            isVisible: lettersVisible[index],
                            index: index,
                            total: arabicLetters.count
                        )
                        .offset(letterOffset(for: index))
                    }
                    
                    // Center logo with book emoji
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                        
                        Text("📖")
                            .font(.system(size: 70))
                            .scaleEffect(logoScale)
                            .rotationEffect(.degrees(logoRotation))
                    }
                }
                .frame(width: 320, height: 320)
                
                // App name
                if showAppName {
                    VStack(spacing: 12) {
                        // Arabic name with animation
                        HStack(spacing: 4) {
                            ForEach(Array("المُدَرِّس".enumerated()), id: \.offset) { index, char in
                                Text(String(char))
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                                    .offset(y: isAnimating ? -5 : 5)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.1),
                                        value: isAnimating
                                    )
                            }
                        }
                        
                        Text("EL-Modras")
                            .font(.title2.bold())
                            .foregroundStyle(.white.opacity(0.9))
                            .tracking(3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Subtitle and loading
                if showSubtitle {
                    VStack(spacing: 16) {
                        // Fun tagline
                        Text("🌟 Learn Arabic the Fun Way! 🌟")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        // Loading dots
                        LoadingDots()
                        
                        Text("Getting your lessons ready...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animated Background
    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(hue: backgroundHue, saturation: 0.7, brightness: 0.9),
                Color(hue: backgroundHue + 0.15, saturation: 0.6, brightness: 0.7),
                Color(hue: backgroundHue + 0.3, saturation: 0.7, brightness: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                backgroundHue = 0.85
            }
        }
    }
    
    // MARK: - Letter Offset
    private func letterOffset(for index: Int) -> CGSize {
        let angle = (Double(index) / Double(arabicLetters.count)) * 2 * .pi - .pi / 2
        let radius: Double = 120
        return CGSize(
            width: Foundation.cos(angle) * radius,
            height: Foundation.sin(angle) * radius
        )
    }
    
    // MARK: - Start Animations
    private func startAnimations() {
        isAnimating = true
        
        // Animate logo appearing
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
        }
        
        // Logo subtle rotation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            logoRotation = 10
        }
        
        // Animate letters appearing one by one
        for index in 0..<arabicLetters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    lettersVisible[index] = true
                }
            }
        }
        
        // Show app name after letters
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showAppName = true
            }
        }
        
        // Show subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                showSubtitle = true
            }
        }
    }
}

// MARK: - Animated Arabic Letter
struct AnimatedArabicLetter: View {
    let letter: String
    let color: Color
    let isVisible: Bool
    let index: Int
    let total: Int
    
    @State private var bounce = false
    @State private var glow = false
    
    var body: some View {
        ZStack {
            // Glow effect
            Text(letter)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
                .blur(radius: glow ? 8 : 4)
                .opacity(glow ? 0.8 : 0.4)
            
            // Main letter
            Text(letter)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 3, y: 2)
        }
        .scaleEffect(isVisible ? (bounce ? 1.3 : 1.0) : 0.1)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            if isVisible {
                // Bounce animation with different delays
                withAnimation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1)
                ) {
                    bounce = true
                }
                
                // Glow animation
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
                ) {
                    glow = true
                }
            }
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                withAnimation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1)
                ) {
                    bounce = true
                }
                
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
                ) {
                    glow = true
                }
            }
        }
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    @State private var dotScales: [CGFloat] = [1.0, 1.0, 1.0]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .scaleEffect(dotScales[index])
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    dotScales[index] = 1.5
                }
            }
        }
    }
}

// MARK: - Floating Bubbles
struct FloatingBubbles: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: CGFloat.random(in: 20...60))
                        .offset(
                            x: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                            y: animate ? -geometry.size.height/2 - 100 : geometry.size.height/2 + 100
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 4...8))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                            value: animate
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Preview
#Preview {
    SplashScreenView()
}
