//
//  TeacherAvatarView.swift
//  EL-Modras
//
//  Animated Arabic Teacher Avatar with Lip Sync
//

import SwiftUI
import Combine

// MARK: - Teacher Mood/State
enum TeacherMood: String, CaseIterable {
    case idle = "idle"
    case speaking = "speaking"
    case happy = "happy"
    case thinking = "thinking"
    case celebrating = "celebrating"
    case listening = "listening"
    case encouraging = "encouraging"
    case surprised = "surprised"
}

// MARK: - Mouth Shape for Lip Sync
enum MouthShape: String {
    case closed = "closed"      // م، ب، پ
    case slightOpen = "slight"  // ا، ت، د
    case open = "open"          // ا، ع، ح
    case wide = "wide"          // ي، س، ش
    case round = "round"        // و، ض، ظ
}

// MARK: - Eye State
enum EyeState {
    case normal
    case happy
    case surprised
    case looking(direction: CGFloat) // -1 to 1
}

// MARK: - Teacher Avatar View
struct TeacherAvatarView: View {
    @StateObject private var animator = TeacherAnimator()
    
    var mood: TeacherMood = .idle
    var isSpeaking: Bool = false
    var message: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Avatar Character
            ZStack {
                // Background Circle with mood-based color
                Circle()
                    .fill(
                        RadialGradient(
                            colors: backgroundColors,
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(animator.breathingScale)
                
                // Listening Waves (when listening)
                if mood == .listening {
                    ListeningWaves()
                }
                
                // Thinking Dots (when thinking)
                if mood == .thinking {
                    ThinkingDotsView()
                        .offset(y: -140)
                }
                
                // Celebration Effects (when celebrating)
                if mood == .celebrating {
                    CelebrationConfetti()
                }
                
                // Drawn Avatar with head nodding
                DrawnTeacherFace(
                    mood: mood,
                    mouthShape: animator.currentMouthShape,
                    isBlinking: animator.isBlinking
                )
                .frame(width: 200, height: 220)
                .scaleEffect(animator.characterScale)
                .rotationEffect(.degrees(animator.headNodAngle))
                .offset(y: animator.headBobOffset)
            }
            
            // Speech Bubble
            if !message.isEmpty {
                SpeechBubble(text: message, mood: mood)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, -20)
            }
        }
        .onChange(of: isSpeaking) { _, newValue in
            if newValue {
                animator.startSpeaking()
            } else {
                animator.stopSpeaking()
            }
        }
        .onChange(of: mood) { _, newMood in
            animator.setMood(newMood)
        }
        .onAppear {
            animator.startIdleAnimations()
        }
    }
    
    // Background colors based on mood
    private var backgroundColors: [Color] {
        switch mood {
        case .celebrating:
            return [Color.yellow.opacity(0.4), Color.orange.opacity(0.3)]
        case .happy:
            return [Color.green.opacity(0.3), Color.mint.opacity(0.2)]
        case .thinking:
            return [Color.purple.opacity(0.3), Color.indigo.opacity(0.2)]
        case .listening:
            return [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)]
        case .encouraging:
            return [Color.pink.opacity(0.3), Color.orange.opacity(0.2)]
        default:
            return [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
        }
    }
}

// MARK: - Listening Waves Animation
struct ListeningWaves: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.cyan.opacity(0.4 - Double(index) * 0.1), lineWidth: 3)
                    .frame(width: 200 + CGFloat(index) * 40, height: 200 + CGFloat(index) * 40)
                    .scaleEffect(animate ? 1.2 : 0.9)
                    .opacity(animate ? 0.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Thinking Dots Animation
struct ThinkingDotsView: View {
    @State private var animatingDot = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12, height: 12)
                    .offset(y: animatingDot == index ? -10 : 0)
                    .animation(
                        .easeInOut(duration: 0.4),
                        value: animatingDot
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
        )
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            animatingDot = (animatingDot + 1) % 3
        }
    }
}

