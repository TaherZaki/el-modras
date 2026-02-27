//
//  VocabularyUseCases.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

// MARK: - Recognize Object Use Case (Camera Vision)
protocol RecognizeObjectUseCase {
    func execute(imageData: Data) async throws -> RecognizedObject
}

struct RecognizedObject {
    let englishName: String
    let arabicName: String
    let transliteration: String
    let confidence: Double
    let relatedWords: [Word]
}

final class RecognizeObjectUseCaseImpl: RecognizeObjectUseCase {
    private let geminiService: GeminiService
    private let wordRepository: WordRepository
    
    init(geminiService: GeminiService, wordRepository: WordRepository) {
        self.geminiService = geminiService
        self.wordRepository = wordRepository
    }
    
    func execute(imageData: Data) async throws -> RecognizedObject {
        // Send image to Gemini for recognition
        let result = try await geminiService.recognizeObject(imageData: imageData)
        
        // Find related words from our vocabulary
        let relatedWords = try await wordRepository.searchWords(query: result.englishName)
        
        return RecognizedObject(
            englishName: result.englishName,
            arabicName: result.arabicName,
            transliteration: result.transliteration,
            confidence: result.confidence,
            relatedWords: relatedWords
        )
    }
}

// MARK: - Learn Word Use Case
protocol LearnWordUseCase {
    func execute(wordId: String, userId: String) async throws
}

final class LearnWordUseCaseImpl: LearnWordUseCase {
    private let wordRepository: WordRepository
    private let progressRepository: ProgressRepository
    
    init(wordRepository: WordRepository, progressRepository: ProgressRepository) {
        self.wordRepository = wordRepository
        self.progressRepository = progressRepository
    }
    
    func execute(wordId: String, userId: String) async throws {
        try await wordRepository.updatePracticeCount(wordId, for: userId)
    }
}

// MARK: - Master Word Use Case
protocol MasterWordUseCase {
    func execute(wordId: String, userId: String) async throws
}

final class MasterWordUseCaseImpl: MasterWordUseCase {
    private let wordRepository: WordRepository
    private let progressRepository: ProgressRepository
    
    init(wordRepository: WordRepository, progressRepository: ProgressRepository) {
        self.wordRepository = wordRepository
        self.progressRepository = progressRepository
    }
    
    func execute(wordId: String, userId: String) async throws {
        try await wordRepository.markWordAsMastered(wordId, for: userId)
        
        // Check for achievements
        let masteredWords = try await wordRepository.getMasteredWords(for: userId)
        
        if masteredWords.count == 1 {
            try await progressRepository.unlockAchievement(.firstWord, for: userId)
        } else if masteredWords.count == 10 {
            try await progressRepository.unlockAchievement(.tenWords, for: userId)
        } else if masteredWords.count == 50 {
            try await progressRepository.unlockAchievement(.fiftyWords, for: userId)
        } else if masteredWords.count == 100 {
            try await progressRepository.unlockAchievement(.hundredWords, for: userId)
        }
    }
}

// MARK: - Search Words Use Case
protocol SearchWordsUseCase {
    func execute(query: String) async throws -> [Word]
}

final class SearchWordsUseCaseImpl: SearchWordsUseCase {
    private let repository: WordRepository
    
    init(repository: WordRepository) {
        self.repository = repository
    }
    
    func execute(query: String) async throws -> [Word] {
        guard !query.isEmpty else { return [] }
        return try await repository.searchWords(query: query)
    }
}

// MARK: - Get Words By Category Use Case
protocol GetWordsByCategoryUseCase {
    func execute(category: LessonCategory) async throws -> [Word]
}

final class GetWordsByCategoryUseCaseImpl: GetWordsByCategoryUseCase {
    private let repository: WordRepository
    
    init(repository: WordRepository) {
        self.repository = repository
    }
    
    func execute(category: LessonCategory) async throws -> [Word] {
        try await repository.getWords(for: category)
    }
}
