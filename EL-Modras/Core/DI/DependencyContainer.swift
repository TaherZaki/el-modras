//
//  DependencyContainer.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    // MARK: - Services
    lazy var geminiService: GeminiService = GeminiServiceImpl()
    lazy var audioService: AudioService = AudioServiceImpl()
    
    // MARK: - Repositories
    lazy var userRepository: UserRepository = UserRepositoryImpl(
        remoteDataSource: UserRemoteDataSource(),
        localDataSource: UserLocalDataSource()
    )
    
    lazy var lessonRepository: LessonRepository = LessonRepositoryImpl(
        remoteDataSource: LessonRemoteDataSource(),
        localDataSource: LessonLocalDataSource()
    )
    
    lazy var wordRepository: WordRepository = WordRepositoryImpl(
        remoteDataSource: WordRemoteDataSource(),
        localDataSource: WordLocalDataSource()
    )
    
    lazy var progressRepository: ProgressRepository = ProgressRepositoryImpl(
        remoteDataSource: ProgressRemoteDataSource(),
        localDataSource: ProgressLocalDataSource()
    )
    
    // MARK: - Use Cases
    
    // Lesson Use Cases
    lazy var getAllLessonsUseCase: GetAllLessonsUseCase = GetAllLessonsUseCaseImpl(
        repository: lessonRepository
    )
    
    lazy var getLessonsByCategoryUseCase: GetLessonsByCategoryUseCase = GetLessonsByCategoryUseCaseImpl(
        repository: lessonRepository
    )
    
    lazy var getRecommendedLessonsUseCase: GetRecommendedLessonsUseCase = GetRecommendedLessonsUseCaseImpl(
        repository: lessonRepository
    )
    
    lazy var startLessonSessionUseCase: StartLessonSessionUseCase = StartLessonSessionUseCaseImpl(
        repository: lessonRepository
    )
    
    lazy var endLessonSessionUseCase: EndLessonSessionUseCase = EndLessonSessionUseCaseImpl(
        repository: lessonRepository,
        progressRepository: progressRepository
    )
    
    lazy var completeLessonUseCase: CompleteLessonUseCase = CompleteLessonUseCaseImpl(
        lessonRepository: lessonRepository,
        progressRepository: progressRepository
    )
    
    lazy var trackWordLearnedUseCase: TrackWordLearnedUseCase = TrackWordLearnedUseCaseImpl(
        progressRepository: progressRepository
    )
    
    lazy var trackLessonCompletedUseCase: TrackLessonCompletedUseCase = TrackLessonCompletedUseCaseImpl(
        progressRepository: progressRepository,
        lessonRepository: lessonRepository
    )
    
    // Vocabulary Use Cases
    lazy var recognizeObjectUseCase: RecognizeObjectUseCase = RecognizeObjectUseCaseImpl(
        geminiService: geminiService,
        wordRepository: wordRepository
    )
    
    lazy var learnWordUseCase: LearnWordUseCase = LearnWordUseCaseImpl(
        wordRepository: wordRepository,
        progressRepository: progressRepository
    )
    
    lazy var masterWordUseCase: MasterWordUseCase = MasterWordUseCaseImpl(
        wordRepository: wordRepository,
        progressRepository: progressRepository
    )
    
    lazy var searchWordsUseCase: SearchWordsUseCase = SearchWordsUseCaseImpl(
        repository: wordRepository
    )
    
    lazy var getWordsByCategoryUseCase: GetWordsByCategoryUseCase = GetWordsByCategoryUseCaseImpl(
        repository: wordRepository
    )
    
    // Conversation Use Cases
    lazy var startConversationUseCase: StartConversationUseCase = StartConversationUseCaseImpl(
        geminiService: geminiService
    )
    
    lazy var sendVoiceMessageUseCase: SendVoiceMessageUseCase = SendVoiceMessageUseCaseImpl(
        geminiService: geminiService
    )
    
    lazy var endConversationUseCase: EndConversationUseCase = EndConversationUseCaseImpl(
        geminiService: geminiService,
        progressRepository: progressRepository
    )
    
    lazy var getPronunciationFeedbackUseCase: GetPronunciationFeedbackUseCase = GetPronunciationFeedbackUseCaseImpl(
        geminiService: geminiService
    )
    
    // MARK: - View Models
    
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getRecommendedLessonsUseCase: getRecommendedLessonsUseCase,
            getAllLessonsUseCase: getAllLessonsUseCase,
            progressRepository: progressRepository,
            userRepository: userRepository
        )
    }
    
    func makeLessonViewModel(lesson: Lesson) -> LessonViewModel {
        LessonViewModel(
            lesson: lesson,
            startConversationUseCase: startConversationUseCase,
            sendVoiceMessageUseCase: sendVoiceMessageUseCase,
            endConversationUseCase: endConversationUseCase,
            getPronunciationFeedbackUseCase: getPronunciationFeedbackUseCase,
            trackWordLearnedUseCase: trackWordLearnedUseCase,
            trackLessonCompletedUseCase: trackLessonCompletedUseCase,
            audioService: audioService,
            geminiService: geminiService
        )
    }
    
    func makeCameraVocabViewModel() -> CameraVocabViewModel {
        CameraVocabViewModel(
            recognizeObjectUseCase: recognizeObjectUseCase,
            learnWordUseCase: learnWordUseCase,
            audioService: audioService,
            geminiService: geminiService
        )
    }
    
    func makeProgressViewModel() -> ProgressViewModel {
        ProgressViewModel(
            progressRepository: progressRepository,
            userRepository: userRepository
        )
    }
    
    private init() {}
}

// MARK: - Environment Key
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
