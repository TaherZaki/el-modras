//
//  LessonRepository.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

protocol LessonRepository {
    func getAllLessons() async throws -> [Lesson]
    func getLesson(by id: String) async throws -> Lesson?
    func getLessons(for category: LessonCategory) async throws -> [Lesson]
    func getLessons(for level: ArabicLevel) async throws -> [Lesson]
    func getRecommendedLessons(for userId: String) async throws -> [Lesson]
    func updateLessonProgress(_ lessonId: String, progress: Double) async throws
    func markLessonCompleted(_ lessonId: String) async throws
    
    // Session management
    func startSession(lessonId: String, userId: String) async throws -> LessonSession
    func endSession(_ session: LessonSession) async throws
    func getSessions(for userId: String) async throws -> [LessonSession]
}
