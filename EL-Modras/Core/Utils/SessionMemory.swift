//
//  SessionMemory.swift
//  EL-Modras
//
//  Remembers what the child was doing last time
//

import Foundation

enum LastActivityType: String, Codable {
    case lesson
    case story
    case camera
}

struct LastActivity: Codable {
    let type: LastActivityType
    let id: String           // lesson or story ID
    let title: String        // display name (Arabic)
    let wordIndex: Int       // which word they were on (for lessons)
    let sceneIndex: Int      // which scene they were on (for stories)
    let totalWords: Int      // total words in lesson
    let totalScenes: Int     // total scenes in story
    let timestamp: Date
    
    var isLesson: Bool { type == .lesson }
    var isStory: Bool { type == .story }
    
    var progressText: String {
        switch type {
        case .lesson:
            return "كلمة \(wordIndex + 1) من \(totalWords)"
        case .story:
            return "مشهد \(sceneIndex + 1) من \(totalScenes)"
        case .camera:
            return ""
        }
    }
    
    var progressPercent: Double {
        switch type {
        case .lesson:
            guard totalWords > 0 else { return 0 }
            return Double(wordIndex) / Double(totalWords)
        case .story:
            guard totalScenes > 0 else { return 0 }
            return Double(sceneIndex) / Double(totalScenes)
        case .camera:
            return 0
        }
    }
    
    /// Returns true if the activity was not completed
    var isIncomplete: Bool {
        switch type {
        case .lesson:
            return wordIndex < totalWords - 1
        case .story:
            return sceneIndex < totalScenes - 1
        case .camera:
            return false
        }
    }
    
    /// How long ago the activity happened
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 1 { return "دلوقتي" }
        if minutes < 60 { return "من \(minutes) دقيقة" }
        if hours < 24 { return "من \(hours) ساعة" }
        if days == 1 { return "من إمبارح" }
        return "من \(days) يوم"
    }
}

// MARK: - Session Memory Manager
final class SessionMemory {
    static let shared = SessionMemory()
    
    private let defaults = UserDefaults.standard
    private let lastActivityKey = "nour_last_activity"
    private let hasEverOpenedKey = "nour_has_ever_opened"
    private let totalSessionsKey = "nour_total_sessions"
    private let childNameKey = "nour_child_name"
    
    private init() {}
    
    // MARK: - First Time Check
    
    /// Is this the very first time the app is opened?
    var isFirstEver: Bool {
        return !defaults.bool(forKey: hasEverOpenedKey)
    }
    
    /// Mark that the app has been opened at least once
    func markAppOpened() {
        defaults.set(true, forKey: hasEverOpenedKey)
        defaults.set(totalSessions + 1, forKey: totalSessionsKey)
    }
    
    /// Total number of sessions
    var totalSessions: Int {
        return defaults.integer(forKey: totalSessionsKey)
    }
    
    // MARK: - Child Name
    
    var childName: String? {
        get { defaults.string(forKey: childNameKey) }
        set { defaults.set(newValue, forKey: childNameKey) }
    }
    
    // MARK: - Last Activity
    
    /// Save the current activity (called during lesson/story)
    func saveActivity(type: LastActivityType, id: String, title: String, wordIndex: Int = 0, sceneIndex: Int = 0, totalWords: Int = 0, totalScenes: Int = 0) {
        let activity = LastActivity(
            type: type,
            id: id,
            title: title,
            wordIndex: wordIndex,
            sceneIndex: sceneIndex,
            totalWords: totalWords,
            totalScenes: totalScenes,
            timestamp: Date()
        )
        
        if let data = try? JSONEncoder().encode(activity) {
            defaults.set(data, forKey: lastActivityKey)
        }
    }
    
    /// Get the last activity (if any)
    var lastActivity: LastActivity? {
        guard let data = defaults.data(forKey: lastActivityKey) else { return nil }
        return try? JSONDecoder().decode(LastActivity.self, from: data)
    }
    
    /// Clear the last activity (when completed)
    func clearLastActivity() {
        defaults.removeObject(forKey: lastActivityKey)
    }
    
    /// Is there an incomplete activity to continue?
    var hasIncompleteActivity: Bool {
        guard let activity = lastActivity else { return false }
        return activity.isIncomplete
    }
}