// MARK: - Celebration Confetti
struct CelebrationConfetti: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ConfettiPiece(particle: particle)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<30).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: -150...150),
                y: CGFloat.random(in: -200...(-50)),
                rotation: Double.random(in: 0...360),
                color: [Color.red, .yellow, .green, .blue, .purple, .orange, .pink].randomElement()!,
                size: CGFloat.random(in: 8...16)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var color: Color
    var size: CGFloat
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var falling = false
    @State private var rotating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.6)
            .rotationEffect(.degrees(rotating ? particle.rotation + 360 : particle.rotation))
            .offset(x: particle.x, y: falling ? 200 : particle.y)
            .opacity(falling ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: Double.random(in: 1.5...2.5))) {
                    falling = true
                }
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}

// MARK: - Image Based Avatar (uses PNG with animated mouth overlay)
struct ImageBasedAvatar: View {
    let isSpeaking: Bool
    let mouthShape: MouthShape
    let mood: TeacherMood
    
    var body: some View {
        ZStack {
            // Teacher face image
            Image("TeacherFace")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 200)
            
            // Animated mouth overlay
            // Adjust offset to match your image's mouth position
            AnimatedMouth(shape: mouthShape, mood: mood)
                .offset(y: 45)
        }
        .frame(width: 200, height: 220)
    }
}

// MARK: - Drawn Teacher Face (Simplified, cleaner version)
struct DrawnTeacherFace: View {
    let mood: TeacherMood
    let mouthShape: MouthShape
    let isBlinking: Bool
    
    var body: some View {
        ZStack {
            // Hair (full head - behind everything)
            Circle()
                .fill(Color(red: 0.2, green: 0.14, blue: 0.1))
                .frame(width: 170, height: 170)
                .offset(y: -40)
            
            // Face
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.91, blue: 0.82),
                            Color(red: 0.94, green: 0.86, blue: 0.76)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 150, height: 170)
                .offset(y: 15)
            
            // Ears
            HStack(spacing: 145) {
                EarView()
                EarView()
            }
            .offset(y: 10)
            
            // Eyebrows - animated based on mood
            HStack(spacing: 45) {
                EyebrowView(isLeft: true, mood: mood)
                EyebrowView(isLeft: false, mood: mood)
            }
            .offset(y: -15)
            
            // Eyes
            HStack(spacing: 38) {
                EyeView2(isBlinking: isBlinking, mood: mood)
                EyeView2(isBlinking: isBlinking, mood: mood)
            }
            .offset(y: 10)
            
            // Glasses
            GlassesView2()
                .offset(y: 10)
            
            // Nose
            NoseView()
                .offset(y: 40)
            
            // Mouth
            AnimatedMouth(shape: mouthShape, mood: mood)
                .offset(y: 70)
        }
    }
}

// MARK: - Hair View
struct HairView: View {
    var body: some View {
        EmptyView() // Not used anymore - hair is part of DrawnTeacherFace
    }
}

// MARK: - Ear View
struct EarView: View {
    var body: some View {
        Ellipse()
            .fill(Color(red: 0.95, green: 0.85, blue: 0.75))
            .frame(width: 22, height: 32)
    }
}

// MARK: - Eyebrow View
struct EyebrowView: View {
    let isLeft: Bool
    var mood: TeacherMood = .idle
    
    private var rotation: Double {
        switch mood {
        case .surprised:
            return isLeft ? -10 : 10  // Raised
        case .thinking:
            return isLeft ? 15 : -5   // One raised
        case .happy, .celebrating:
            return isLeft ? -5 : 5    // Relaxed up
        case .encouraging:
            return isLeft ? 8 : -8    // Slight raise
        default:
            return isLeft ? 5 : -5    // Neutral
        }
    }
    
    private var offsetY: CGFloat {
        switch mood {
        case .surprised:
            return -5
        case .thinking:
            return isLeft ? -3 : 0
        default:
            return 0
        }
    }
    
