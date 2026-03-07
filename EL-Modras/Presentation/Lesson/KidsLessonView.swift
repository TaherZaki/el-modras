//
//  KidsLessonView.swift
//  EL-Modras
//
//  A fun, kid-friendly lesson interface with animated teacher avatar
//

import SwiftUI
import Combine

struct KidsLessonView: View {
    @StateObject private var viewModel: LessonViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var teacherMood: TeacherMood = .idle
    @State private var isSpeaking: Bool = false
    @State private var currentMessage: String = ""
    @State private var showCelebration: Bool = false
    @State private var selectedWordIndex: Int = 0
    @State private var isAskingQuestion: Bool = false
    @State private var recordingPulse: Bool = false
    
    init(viewModel: LessonViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Fun gradient background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Teacher Avatar - The Star of the Show!
                        avatarSection
                        
                        // Current Word to Learn
                        if let word = viewModel.currentWord {
                            wordCard(word: word)
                        }
                        
                        // Word Selection (horizontal scroll)
                        wordSelector
                        
                        // Pronunciation Score (if available)
                        if let score = viewModel.pronunciationScore {
                            scoreView(score: score)
                        }
                    }
                    .padding()
                }
                
                // Bottom action area
                bottomActionArea
            }
            
            // Celebration overlay
            if showCelebration {
                CelebrationOverlay()
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCelebration = false
                            }
                        }
                    }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startLesson()
        }
        .onChange(of: viewModel.isPlaying) { _, newValue in
            // Only use this for non-speaking states (when isPlaying becomes false)
            if !newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSpeaking = false
                    teacherMood = .idle
                }
            }
        }
        // Listen to actual audio playback for lip-sync (triggers when audio REALLY plays)
        .onReceive(viewModel.audioService.speakingProgressPublisher.receive(on: DispatchQueue.main)) { progress in
            withAnimation(.easeInOut(duration: 0.15)) {
                isSpeaking = progress.isSpeaking
                if progress.isSpeaking {
                    teacherMood = .speaking
                }
            }
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            withAnimation(.easeInOut(duration: 0.2)) {
                if isProcessing {
                    teacherMood = .thinking
                    currentMessage = "خليني أسمع كويس..."
                }
            }
        }
        .onChange(of: viewModel.pronunciationScore) { _, score in
            if let score = score {
                handleScore(score)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .speechFinished)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSpeaking = false
                teacherMood = .idle
            }
        }
        .onChange(of: viewModel.isInterrupted) { _, isInterrupted in
            if isInterrupted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSpeaking = false
                    teacherMood = .listening
                    currentMessage = "نعم؟ بسمعك!"
                }
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.7, blue: 1.0),
                Color(red: 0.6, green: 0.5, blue: 0.9),
                Color(red: 0.9, green: 0.6, blue: 0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }
            
            Spacer()
            
            // Lesson title
            VStack(spacing: 2) {
                Text(viewModel.lesson.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.lesson.titleArabic)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Progress indicator
            KidsCircularProgressView(progress: lessonProgress)
                .frame(width: 40, height: 40)
        }
        .padding()
        .background(Color.black.opacity(0.1))
    }
    
    // MARK: - Avatar Section
    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                TeacherAvatarView(
                    mood: teacherMood,
                    isSpeaking: isSpeaking,
                    message: currentMessage
                )
                .frame(height: 320)
                
                // Interrupt button (only show when teacher is speaking)
                if isSpeaking {
                    Button(action: {
                        interruptTeacher()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                            Text("قاطع")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .shadow(color: .red.opacity(0.5), radius: 3, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Simple action buttons - just two: Listen and Ask
            HStack(spacing: 20) {
                // Listen button
                if !isSpeaking && !viewModel.isProcessing && !isAskingQuestion {
                    Button(action: {
                        speakCurrentWord()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.title2)
                            Text("اسمع")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.5), radius: 5, y: 3)
                    }
                }
                
                // Ask button - simple: tap to record, tap again to send
                if !isSpeaking && !viewModel.isProcessing {
                    Button(action: {
                        toggleAskQuestion()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isAskingQuestion ? "stop.fill" : "mic.fill")
                                .font(.title2)
                            Text(isAskingQuestion ? "ابعت" : "اسأل")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(isAskingQuestion ? Color.red : Color.purple)
                        .clipShape(Capsule())
                        .shadow(color: (isAskingQuestion ? Color.red : Color.purple).opacity(0.5), radius: 5, y: 3)
                    }
                    .scaleEffect(isAskingQuestion ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAskingQuestion)
                }
            }
            
            // Recording indicator
            if isAskingQuestion {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(recordingPulse ? 1.0 : 0.3)
                    Text("بسمعك...")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        recordingPulse = true
                    }
                }
                .onDisappear {
                    recordingPulse = false
                }
            }
            
            // Loading indicator
            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("المدرس بيفكر...")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Toggle Ask Question
    private func toggleAskQuestion() {
        if isAskingQuestion {
            // Stop and send
            isAskingQuestion = false
            recordingPulse = false
            teacherMood = .thinking
            currentMessage = "خليني أفكر..."
            
            Task {
                await viewModel.stopRecordingAndAskQuestion()
            }
        } else {
            // Start recording
            isAskingQuestion = true
            teacherMood = .listening
            currentMessage = "بسمعك..."
            
            Task {
                await viewModel.startRecordingQuestion()
            }
        }
    }
    
    // MARK: - Word Card
    private func wordCard(word: Word) -> some View {
        VStack(spacing: 16) {
            // Emoji/Image - BIG for kids to see
            if let emoji = word.emoji {
                Text(emoji)
                    .font(.system(size: 100))
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
            }
            
            // Arabic word - BIG and beautiful
            Text(word.arabic)
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Transliteration
            Text(word.transliteration)
                .font(.title2)
                .foregroundStyle(Color.gray)
            
            // English meaning
            Text(word.english)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.8))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Word Selector
    private var wordSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.wordsToLearn)
                .font(.headline)
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.lesson.words.enumerated()), id: \.element.id) { index, word in
                        KidsWordChip(
                            word: word,
                            isSelected: viewModel.currentWord?.id == word.id,
                            isCompleted: index < selectedWordIndex
                        ) {
                            viewModel.selectWord(word)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Score View
    private func scoreView(score: PronunciationScore) -> some View {
        VStack(spacing: 12) {
            // Stars based on score
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(score.score * 5) ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(.yellow)
                }
            }
            
            Text(score.feedback)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding()
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Bottom Action Area
    private var bottomActionArea: some View {
        VStack(spacing: 16) {
            // Processing status - show loading when checking pronunciation
            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("بسمع النطق...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 20)
            } else if viewModel.isRecording {
                RecordingIndicator()
            }
            
            // Big microphone button
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: buttonColor.opacity(0.5), radius: 10, y: 5)
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(viewModel.isProcessing)
            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
            
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(
            Color.black.opacity(0.2)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private var buttonColor: Color {
        if viewModel.isProcessing {
            return Color.orange
        } else if viewModel.isRecording {
            return Color.red
        } else {
            return Color.green
        }
    }
    
    private var statusText: String {
        if viewModel.isProcessing {
            return L10n.analyzingPronunciation
        } else if viewModel.isRecording {
            return L10n.listening
        } else {
            return L10n.pressAndSay
        }
    }
    
    // MARK: - Computed Properties
    private var lessonProgress: Double {
        guard !viewModel.lesson.words.isEmpty else { return 0 }
        return Double(selectedWordIndex) / Double(viewModel.lesson.words.count)
    }
    
    // MARK: - Actions
    private func startLesson() {
        Task {
            await viewModel.startSession()
            
            // Welcome message in Egyptian Arabic
            currentMessage = "يلا نبدأ الدرس!"
            teacherMood = .happy
            
            // Speak welcome
            if let firstWord = viewModel.lesson.words.first {
                viewModel.selectWord(firstWord)
            }
        }
    }
    
    private func speakCurrentWord() {
        guard let word = viewModel.currentWord else { return }
        currentMessage = word.arabic
        
        // Don't set isSpeaking here - let speakingProgressPublisher handle it
        // when audio actually starts playing
        teacherMood = .speaking
        
        Task {
            await viewModel.speakWord(word)
            
            // Speech finished
            teacherMood = .idle
        }
    }
    
    private func toggleRecording() {
        Task {
            if viewModel.isRecording {
                teacherMood = .thinking
                currentMessage = "خليني أسمع كويس..."
                await viewModel.stopRecording()
            } else {
                teacherMood = .listening
                currentMessage = "بسمعك... قول الكلمة!"
                await viewModel.startRecording()
            }
        }
    }
    
    private func handleScore(_ score: PronunciationScore) {
        if score.score >= 0.7 {
            // Great job! - Egyptian Arabic
            teacherMood = .celebrating
            currentMessage = "برافو عليك يا بطل! 🎉"
            
            withAnimation {
                showCelebration = true
            }
            
            // After celebration, say the word in a sentence, then move to next word
            Task {
                // Wait for celebration to be visible
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Keep celebration showing, change message
                await MainActor.run {
                    teacherMood = .speaking
                    currentMessage = "هاحطهالك في جملة، ركز معايا! 👂"
                }
                
                // Say "I'll put it in a sentence for you, focus with me"
                if let word = viewModel.currentWord {
                    await viewModel.speakSentenceIntro()
                    
                    // Small pause
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    
                    // Now say the sentence
                    await viewModel.speakWordInSentence(word)
                }
                
                // Wait a bit then move to next word
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                await MainActor.run {
                    withAnimation {
                        showCelebration = false
                        selectedWordIndex += 1
                        isSpeaking = false
                    }
                    moveToNextWord()
                }
            }
        } else if score.score >= 0.4 {
            // Good try - Egyptian Arabic
            teacherMood = .encouraging
            currentMessage = "شاطر! جرب تاني كمان مرة"
        } else {
            // Need more practice - Egyptian Arabic
            teacherMood = .encouraging
            currentMessage = "كمل! انت قدها!"
        }
    }
    
    private func moveToNextWord() {
        guard let currentWord = viewModel.currentWord,
              let currentIndex = viewModel.lesson.words.firstIndex(where: { $0.id == currentWord.id }),
              currentIndex + 1 < viewModel.lesson.words.count else {
            // Lesson complete! - Egyptian Arabic
            teacherMood = .celebrating
            currentMessage = "🎉 خلصت الدرس! شاطر أوي!"
            return
        }
        
        let nextWord = viewModel.lesson.words[currentIndex + 1]
        viewModel.selectWord(nextWord)
        teacherMood = .happy
        currentMessage = "يلا نتعلم: \(nextWord.arabic)"
    }
    
    // MARK: - Interruption Methods
    
    private func interruptTeacher() {
        Task {
            await viewModel.interruptTeacher()
            withAnimation(.easeInOut(duration: 0.2)) {
                isSpeaking = false
                teacherMood = .listening
                currentMessage = "نعم؟ بسمعك!"
            }
        }
    }
    
    // MARK: - Ask Question (Voice-based)
    
    private func startAskingQuestion() {
        if isAskingQuestion {
            // Stop recording and send question
            stopAskingQuestion()
        } else {
            // Start recording question
            isAskingQuestion = true
            recordingPulse = false
            teacherMood = .listening
            currentMessage = "بسمعك... اسأل سؤالك!"
            
            Task {
                await viewModel.startRecordingQuestion()
            }
        }
    }
    
    private func stopAskingQuestion() {
        isAskingQuestion = false
        recordingPulse = false
        teacherMood = .thinking
        currentMessage = "خليني أفكر..."
        
        Task {
            await viewModel.stopRecordingAndAskQuestion()
        }
    }
}

// MARK: - Supporting Views

struct KidsWordChip: View {
    let word: Word
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Show emoji if available
                if let emoji = word.emoji {
                    Text(emoji)
                        .font(.title)
                }
                Text(word.arabic)
                    .font(.headline)
                Text(word.english)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
            )
            .foregroundStyle(isCompleted ? .white : .primary)
        }
    }
    
    var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isSelected {
            return .white
        } else {
            return .white.opacity(0.7)
        }
    }
}

