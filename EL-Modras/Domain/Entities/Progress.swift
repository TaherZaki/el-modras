//
//  Progress.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

struct UserProgress: Identifiable, Codable {
    let id: String
    let userId: String
    var totalWordsLearned: Int
    var totalMinutesPracticed: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDate: Date?
    var dailyProgress: [DailyProgress]
    var categoryProgress: [CategoryProgress]
    var achievements: [Achievement]
    var lessonsCompleted: Int
    var conversationsCompleted: Int
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        totalWordsLearned: Int = 0,
        totalMinutesPracticed: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastPracticeDate: Date? = nil,
        dailyProgress: [DailyProgress] = [],
        categoryProgress: [CategoryProgress] = [],
        achievements: [Achievement] = [],
        lessonsCompleted: Int = 0,
        conversationsCompleted: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.totalWordsLearned = totalWordsLearned
        self.totalMinutesPracticed = totalMinutesPracticed
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastPracticeDate = lastPracticeDate
        self.dailyProgress = dailyProgress
        self.categoryProgress = categoryProgress
        self.achievements = achievements
        self.lessonsCompleted = lessonsCompleted
        self.conversationsCompleted = conversationsCompleted
    }
    
    var averageAccuracy: Double {
        guard !categoryProgress.isEmpty else { return 0.0 }
        let total = categoryProgress.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(categoryProgress.count)
    }
    
    var weeklyMinutes: Int {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return dailyProgress
            .filter { $0.date >= oneWeekAgo }
            .reduce(0) { $0 + $1.minutesPracticed }
    }
}

struct DailyProgress: Identifiable, Codable {
    let id: String
    let date: Date
    var wordsLearned: Int
    var lessonsCompleted: Int
    var minutesPracticed: Int
    var conversationCount: Int
    var cameraScans: Int
    
    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        wordsLearned: Int = 0,
        lessonsCompleted: Int = 0,
        minutesPracticed: Int = 0,
        conversationCount: Int = 0,
        cameraScans: Int = 0
    ) {
        self.id = id
        self.date = date
        self.wordsLearned = wordsLearned
        self.lessonsCompleted = lessonsCompleted
        self.minutesPracticed = minutesPracticed
        self.conversationCount = conversationCount
        self.cameraScans = cameraScans
    }
}

struct CategoryProgress: Identifiable, Codable {
    let id: String
    let category: LessonCategory
    var wordsLearned: Int
    var totalWords: Int
    var lessonsCompleted: Int
    var totalLessons: Int
    var accuracy: Double
    
    init(
        id: String = UUID().uuidString,
        category: LessonCategory,
        wordsLearned: Int = 0,
        totalWords: Int = 0,
        lessonsCompleted: Int = 0,
        totalLessons: Int = 0,
        accuracy: Double = 0.0
    ) {
        self.id = id
        self.category = category
        self.wordsLearned = wordsLearned
        self.totalWords = totalWords
        self.lessonsCompleted = lessonsCompleted
        self.totalLessons = totalLessons
        self.accuracy = accuracy
    }
    
    var progressPercentage: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(wordsLearned) / Double(totalWords)
    }
}

struct Achievement: Identifiable, Codable {
    let id: String
    let type: AchievementType
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Int
    var target: Int
    
    init(
        id: String = UUID().uuidString,
        type: AchievementType,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil,
        progress: Int = 0,
        target: Int
    ) {
        self.id = id
        self.type = type
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.progress = progress
        self.target = target
    }
    
    var progressPercentage: Double {
        guard target > 0 else { return 0.0 }
        return min(Double(progress) / Double(target), 1.0)
    }
}

enum AchievementType: String, Codable, CaseIterable {
    case firstWord = "first_word"
    case tenWords = "ten_words"
    case fiftyWords = "fifty_words"
    case hundredWords = "hundred_words"
    case firstLesson = "first_lesson"
    case tenLessons = "ten_lessons"
    case firstConversation = "first_conversation"
    case tenConversations = "ten_conversations"
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case cameraExplorer = "camera_explorer"
    case perfectPronunciation = "perfect_pronunciation"
    
    var displayName: String {
        switch self {
        case .firstWord: return "First Steps"
        case .tenWords: return "Word Collector"
        case .fiftyWords: return "Vocabulary Builder"
        case .hundredWords: return "Word Master"
        case .firstLesson: return "Student"
        case .tenLessons: return "Dedicated Learner"
        case .firstConversation: return "Conversation Starter"
        case .tenConversations: return "Chatterbox"
        case .weekStreak: return "Week Warrior"
        case .monthStreak: return "Month Champion"
        case .cameraExplorer: return "Visual Explorer"
        case .perfectPronunciation: return "Perfect Accent"
        }
    }
    
    var description: String {
        switch self {
        case .firstWord: return "Learn your first Arabic word"
        case .tenWords: return "Learn 10 Arabic words"
        case .fiftyWords: return "Learn 50 Arabic words"
        case .hundredWords: return "Learn 100 Arabic words"
        case .firstLesson: return "Complete your first lesson"
        case .tenLessons: return "Complete 10 lessons"
        case .firstConversation: return "Have your first conversation"
        case .tenConversations: return "Have 10 conversations"
        case .weekStreak: return "Practice for 7 days in a row"
        case .monthStreak: return "Practice for 30 days in a row"
        case .cameraExplorer: return "Scan 20 objects with camera"
        case .perfectPronunciation: return "Get perfect score on pronunciation"
        }
    }
    
    var icon: String {
        switch self {
        case .firstWord: return "star.fill"
        case .tenWords: return "books.vertical.fill"
        case .fiftyWords: return "text.book.closed.fill"
        case .hundredWords: return "crown.fill"
        case .firstLesson: return "graduationcap.fill"
        case .tenLessons: return "medal.fill"
        case .firstConversation: return "bubble.left.fill"
        case .tenConversations: return "bubble.left.and.bubble.right.fill"
        case .weekStreak: return "flame.fill"
        case .monthStreak: return "flame.circle.fill"
        case .cameraExplorer: return "camera.fill"
        case .perfectPronunciation: return "waveform.circle.fill"
        }
    }
}
