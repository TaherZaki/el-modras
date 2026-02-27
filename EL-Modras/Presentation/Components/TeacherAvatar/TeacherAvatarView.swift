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
                // Background Circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(animator.breathingScale)
                
                // Drawn Avatar
                DrawnTeacherFace(
                    mood: mood,
                    mouthShape: animator.currentMouthShape,
                    isBlinking: animator.isBlinking
                )
                .frame(width: 200, height: 220)
                .scaleEffect(animator.characterScale)
            }
            
            // Speech Bubble
            if !message.isEmpty && isSpeaking {
                SpeechBubble(text: message)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, -20)
            }
        }
        .onChange(of: isSpeaking) { _, newValue in
            // Immediately update mouth state - no delay
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
            
            // Eyebrows
            HStack(spacing: 45) {
                EyebrowView(isLeft: true)
                EyebrowView(isLeft: false)
            }
            .offset(y: -15)
            
            // Eyes
            HStack(spacing: 38) {
                EyeView2(isBlinking: isBlinking)
                EyeView2(isBlinking: isBlinking)
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
    
    var body: some View {
        Capsule()
            .fill(Color(red: 0.25, green: 0.18, blue: 0.12))
            .frame(width: 25, height: 5)
            // Neutral/friendly angle - not too tilted
            .rotationEffect(.degrees(isLeft ? 5 : -5))
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
    
    var body: some View {
        ZStack {
            // White
            Ellipse()
                .fill(.white)
                .frame(width: 32, height: isBlinking ? 3 : 28)
                .animation(.easeInOut(duration: 0.1), value: isBlinking)
            
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble pointer
            Triangle()
                .fill(Color.white)
                .frame(width: 20, height: 12)
                .rotationEffect(.degrees(180))
            
            // Bubble content
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .frame(maxWidth: 300)
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
    
    private var blinkingTask: Task<Void, Never>?
    private var breathingTask: Task<Void, Never>?
    private var speakingTask: Task<Void, Never>?
    
    func startIdleAnimations() {
        startBlinking()
        startBreathing()
    }
    
    func startSpeaking() {
        speakingTask?.cancel()
        
        // IMMEDIATELY start with open mouth - no delay
        currentMouthShape = .open
        
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
    
    func stopSpeaking() {
        speakingTask?.cancel()
        speakingTask = nil
        // Close mouth when done speaking
        currentMouthShape = .closed
    }
    
    func setMood(_ mood: TeacherMood) {
        switch mood {
        case .happy, .celebrating:
            eyeState = .happy
            characterScale = 1.05
        case .surprised:
            eyeState = .surprised
            characterScale = 1.1
        case .thinking:
            eyeState = .looking(direction: 0.5)
            characterScale = 1.0
        default:
            eyeState = .normal
            characterScale = 1.0
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
