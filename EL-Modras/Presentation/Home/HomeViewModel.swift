//
//  HomeViewModel.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var recommendedLessons: [Lesson] = []
    @Published var allLessons: [Lesson] = []
    @Published var progress: UserProgress?
    @Published var selectedCategory: LessonCategory?
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Dependencies
    private let getRecommendedLessonsUseCase: GetRecommendedLessonsUseCase
    private let getAllLessonsUseCase: GetAllLessonsUseCase
    private let progressRepository: ProgressRepository
    private let userRepository: UserRepository
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "صباح الخير" // Good morning
        case 12..<17: return "مساء الخير" // Good afternoon
        case 17..<21: return "مساء الخير" // Good evening
        default: return "مساء الخير" // Good night
        }
    }
    
    var greetingEnglish: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good evening"
        }
    }
    
    var streakText: String {
        guard let streak = progress?.currentStreak, streak > 0 else {
            return "Start your streak today!"
        }
        return "\(streak) day\(streak > 1 ? "s" : "") streak 🔥"
    }
    
    var wordsLearnedText: String {
        let count = progress?.totalWordsLearned ?? 0
        return "\(count) word\(count != 1 ? "s" : "") learned"
    }
    
    var filteredLessons: [Lesson] {
        guard let category = selectedCategory else {
            return allLessons
        }
        return allLessons.filter { $0.category == category }
    }
    
    // Alias for convenience
    var lessons: [Lesson] {
        allLessons
    }
    
    // MARK: - Initialization
    init(
        getRecommendedLessonsUseCase: GetRecommendedLessonsUseCase,
        getAllLessonsUseCase: GetAllLessonsUseCase,
        progressRepository: ProgressRepository,
        userRepository: UserRepository
    ) {
        self.getRecommendedLessonsUseCase = getRecommendedLessonsUseCase
        self.getAllLessonsUseCase = getAllLessonsUseCase
        self.progressRepository = progressRepository
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        error = nil
        
        print("📚 Starting to load data...")
        
        do {
            // Load user
            user = try await userRepository.getCurrentUser()
            
            // If no user, create a default one
            if user == nil {
                let newUser = User(name: "Learner", email: "")
                try await userRepository.saveUser(newUser)
                user = newUser
            }
            
            guard let userId = user?.id else {
                print("❌ No user ID found")
                return
            }
            
            print("👤 User ID: \(userId)")
            
            // Load progress
            progress = try await progressRepository.getProgress(for: userId)
            
            // Load lessons
            print("📖 Loading lessons...")
            async let recommendedTask = getRecommendedLessonsUseCase.execute(userId: userId)
            async let allTask = getAllLessonsUseCase.execute()
            
            let (recommended, all) = try await (recommendedTask, allTask)
            recommendedLessons = recommended
            allLessons = all
            
            print("✅ Loaded \(allLessons.count) lessons")
            for lesson in allLessons {
                print("   - \(lesson.title): \(lesson.words.count) words")
            }
            
        } catch {
            self.error = error.localizedDescription
            print("❌ Error loading data: \(error)")
        }
        
        isLoading = false
    }
    
    func selectCategory(_ category: LessonCategory?) {
        selectedCategory = category
    }
    
    func refreshProgress() async {
        guard let userId = user?.id else { return }
        progress = try? await progressRepository.getProgress(for: userId)
    }
}
