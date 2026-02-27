//
//  ConversationUseCases.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

// MARK: - Start Conversation Use Case
protocol StartConversationUseCase {
    func execute(lessonId: String?, userId: String) async throws -> ConversationSession
}

struct ConversationSession {
    let id: String
    let userId: String
    let lessonId: String?
    var isActive: Bool
    var messages: [ConversationMessage]
    let startedAt: Date
}

final class StartConversationUseCaseImpl: StartConversationUseCase {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
    }
    
    func execute(lessonId: String?, userId: String) async throws -> ConversationSession {
        // Initialize Gemini Live API session
        try await geminiService.startLiveSession()
        
        return ConversationSession(
            id: UUID().uuidString,
            userId: userId,
            lessonId: lessonId,
            isActive: true,
            messages: [],
            startedAt: Date()
        )
    }
}

// MARK: - Send Voice Message Use Case
protocol SendVoiceMessageUseCase {
    func execute(audioData: Data, session: ConversationSession) async throws -> ConversationMessage
}

final class SendVoiceMessageUseCaseImpl: SendVoiceMessageUseCase {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
    }
    
    func execute(audioData: Data, session: ConversationSession) async throws -> ConversationMessage {
        let response = try await geminiService.sendAudioMessage(audioData: audioData)
        
        return ConversationMessage(
            role: .assistant,
            content: response.text,
            contentArabic: response.arabicText,
            audioURL: response.audioURL
        )
    }
}

// MARK: - End Conversation Use Case
protocol EndConversationUseCase {
    func execute(session: ConversationSession) async throws -> ConversationSummary
}

struct ConversationSummary {
    let duration: TimeInterval
    let messagesCount: Int
    let wordsLearned: [Word]
    let pronunciationFeedback: [PronunciationScore]
    let overallScore: Double
}

final class EndConversationUseCaseImpl: EndConversationUseCase {
    private let geminiService: GeminiService
    private let progressRepository: ProgressRepository
    
    init(geminiService: GeminiService, progressRepository: ProgressRepository) {
        self.geminiService = geminiService
        self.progressRepository = progressRepository
    }
    
    func execute(session: ConversationSession) async throws -> ConversationSummary {
        // End Gemini Live session
        try await geminiService.endLiveSession()
        
        let duration = Date().timeIntervalSince(session.startedAt)
        
        // Update progress
        try await progressRepository.updateStreak(for: session.userId)
        
        return ConversationSummary(
            duration: duration,
            messagesCount: session.messages.count,
            wordsLearned: [],
            pronunciationFeedback: [],
            overallScore: 0.85
        )
    }
}

// MARK: - Get Pronunciation Feedback Use Case
protocol GetPronunciationFeedbackUseCase {
    func execute(audioData: Data, expectedWord: Word) async throws -> PronunciationScore
}

final class GetPronunciationFeedbackUseCaseImpl: GetPronunciationFeedbackUseCase {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
    }
    
    func execute(audioData: Data, expectedWord: Word) async throws -> PronunciationScore {
        let feedback = try await geminiService.analyzePronunciation(
            audioData: audioData,
            expectedText: expectedWord.arabic
        )
        
        return PronunciationScore(
            wordId: expectedWord.id,
            score: feedback.score,
            feedback: feedback.feedback
        )
    }
}
