//
//  LessonUseCases.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

// MARK: - Get All Lessons Use Case
protocol GetAllLessonsUseCase {
    func execute() async throws -> [Lesson]
}

final class GetAllLessonsUseCaseImpl: GetAllLessonsUseCase {
    private let repository: LessonRepository
    
    init(repository: LessonRepository) {
        self.repository = repository
    }
    
    func execute() async throws -> [Lesson] {
        try await repository.getAllLessons()
    }
}

// MARK: - Get Lessons By Category Use Case
protocol GetLessonsByCategoryUseCase {
    func execute(category: LessonCategory) async throws -> [Lesson]
}

final class GetLessonsByCategoryUseCaseImpl: GetLessonsByCategoryUseCase {
    private let repository: LessonRepository
    
    init(repository: LessonRepository) {
        self.repository = repository
    }
    
    func execute(category: LessonCategory) async throws -> [Lesson] {
        try await repository.getLessons(for: category)
    }
}

// MARK: - Get Recommended Lessons Use Case
protocol GetRecommendedLessonsUseCase {
    func execute(userId: String) async throws -> [Lesson]
}

final class GetRecommendedLessonsUseCaseImpl: GetRecommendedLessonsUseCase {
    private let repository: LessonRepository
    
    init(repository: LessonRepository) {
        self.repository = repository
    }
    
    func execute(userId: String) async throws -> [Lesson] {
        try await repository.getRecommendedLessons(for: userId)
    }
}

// MARK: - Start Lesson Session Use Case
protocol StartLessonSessionUseCase {
    func execute(lessonId: String, userId: String) async throws -> LessonSession
}

final class StartLessonSessionUseCaseImpl: StartLessonSessionUseCase {
    private let repository: LessonRepository
    
    init(repository: LessonRepository) {
        self.repository = repository
    }
    
    func execute(lessonId: String, userId: String) async throws -> LessonSession {
        try await repository.startSession(lessonId: lessonId, userId: userId)
    }
}

// MARK: - End Lesson Session Use Case
protocol EndLessonSessionUseCase {
    func execute(session: LessonSession) async throws
}

final class EndLessonSessionUseCaseImpl: EndLessonSessionUseCase {
    private let repository: LessonRepository
    private let progressRepository: ProgressRepository
    
    init(repository: LessonRepository, progressRepository: ProgressRepository) {
        self.repository = repository
        self.progressRepository = progressRepository
    }
    
    func execute(session: LessonSession) async throws {
        var completedSession = session
        completedSession.endedAt = Date()
        try await repository.endSession(completedSession)
        
        // Update user progress
        try await progressRepository.updateStreak(for: session.userId)
    }
}

// MARK: - Complete Lesson Use Case
protocol CompleteLessonUseCase {
    func execute(lessonId: String, userId: String) async throws
}

final class CompleteLessonUseCaseImpl: CompleteLessonUseCase {
    private let lessonRepository: LessonRepository
    private let progressRepository: ProgressRepository
    
    init(lessonRepository: LessonRepository, progressRepository: ProgressRepository) {
        self.lessonRepository = lessonRepository
        self.progressRepository = progressRepository
    }
    
    func execute(lessonId: String, userId: String) async throws {
        try await lessonRepository.markLessonCompleted(lessonId)
        try await progressRepository.updateStreak(for: userId)
    }
}

// MARK: - Track Word Learned Use Case
protocol TrackWordLearnedUseCase {
    func execute(word: Word, category: LessonCategory, userId: String) async throws
}

final class TrackWordLearnedUseCaseImpl: TrackWordLearnedUseCase {
    private let progressRepository: ProgressRepository
    
    init(progressRepository: ProgressRepository) {
        self.progressRepository = progressRepository
    }
    
    func execute(word: Word, category: LessonCategory, userId: String) async throws {
        // Update daily progress
        let dailyProgress = DailyProgress(
            date: Date(),
            wordsLearned: 1,
            minutesPracticed: 1
        )
        try await progressRepository.updateDailyProgress(dailyProgress, for: userId)
        
        // Update category progress
        var currentProgress = try await progressRepository.getProgress(for: userId)
        let existingCategoryProgress = currentProgress?.categoryProgress.first(where: { $0.category == category })
        
        let categoryProgress = CategoryProgress(
            category: category,
            wordsLearned: (existingCategoryProgress?.wordsLearned ?? 0) + 1,
            totalWords: 10, // Approximate
            accuracy: existingCategoryProgress?.accuracy ?? 0.8
        )
        try await progressRepository.updateCategoryProgress(categoryProgress, for: userId)
        
        // Check for achievements
        let progress = try await progressRepository.getProgress(for: userId)
        let totalWords = progress?.totalWordsLearned ?? 0
        
        // First word achievement
        if totalWords >= 1 {
            try await progressRepository.unlockAchievement(.firstWord, for: userId)
        }
        // 10 words achievement
        if totalWords >= 10 {
            try await progressRepository.unlockAchievement(.tenWords, for: userId)
        }
        // 50 words achievement
        if totalWords >= 50 {
            try await progressRepository.unlockAchievement(.fiftyWords, for: userId)
        }
        // 100 words achievement
        if totalWords >= 100 {
            try await progressRepository.unlockAchievement(.hundredWords, for: userId)
        }
        
        // Update streak
        try await progressRepository.updateStreak(for: userId)
    }
}

// MARK: - Track Lesson Completed Use Case
protocol TrackLessonCompletedUseCase {
    func execute(lesson: Lesson, userId: String) async throws
}

final class TrackLessonCompletedUseCaseImpl: TrackLessonCompletedUseCase {
    private let progressRepository: ProgressRepository
    private let lessonRepository: LessonRepository
    
    init(progressRepository: ProgressRepository, lessonRepository: LessonRepository) {
        self.progressRepository = progressRepository
        self.lessonRepository = lessonRepository
    }
    
    func execute(lesson: Lesson, userId: String) async throws {
        // Mark lesson as completed
        try await lessonRepository.markLessonCompleted(lesson.id)
        
        // Update daily progress (don't add wordsLearned here - each word is tracked individually in trackWordLearned)
        let dailyProgress = DailyProgress(
            date: Date(),
            wordsLearned: 0,
            lessonsCompleted: 1,
            minutesPracticed: lesson.durationMinutes
        )
        try await progressRepository.updateDailyProgress(dailyProgress, for: userId)
        
        // Check for lesson achievements
        let progress = try await progressRepository.getProgress(for: userId)
        let totalLessons = progress?.lessonsCompleted ?? 0
        
        if totalLessons >= 1 {
            try await progressRepository.unlockAchievement(.firstLesson, for: userId)
        }
        if totalLessons >= 10 {
            try await progressRepository.unlockAchievement(.tenLessons, for: userId)
        }
        
        // Update streak
        try await progressRepository.updateStreak(for: userId)
    }
}