    var body: some View {
        Capsule()
            .fill(Color(red: 0.25, green: 0.18, blue: 0.12))
            .frame(width: 25, height: 5)
            .rotationEffect(.degrees(rotation))
            .offset(y: offsetY)
            .animation(.easeInOut(duration: 0.2), value: mood)
    }
}

// MARK: - Nose View
struct NoseView: View {
    var body: some View {
        Ellipse()
            .fill(Color(red: 0.92, green: 0.82, blue: 0.72))
            .frame(width: 16, height: 12)
    }
}

// MARK: - Cheek View
struct CheekView: View {
    var body: some View {
        Circle()
            .fill(Color.pink.opacity(0.35))
            .frame(width: 28, height: 28)
            .blur(radius: 6)
    }
}

// MARK: - Eye View
struct EyeView2: View {
    let isBlinking: Bool
    var mood: TeacherMood = .idle
    
    private var eyeHeight: CGFloat {
        switch mood {
        case .happy, .celebrating:
            return isBlinking ? 3 : 20  // Squinted happy eyes
        case .surprised:
            return isBlinking ? 3 : 32  // Wide eyes
        default:
            return isBlinking ? 3 : 28  // Normal
        }
    }
    
    var body: some View {
        ZStack {
            // White
            Ellipse()
                .fill(.white)
                .frame(width: 32, height: eyeHeight)
                .animation(.easeInOut(duration: 0.1), value: isBlinking)
                .animation(.easeInOut(duration: 0.2), value: mood)
            
            if !isBlinking {
                // Iris
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brown, Color(red: 0.3, green: 0.2, blue: 0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 18, height: 18)
                
                // Pupil
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                
                // Shine
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

// MARK: - Glasses View
struct GlassesView2: View {
    var body: some View {
        ZStack {
            // Left lens - wider
            Circle()
                .stroke(Color(red: 0.15, green: 0.1, blue: 0.05), lineWidth: 3)
                .frame(width: 48, height: 48)
                .offset(x: -30)
            
            // Right lens - wider
            Circle()
                .stroke(Color(red: 0.15, green: 0.1, blue: 0.05), lineWidth: 3)
                .frame(width: 48, height: 48)
                .offset(x: 30)
            
            // Bridge (connects lenses)
            Rectangle()
                .fill(Color(red: 0.15, green: 0.1, blue: 0.05))
                .frame(width: 12, height: 3)
            
            // Left arm
            Rectangle()
                .fill(Color(red: 0.15, green: 0.1, blue: 0.05))
                .frame(width: 25, height: 3)
                .offset(x: -65)
            
            // Right arm
            Rectangle()
                .fill(Color(red: 0.15, green: 0.1, blue: 0.05))
                .frame(width: 25, height: 3)
                .offset(x: 65)
        }
    }
}

// MARK: - Animated Mouth
struct AnimatedMouth: View {
    let shape: MouthShape
    let mood: TeacherMood
    
    var body: some View {
        // When mouth shape is not closed, show speaking mouth
        // When closed, show smile
        if shape != .closed {
            // Speaking - show animated mouth
            SpeakingMouth2(shape: shape)
        } else {
            // Not speaking - show smile
            SmileMouthView()
        }
    }
}

struct SmileMouthView: View {
    var body: some View {
        ZStack {
            // Happy smile - curved up with bigger smile
            Capsule()
                .fill(Color(red: 0.75, green: 0.25, blue: 0.25))
                .frame(width: 40, height: 18)
            
            // Teeth showing
            RoundedRectangle(cornerRadius: 3)
                .fill(.white)
                .frame(width: 30, height: 8)
                .offset(y: -3)
        }
    }
}

struct SpeakingMouth2: View {
    let shape: MouthShape
    
    var mouthHeight: CGFloat {
        switch shape {
        case .closed: return 4
        case .slightOpen: return 12
        case .open: return 20
        case .wide: return 16
        case .round: return 18
        }
    }
    
    var mouthWidth: CGFloat {
        switch shape {
        case .closed: return 30
        case .slightOpen: return 32
        case .open: return 36
        case .wide: return 42
        case .round: return 24
        }
    }
    
    var body: some View {
        ZStack {
            if shape == .closed {
                // Closed - simple line
                Capsule()
                    .fill(Color(red: 0.6, green: 0.35, blue: 0.3))
                    .frame(width: mouthWidth, height: mouthHeight)
            } else {
                // Open mouth
                RoundedRectangle(cornerRadius: mouthHeight / 2)
                    .fill(Color(red: 0.15, green: 0.05, blue: 0.05))
                    .frame(width: mouthWidth, height: mouthHeight)
                
                // Teeth
                if mouthHeight > 10 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: mouthWidth * 0.7, height: 6)
                        .offset(y: -mouthHeight/2 + 4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.08), value: shape)
    }
}

struct ThinkingMouth: View {
    var body: some View {
        Ellipse()
            .fill(Color(red: 0.85, green: 0.5, blue: 0.5))
            .frame(width: 15, height: 12)
            .offset(x: 5)
    }
}

struct CelebrationStars: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<5) { index in
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
                    .offset(
                        x: CGFloat.random(in: -80...80),
                        y: CGFloat.random(in: -120...(-60))
                    )
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .opacity(animate ? 1 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Speech Bubble
struct SpeechBubble: View {
    let text: String
    var mood: TeacherMood = .idle
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble pointer
            Triangle()
                .fill(bubbleColor)
                .frame(width: 20, height: 12)
                .rotationEffect(.degrees(180))
            
            // Bubble content
            HStack(spacing: 8) {
                // Mood emoji
                if let emoji = moodEmoji {
                    Text(emoji)
                        .font(.title2)
                }
                
                Text(text)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .frame(maxWidth: 320)
    }
    
    private var bubbleColor: Color {
        switch mood {
        case .celebrating:
            return Color.yellow.opacity(0.95)
        case .encouraging:
            return Color.green.opacity(0.15).opacity(0.95)
        default:
            return .white
        }
    }
    
    private var moodEmoji: String? {
        switch mood {
        case .celebrating:
            return "🎉"
        case .encouraging:
            return "💪"
        case .thinking:
            return "🤔"
        case .listening:
            return "👂"
        default:
            return nil
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Teacher Animator
@MainActor
class TeacherAnimator: ObservableObject {
    @Published var currentMouthShape: MouthShape = .closed
    @Published var eyeState: EyeState = .normal
    @Published var isBlinking: Bool = false
    @Published var breathingScale: CGFloat = 1.0
    @Published var characterScale: CGFloat = 1.0
    @Published var headNodAngle: Double = 0.0
    @Published var headBobOffset: CGFloat = 0.0
    
    private var blinkingTask: Task<Void, Never>?
    private var breathingTask: Task<Void, Never>?
    private var speakingTask: Task<Void, Never>?
    private var noddingTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    
    func startIdleAnimations() {
        startBlinking()
        startBreathing()
    }
    
    func startSpeaking() {
        speakingTask?.cancel()
        noddingTask?.cancel()
        
        // IMMEDIATELY start with open mouth - no delay
        currentMouthShape = .open
        
        // Start head bob while speaking
        startHeadBobWhileSpeaking()
        
        // Natural mouth animation like human speech
        speakingTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Different mouth shapes for natural look
            let shapes: [MouthShape] = [.open, .slightOpen, .open, .wide, .slightOpen, .open, .slightOpen]
            var index = 0
            
            while !Task.isCancelled {
                // Cycle through natural mouth shapes
                self.currentMouthShape = shapes[index % shapes.count]
                index += 1
                
                // 120ms = natural speaking rhythm
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }
    
    private func startHeadBobWhileSpeaking() {
        noddingTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Small head movements while speaking
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headBobOffset = -3
                    self.headNodAngle = Double.random(in: -2...2)
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headBobOffset = 0
                    self.headNodAngle = Double.random(in: -2...2)
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
    
    func stopSpeaking() {
        speakingTask?.cancel()
        speakingTask = nil
        noddingTask?.cancel()
        noddingTask = nil
        
        // Reset head position
        withAnimation(.easeOut(duration: 0.2)) {
            headBobOffset = 0
            headNodAngle = 0
        }
        
        // Close mouth when done speaking
        currentMouthShape = .closed
    }
    
    func startListening() {
        listeningTask?.cancel()
        
        // Head nodding while listening (like "I understand")
        listeningTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Nod down
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.headNodAngle = 5
                    self.headBobOffset = 5
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
                
                // Nod up
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.headNodAngle = -2
                    self.headBobOffset = 0
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
                
                // Pause between nods
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }
    
    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        
        withAnimation(.easeOut(duration: 0.2)) {
            headNodAngle = 0
            headBobOffset = 0
        }
    }
    
    func setMood(_ mood: TeacherMood) {
        // Stop previous mood animations
        listeningTask?.cancel()
        noddingTask?.cancel()
        
        switch mood {
        case .happy:
            eyeState = .happy
            characterScale = 1.05
            // Happy bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                headBobOffset = -10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.headBobOffset = 0
                }
            }
            
        case .celebrating:
            eyeState = .happy
            characterScale = 1.1
            // Excited bouncing
            startCelebrationBounce()
            
        case .surprised:
            eyeState = .surprised
            characterScale = 1.1
            // Quick head back
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                headNodAngle = -5
                headBobOffset = -8
            }
            
        case .thinking:
            eyeState = .looking(direction: 0.5)
            characterScale = 1.0
            // Look up and to the side
            withAnimation(.easeInOut(duration: 0.5)) {
                headNodAngle = -8
            }
            
        case .listening:
            eyeState = .normal
            characterScale = 1.0
            startListening()
            
        case .encouraging:
            eyeState = .happy
            characterScale = 1.03
            // Gentle encouraging nod
            withAnimation(.easeInOut(duration: 0.4)) {
                headNodAngle = 5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.headNodAngle = 0
                }
            }
            
        default:
            eyeState = .normal
            characterScale = 1.0
            withAnimation(.easeOut(duration: 0.3)) {
                headNodAngle = 0
                headBobOffset = 0
            }
        }
    }
    
    private func startCelebrationBounce() {
        noddingTask = Task { [weak self] in
            guard let self = self else { return }
            
            for _ in 0..<5 {
                if Task.isCancelled { break }
                
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    self.headBobOffset = -15
                    self.headNodAngle = Double.random(in: -5...5)
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
                
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    self.headBobOffset = 0
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            
            // Reset
            withAnimation(.easeOut(duration: 0.3)) {
                self.headNodAngle = 0
            }
        }
    }
    
    private func startBlinking() {
        blinkingTask?.cancel()
        blinkingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_500_000_000...4_500_000_000))
                if Task.isCancelled { break }
                
                // Blink
                self.isBlinking = true
                try? await Task.sleep(nanoseconds: 120_000_000)
                self.isBlinking = false
            }
        }
    }
    
    private func startBreathing() {
        breathingTask?.cancel()
        breathingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 2.5)) {
                    self.breathingScale = 1.02
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                
                withAnimation(.easeInOut(duration: 2.5)) {
                    self.breathingScale = 1.0
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }
    
    deinit {
        blinkingTask?.cancel()
        breathingTask?.cancel()
        speakingTask?.cancel()
        noddingTask?.cancel()
        listeningTask?.cancel()
    }
}

// MARK: - Notification for Audio Level
extension Notification.Name {
    static let audioLevelChanged = Notification.Name("audioLevelChanged")
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        TeacherAvatarView(
            mood: .speaking,
            isSpeaking: true,
            message: "مرحباً! أهلاً وسهلاً"
        )
        
        HStack(spacing: 20) {
            ForEach(TeacherMood.allCases, id: \.rawValue) { mood in
                Text(mood.rawValue)
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
