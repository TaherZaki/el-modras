//
//  ProgressRepositoryImpl.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

final class ProgressRepositoryImpl: ProgressRepository {
    private let remoteDataSource: ProgressRemoteDataSource
    private let localDataSource: ProgressLocalDataSource
    
    init(remoteDataSource: ProgressRemoteDataSource, localDataSource: ProgressLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getProgress(for userId: String) async throws -> UserProgress? {
        if let localProgress = try await localDataSource.getProgress(for: userId) {
            return localProgress
        }
        
        // Create default progress for new user
        let defaultProgress = UserProgress(
            userId: userId,
            achievements: AchievementType.allCases.map { type in
                Achievement(
                    type: type,
                    target: type.targetValue
                )
            }
        )
        try await localDataSource.saveProgress(defaultProgress)
        return defaultProgress
    }
    
    func saveProgress(_ progress: UserProgress) async throws {
        try await localDataSource.saveProgress(progress)
        try await remoteDataSource.saveProgress(progress)
    }
    
    func updateDailyProgress(_ dailyProgress: DailyProgress, for userId: String) async throws {
        guard var progress = try await getProgress(for: userId) else { return }
        
        // Find or create today's progress
        let calendar = Calendar.current
        if let index = progress.dailyProgress.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dailyProgress.date) }) {
            // ACCUMULATE instead of replace
            progress.dailyProgress[index].wordsLearned += dailyProgress.wordsLearned
            progress.dailyProgress[index].lessonsCompleted += dailyProgress.lessonsCompleted
            progress.dailyProgress[index].minutesPracticed += dailyProgress.minutesPracticed
            progress.dailyProgress[index].conversationCount += dailyProgress.conversationCount
            progress.dailyProgress[index].cameraScans += dailyProgress.cameraScans
        } else {
            progress.dailyProgress.append(dailyProgress)
        }
        
        // Update totals
        progress.totalWordsLearned += dailyProgress.wordsLearned
        progress.totalMinutesPracticed += dailyProgress.minutesPracticed
        progress.lessonsCompleted += dailyProgress.lessonsCompleted
        progress.lastPracticeDate = Date()
        
        // Update achievement progress counts
        for i in 0..<progress.achievements.count {
            switch progress.achievements[i].type {
            case .firstWord, .tenWords, .fiftyWords, .hundredWords:
                progress.achievements[i].progress = progress.totalWordsLearned
            case .firstLesson, .tenLessons:
                progress.achievements[i].progress = progress.lessonsCompleted
            case .weekStreak, .monthStreak:
                progress.achievements[i].progress = progress.currentStreak
            default:
                break
            }
        }
        
        try await saveProgress(progress)
    }
    
    func updateCategoryProgress(_ categoryProgress: CategoryProgress, for userId: String) async throws {
        guard var progress = try await getProgress(for: userId) else { return }
        
        if let index = progress.categoryProgress.firstIndex(where: { $0.category == categoryProgress.category }) {
            progress.categoryProgress[index] = categoryProgress
        } else {
            progress.categoryProgress.append(categoryProgress)
        }
        
        try await saveProgress(progress)
    }
    
    func unlockAchievement(_ achievementType: AchievementType, for userId: String) async throws {
        guard var progress = try await getProgress(for: userId) else { return }
        
        if let index = progress.achievements.firstIndex(where: { $0.type == achievementType }) {
            if !progress.achievements[index].isUnlocked {
                progress.achievements[index].isUnlocked = true
                progress.achievements[index].unlockedAt = Date()
            }
            progress.achievements[index].progress = max(progress.achievements[index].progress, progress.achievements[index].target)
        }
        
        try await saveProgress(progress)
    }
    
    func updateStreak(for userId: String) async throws {
        guard var progress = try await getProgress(for: userId) else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        if let lastPractice = progress.lastPracticeDate {
            if calendar.isDateInYesterday(lastPractice) {
                // Continue streak
                progress.currentStreak += 1
            } else if !calendar.isDateInToday(lastPractice) {
                // Streak broken
                progress.currentStreak = 1
            }
            // If today, don't change streak
        } else {
            // First time practicing
            progress.currentStreak = 1
        }
        
        // Update longest streak
        if progress.currentStreak > progress.longestStreak {
            progress.longestStreak = progress.currentStreak
        }
        
        progress.lastPracticeDate = today
        
        // Update streak achievement progress
        for i in 0..<progress.achievements.count {
            if progress.achievements[i].type == .weekStreak || progress.achievements[i].type == .monthStreak {
                progress.achievements[i].progress = progress.currentStreak
            }
        }
        
        // Check streak achievements
        if progress.currentStreak >= 7 {
            try await unlockAchievement(.weekStreak, for: userId)
        }
        if progress.currentStreak >= 30 {
            try await unlockAchievement(.monthStreak, for: userId)
        }
        
        try await saveProgress(progress)
    }
    
    func getLeaderboard() async throws -> [UserProgress] {
        try await remoteDataSource.fetchLeaderboard()
    }
}

// MARK: - Remote Data Source
final class ProgressRemoteDataSource {
    private let baseURL = AppConfig.backendURL
    
    func saveProgress(_ progress: UserProgress) async throws {
        // In production, save to Firestore
    }
    
    func fetchLeaderboard() async throws -> [UserProgress] {
        // In production, fetch from Firestore
        return []
    }
}

// MARK: - Local Data Source
final class ProgressLocalDataSource {
    private let progressKey = "user_progress"
    
    func getProgress(for userId: String) async throws -> UserProgress? {
        guard let data = UserDefaults.standard.data(forKey: "\(progressKey)_\(userId)") else {
            return nil
        }
        return try JSONDecoder().decode(UserProgress.self, from: data)
    }
    
    func saveProgress(_ progress: UserProgress) async throws {
        let data = try JSONEncoder().encode(progress)
        UserDefaults.standard.set(data, forKey: "\(progressKey)_\(progress.userId)")
    }
}

// MARK: - Achievement Target Values
extension AchievementType {
    var targetValue: Int {
        switch self {
        case .firstWord: return 1
        case .tenWords: return 10
        case .fiftyWords: return 50
        case .hundredWords: return 100
        case .firstLesson: return 1
        case .tenLessons: return 10
        case .firstConversation: return 1
        case .tenConversations: return 10
        case .weekStreak: return 7
        case .monthStreak: return 30
        case .cameraExplorer: return 20
        case .perfectPronunciation: return 1
        }
    }
}
