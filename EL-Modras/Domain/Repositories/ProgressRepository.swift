//
//  ProgressRepository.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

protocol ProgressRepository {
    func getProgress(for userId: String) async throws -> UserProgress?
    func saveProgress(_ progress: UserProgress) async throws
    func updateDailyProgress(_ dailyProgress: DailyProgress, for userId: String) async throws
    func updateCategoryProgress(_ categoryProgress: CategoryProgress, for userId: String) async throws
    func unlockAchievement(_ achievementType: AchievementType, for userId: String) async throws
    func updateStreak(for userId: String) async throws
    func getLeaderboard() async throws -> [UserProgress]
}
