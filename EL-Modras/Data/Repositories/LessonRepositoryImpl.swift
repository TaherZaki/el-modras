//
//  LessonRepositoryImpl.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

final class LessonRepositoryImpl: LessonRepository {
    private let remoteDataSource: LessonRemoteDataSource
    private let localDataSource: LessonLocalDataSource
    
    init(remoteDataSource: LessonRemoteDataSource, localDataSource: LessonLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getAllLessons() async throws -> [Lesson] {
        // Try local cache first
        let localLessons = try await localDataSource.getAllLessons()
        if !localLessons.isEmpty {
            return localLessons
        }
        
        // Fetch from remote and cache
        let remoteLessons = try await remoteDataSource.fetchAllLessons()
        try await localDataSource.saveLessons(remoteLessons)
        return remoteLessons
    }
    
    func getLesson(by id: String) async throws -> Lesson? {
        let lessons = try await getAllLessons()
        return lessons.first { $0.id == id }
    }
    
    func getLessons(for category: LessonCategory) async throws -> [Lesson] {
        let lessons = try await getAllLessons()
        return lessons.filter { $0.category == category }
    }
    
    func getLessons(for level: ArabicLevel) async throws -> [Lesson] {
        let lessons = try await getAllLessons()
        return lessons.filter { $0.level == level }
    }
    
    func getRecommendedLessons(for userId: String) async throws -> [Lesson] {
        let lessons = try await getAllLessons()
        // Return uncompleted lessons, sorted by level
        return lessons
            .filter { !$0.isCompleted }
            .sorted { $0.level.rawValue < $1.level.rawValue }
            .prefix(5)
            .map { $0 }
    }
    
    func updateLessonProgress(_ lessonId: String, progress: Double) async throws {
        try await localDataSource.updateProgress(lessonId: lessonId, progress: progress)
    }
    
    func markLessonCompleted(_ lessonId: String) async throws {
        try await localDataSource.markCompleted(lessonId: lessonId)
    }
    
    func startSession(lessonId: String, userId: String) async throws -> LessonSession {
        let session = LessonSession(lessonId: lessonId, userId: userId)
        try await localDataSource.saveSession(session)
        return session
    }
    
    func endSession(_ session: LessonSession) async throws {
        try await localDataSource.saveSession(session)
        try await remoteDataSource.saveSession(session)
    }
    
    func getSessions(for userId: String) async throws -> [LessonSession] {
        try await localDataSource.getSessions(for: userId)
    }
}

// MARK: - Remote Data Source
final class LessonRemoteDataSource {
    private let baseURL = AppConfig.backendURL
    
    func fetchAllLessons() async throws -> [Lesson] {
        // Return sample lessons for now
        // In production, this would fetch from Firestore
        return Lesson.sampleLessons
    }
    
    func saveSession(_ session: LessonSession) async throws {
        let url = URL(string: "\(baseURL)/api/v1/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(session)
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Local Data Source
final class LessonLocalDataSource {
    private let lessonsKey = "cached_lessons"
    private let sessionsKey = "lesson_sessions"
    private let progressKey = "lesson_progress"
    
    func getAllLessons() async throws -> [Lesson] {
        // Always return the latest sample lessons
        // This ensures new lessons are always available
        return Lesson.sampleLessons
    }
    
    func saveLessons(_ lessons: [Lesson]) async throws {
        let data = try JSONEncoder().encode(lessons)
        UserDefaults.standard.set(data, forKey: lessonsKey)
    }
    
    func updateProgress(lessonId: String, progress: Double) async throws {
        var lessons = try await getAllLessons()
        if let index = lessons.firstIndex(where: { $0.id == lessonId }) {
            lessons[index].progress = progress
            try await saveLessons(lessons)
        }
    }
    
    func markCompleted(lessonId: String) async throws {
        var lessons = try await getAllLessons()
        if let index = lessons.firstIndex(where: { $0.id == lessonId }) {
            lessons[index].isCompleted = true
            lessons[index].progress = 1.0
            try await saveLessons(lessons)
        }
    }
    
    func saveSession(_ session: LessonSession) async throws {
        var sessions = try await getSessions(for: session.userId)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        let data = try JSONEncoder().encode(sessions)
        UserDefaults.standard.set(data, forKey: "\(sessionsKey)_\(session.userId)")
    }
    
    func getSessions(for userId: String) async throws -> [LessonSession] {
        guard let data = UserDefaults.standard.data(forKey: "\(sessionsKey)_\(userId)") else {
            return []
        }
        return try JSONDecoder().decode([LessonSession].self, from: data)
    }
}
