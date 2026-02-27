//
//  ProgressViewModel.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var progress: UserProgress?
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }
    
    // MARK: - Dependencies
    private let progressRepository: ProgressRepository
    private let userRepository: UserRepository
    
    // MARK: - Computed Properties
    var totalWordsLearned: Int {
        progress?.totalWordsLearned ?? 0
    }
    
    var totalLessonsCompleted: Int {
        progress?.lessonsCompleted ?? 0
    }
    
    var totalMinutesPracticed: Int {
        progress?.totalMinutesPracticed ?? 0
    }
    
    var currentStreak: Int {
        progress?.currentStreak ?? 0
    }
    
    var longestStreak: Int {
        progress?.longestStreak ?? 0
    }
    
    var averageAccuracy: Double {
        progress?.averageAccuracy ?? 0
    }
    
    var unlockedAchievements: [Achievement] {
        progress?.achievements.filter { $0.isUnlocked } ?? []
    }
    
    var lockedAchievements: [Achievement] {
        progress?.achievements.filter { !$0.isUnlocked } ?? []
    }
    
    var categoryProgressList: [CategoryProgress] {
        progress?.categoryProgress ?? []
    }
    
    var recentActivity: [DailyProgress] {
        let days: Int
        switch selectedTimeRange {
        case .week: days = 7
        case .month: days = 30
        case .all: days = 365
        }
        
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return (progress?.dailyProgress ?? [])
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }
    
    var weeklyMinutes: Int {
        progress?.weeklyMinutes ?? 0
    }
    
    // MARK: - Initialization
    init(progressRepository: ProgressRepository, userRepository: UserRepository) {
        self.progressRepository = progressRepository
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    func loadProgress() async {
        isLoading = true
        error = nil
        
        do {
            user = try await userRepository.getCurrentUser()
            guard let userId = user?.id else {
                isLoading = false
                return
            }
            
            progress = try await progressRepository.getProgress(for: userId)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func selectTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
    }
}