struct KidsCircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
    }
}

struct RecordingIndicator: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .scaleEffect(scale)
            
            Text(L10n.recording)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                scale = 1.3
            }
        }
    }
}

struct CelebrationOverlay: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color)] = []
    
    let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .orange, .pink]
    
    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 12, height: 12)
                    .position(x: particle.x, y: particle.y)
            }
            
            // Big star
            VStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 20)
                
                Text(L10n.amazing)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 5)
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        for i in 0..<30 {
            let particle = (
                id: i,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                color: colors.randomElement()!
            )
            particles.append(particle)
        }
    }
}

// MARK: - Preview
#Preview {
    let lesson = Lesson(
        id: "1",
        title: "Basic Greetings",
        titleArabic: "التحيات الأساسية",
        description: "Learn basic Arabic greetings",
        category: .greetings,
        level: .beginner,
        durationMinutes: 5,
        words: [
            Word(id: "1", english: "Hello", arabic: "مرحبا", transliteration: "Marhaba", category: .greetings),
            Word(id: "2", english: "Thank you", arabic: "شكراً", transliteration: "Shukran", category: .greetings),
            Word(id: "3", english: "Goodbye", arabic: "مع السلامة", transliteration: "Ma'a Salama", category: .greetings)
        ]
    )
    
    KidsLessonView(viewModel: DependencyContainer.shared.makeLessonViewModel(lesson: lesson))
}
