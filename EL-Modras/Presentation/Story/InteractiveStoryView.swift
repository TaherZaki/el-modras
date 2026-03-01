//
//  InteractiveStoryView.swift
//  EL-Modras
//
//  Interactive Story View for Kids
//

import SwiftUI

struct InteractiveStoryView: View {
    @StateObject var viewModel: StoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main Story Content
                if viewModel.isStoryComplete {
                    storyCompleteView
                } else {
                    storyContentView
                }
            }
            .padding(.top, 20)
            
            // Confetti for celebrations
            if viewModel.avatarMood == .celebrating {
                StoryConfettiView()
            }
        }
        .task {
            await viewModel.startStory()
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            // Gradient background based on scene
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating emojis
            ForEach(0..<5, id: \.self) { i in
                Text(viewModel.currentScene.backgroundEmoji)
                    .font(.system(size: 40))
                    .opacity(0.2)
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: CGFloat.random(in: -300...300)
                    )
            }
        }
    }
    
    private var backgroundColors: [Color] {
        switch viewModel.currentScene.backgroundEmoji {
        case "🏠", "🏡":
            return [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)]
        case "🏪":
            return [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]
        case "🌳":
            return [Color.green.opacity(0.3), Color.mint.opacity(0.3)]
        case "🌟":
            return [Color.yellow.opacity(0.4), Color.orange.opacity(0.3)]
        case "🌙":
            return [Color.indigo.opacity(0.3), Color.purple.opacity(0.3)]
        default:
            return [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)]
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            
            Spacer()
            
            // Progress
            VStack(spacing: 4) {
                Text(viewModel.story.titleArabic)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(Color.yellow)
                            .frame(width: geo.size.width * viewModel.progress, height: 8)
                    }
                }
                .frame(height: 8)
                .frame(maxWidth: 150)
            }
            
            Spacer()
            
            // Stars earned
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.starsEarned)")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding()
    }
    
    // MARK: - Story Content
    private var storyContentView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Scene character
            characterView
            
            // Narrator text bubble
            narratorBubble
            
            // Word to learn (if any)
            if let word = viewModel.currentScene.wordToLearn {
                wordCard(word: word)
            }
            
            // Choices (if any)
            if viewModel.showChoices, let choices = viewModel.currentScene.choices {
                choicesView(choices: choices)
            }
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding()
    }
    
    // MARK: - Character View
    private var characterView: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.5), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
            
            // Character emoji
            Text(viewModel.currentScene.characterEmoji)
                .font(.system(size: 100))
                .scaleEffect(viewModel.isPlaying ? 1.1 : 1.0)
                .animation(
                    viewModel.isPlaying ?
                        .easeInOut(duration: 0.3).repeatForever(autoreverses: true) :
                        .default,
                    value: viewModel.isPlaying
                )
        }
    }
    
    // MARK: - Narrator Bubble
    private var narratorBubble: some View {
        VStack(spacing: 8) {
            // Arabic text
            Text(viewModel.currentScene.narratorTextArabic)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.85))
                .multilineTextAlignment(.center)
            
            // Processing indicator
            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.orange)
                    Text("بفكر...")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Word Card
    private func wordCard(word: Word) -> some View {
        VStack(spacing: 12) {
            // Emoji
            if let emoji = word.emoji {
                Text(emoji)
                    .font(.system(size: 60))
            }
            
            // Arabic word
            Text(word.arabic)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.blue)
            
            // Transliteration
            Text(word.transliteration)
                .font(.title3)
                .foregroundStyle(.gray)
            
            // Score indicator (if available)
            if let score = viewModel.pronunciationScore {
                HStack {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: Double(i) < score.score * 3 ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .font(.title2)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .blue.opacity(0.2), radius: 10)
        )
    }
    
    // MARK: - Choices View
    private func choicesView(choices: [StoryChoice]) -> some View {
        VStack(spacing: 12) {
            Text("اختار!")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: 16) {
                ForEach(choices) { choice in
                    choiceButton(choice: choice)
                }
            }
        }
    }
    
    private func choiceButton(choice: StoryChoice) -> some View {
        Button {
            Task {
                await viewModel.selectChoice(choice)
            }
        } label: {
            VStack(spacing: 8) {
                Text(choice.emoji)
                    .font(.system(size: 40))
                
                Text(choice.textArabic)
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.85))
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Replay button
            Button {
                Task {
                    await viewModel.replayScene()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                    Text("تاني")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Circle().fill(Color.blue))
                .shadow(radius: 5)
            }
            .disabled(viewModel.isPlaying || viewModel.isRecording)
            .opacity(viewModel.isPlaying || viewModel.isRecording ? 0.5 : 1)
            
            // Record button (if pronunciation required)
            if viewModel.currentScene.requiresPronunciation && !viewModel.showChoices {
                Button {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecordingAndCheck()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? Color.red : Color.orange)
                                .frame(width: 80, height: 80)
                            
                            if viewModel.isRecording {
                                // Recording indicator
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                                    .opacity(viewModel.isRecording ? 0 : 1)
                                    .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: viewModel.isRecording)
                                
                                Image(systemName: "stop.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Text(viewModel.isRecording ? "خلاص" : "كرر 🎤")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .disabled(viewModel.isPlaying || viewModel.isProcessing)
                .shadow(radius: 5)
            }
            
            // Skip button
            Button {
                viewModel.skipScene()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                    Text("التالي")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Circle().fill(Color.green))
                .shadow(radius: 5)
            }
            .disabled(viewModel.isPlaying || viewModel.isRecording || viewModel.showChoices)
            .opacity(viewModel.isPlaying || viewModel.isRecording || viewModel.showChoices ? 0.5 : 1)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Story Complete View
    private var storyCompleteView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Celebration
            Text("🎉")
                .font(.system(size: 80))
            
            Text("برافو!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("خلصت القصة!")
                .font(.title)
                .foregroundStyle(.white.opacity(0.9))
            
            // Stats
            VStack(spacing: 16) {
                HStack(spacing: 30) {
                    statItem(icon: "star.fill", value: "\(viewModel.starsEarned)", label: "نجوم", color: .yellow)
                    statItem(icon: "book.fill", value: "\(viewModel.wordsLearned.count)", label: "كلمات", color: .blue)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.2))
            )
            
            // Words learned
            if !viewModel.wordsLearned.isEmpty {
                VStack(spacing: 12) {
                    Text("الكلمات اللي اتعلمتها:")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.wordsLearned, id: \.id) { word in
                                VStack(spacing: 4) {
                                    Text(word.emoji ?? "📝")
                                        .font(.title)
                                    Text(word.arabic)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.black.opacity(0.85))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            // Done button
            Button {
                dismiss()
            } label: {
                Text("رجوع للرئيسية")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Confetti View
struct StoryConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { i in
                StoryConfettiPiece(
                    color: [.red, .blue, .green, .yellow, .purple, .orange, .pink].randomElement()!,
                    delay: Double(i) * 0.05
                )
            }
        }
    }
}

struct StoryConfettiPiece: View {
    let color: Color
    let delay: Double
    
    @State private var animate = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .offset(
                x: animate ? CGFloat.random(in: -200...200) : 0,
                y: animate ? CGFloat.random(in: 300...500) : -100
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 2).delay(delay)) {
                    animate = true
                }
            }
    }
}

// MARK: - Preview
#Preview {
    InteractiveStoryView(
        viewModel: StoryViewModel(
            story: Story.mimiTheCat,
            audioService: AudioServiceImpl(),
            geminiService: GeminiServiceImpl()
        )
    )
}
