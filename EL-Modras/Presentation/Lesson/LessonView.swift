//
//  LessonView.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import SwiftUI

struct LessonView: View {
    @StateObject private var viewModel: LessonViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: LessonViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with lesson info
                lessonHeader
                
                // Main content area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Word cards (if lesson has vocabulary)
                            if !viewModel.wordsInLesson.isEmpty {
                                wordCardsSection
                            }
                            
                            // Conversation messages
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message) {
                                    Task {
                                        await viewModel.speakResponse(message)
                                    }
                                }
                                .id(message.id)
                            }
                            
                            // Processing indicator
                            if viewModel.isProcessing {
                                ProcessingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Bottom control area
                controlArea
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        Task {
                            await viewModel.endSession()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSessionActive {
                        Button("End Session") {
                            Task {
                                await viewModel.endSession()
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert("Session Error", isPresented: .constant(viewModel.error != nil)) {
                Button("Retry") {
                    viewModel.error = nil
                    Task {
                        await viewModel.startSession()
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Lesson Header
    private var lessonHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: viewModel.lesson.category.icon)
                    .foregroundStyle(.blue)
                
                Text(viewModel.lesson.titleArabic)
                    .font(.headline)
                
                Spacer()
                
                SessionStateBadge(state: viewModel.sessionState)
            }
            
            if let currentWord = viewModel.currentWord {
                CurrentWordCard(
                    word: currentWord,
                    score: viewModel.pronunciationScore
                ) {
                    Task {
                        await viewModel.speakWord(currentWord)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Word Cards Section
    private var wordCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words to Practice")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.wordsInLesson) { word in
                        WordChip(
                            word: word,
                            isSelected: viewModel.currentWord?.id == word.id
                        ) {
                            viewModel.selectWord(word)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Control Area
    private var controlArea: some View {
        VStack(spacing: 16) {
            // Audio level indicator
            if viewModel.isRecording {
                AudioLevelView(level: viewModel.audioLevel)
                    .frame(height: 40)
            }
            
            // Main controls
            HStack(spacing: 24) {
                if viewModel.canStartSession {
                    // Start session button
                    Button {
                        Task {
                            await viewModel.startSession()
                        }
                    } label: {
                        Label("Start Lesson", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if viewModel.isSessionActive {
                    // Recording button
                    RecordButton(
                        isRecording: viewModel.isRecording,
                        isProcessing: viewModel.isProcessing
                    ) {
                        Task {
                            if viewModel.isRecording {
                                await viewModel.stopRecording()
                            } else {
                                await viewModel.startRecording()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Supporting Views

struct SessionStateBadge: View {
    let state: LessonViewModel.SessionState
    
    var color: Color {
        switch state {
        case .idle: return .gray
        case .connecting: return .orange
        case .active: return .green
        case .ended: return .blue
        }
    }
    
    var text: String {
        switch state {
        case .idle: return "Ready"
        case .connecting: return "Connecting..."
        case .active: return "Live"
        case .ended: return "Completed"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct CurrentWordCard: View {
    let word: Word
    let score: PronunciationScore?
    let onSpeak: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice this word:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(word.arabic)
                    .font(.system(size: 32, weight: .bold))
                
                Text("\(word.transliteration) - \(word.english)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                
                if let score = score {
                    ScoreIndicator(score: score.score)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ScoreIndicator: View {
    let score: Double
    
    var color: Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Text("\(Int(score * 100))%")
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct WordChip: View {
    let word: Word
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(word.arabic)
                    .font(.headline)
                Text(word.english)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct MessageBubble: View {
    let message: ConversationMessage
    var onSpeakTapped: (() -> Void)? = nil
    
    var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                
                if let arabic = message.contentArabic {
                    Text(arabic)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if !isUser, let onSpeakTapped = onSpeakTapped {
                        Button(action: onSpeakTapped) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(isUser ? .white.opacity(0.8) : .blue)
                        }
                    }
                }
            }
            .padding(12)
            .background(isUser ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if !isUser { Spacer() }
        }
    }
}

struct ProcessingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Processing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AudioLevelView: View {
    let level: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: (geometry.size.width - 60) / 30)
                        .scaleY(barScale(for: index))
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func barScale(for index: Int) -> CGFloat {
        let threshold = Double(index) / 30.0
        return level > threshold ? 1.0 : 0.3
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Double(index) / 30.0
        if threshold < 0.5 { return .green }
        if threshold < 0.8 { return .yellow }
        return .red
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 72, height: 72)
                
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isProcessing)
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

extension View {
    func scaleY(_ scale: CGFloat) -> some View {
        self.scaleEffect(CGSize(width: 1, height: scale))
    }
}

#Preview {
    let lesson = Lesson.sampleLessons[0]
    return LessonView(viewModel: DependencyContainer.shared.makeLessonViewModel(lesson: lesson))
}
