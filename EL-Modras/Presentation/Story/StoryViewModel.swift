//
//  StoryViewModel.swift
//  EL-Modras
//
//  ViewModel for Interactive Stories
//

import Foundation
import Combine

@MainActor
final class StoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var story: Story
    @Published var currentScene: StoryScene
    @Published var currentSceneIndex: Int = 0
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var showChoices = false
    @Published var pronunciationScore: PronunciationScore?
    @Published var wordsLearned: [Word] = []
    @Published var starsEarned: Int = 0
    @Published var isStoryComplete = false
    @Published var error: String?
    @Published var avatarMood: TeacherMood = .idle
    
    // Scene history for navigation
    private var sceneHistory: [String] = []
    
    // MARK: - Dependencies
    private let audioService: AudioService
    private let geminiService: GeminiService
    private let trackWordLearnedUseCase: TrackWordLearnedUseCase?
    
    // MARK: - Initialization
    init(story: Story, audioService: AudioService, geminiService: GeminiService, trackWordLearnedUseCase: TrackWordLearnedUseCase? = nil) {
        self.story = story
        self.audioService = audioService
        self.geminiService = geminiService
        self.trackWordLearnedUseCase = trackWordLearnedUseCase
        self.currentScene = story.scenes.first!
        self.sceneHistory = [story.scenes.first!.id]
    }
    
    // MARK: - Story Navigation
    
    func startStory() async {
        // Stop any audio from home screen
        audioService.stopSpeaking()
        
        currentSceneIndex = 0
        currentScene = story.scenes.first!
        sceneHistory = [currentScene.id]
        wordsLearned = []
        starsEarned = 0
        isStoryComplete = false
        
        // Save activity for session memory
        SessionMemory.shared.saveActivity(
            type: .story,
            id: story.id,
            title: story.titleArabic,
            sceneIndex: 0,
            totalScenes: story.scenes.count
        )
        
        // Start preloading audio in background for instant playback
        Task.detached { [weak self] in
            guard let self = self else { return }
            await AudioPreloader.shared.preloadStory(self.story, using: self.geminiService)
        }
        
        // Speak the first scene
        await speakCurrentScene()
    }
    
    func speakCurrentScene() async {
        isPlaying = true
        avatarMood = .speaking
        
        // speakNaturalArabic handles: cache check → Gemini TTS → retry → fallback
        // All with the unified Orus voice
        await audioService.speakNaturalArabic(currentScene.narratorTextArabic, using: geminiService)
        
        isPlaying = false
        
        // After speaking, show choices if any, or wait for pronunciation
        if currentScene.choices != nil && !currentScene.choices!.isEmpty {
            showChoices = true
            avatarMood = .thinking
        } else if currentScene.requiresPronunciation {
            avatarMood = .listening
        } else {
            avatarMood = .idle
        }
    }
    
    func selectChoice(_ choice: StoryChoice) async {
        showChoices = false
        avatarMood = .happy
        
        // If choice has a word, speak it and add to learned words
        if let word = choice.word {
            isPlaying = true
            await audioService.speakNaturalArabic(word.arabic, using: geminiService)
            isPlaying = false
            
            wordsLearned.append(word)
            starsEarned += 1
            
            // Track progress
            await trackWordLearned(word)
        }
        
        // Navigate to next scene
        if let nextSceneId = choice.nextSceneId {
            goToScene(withId: nextSceneId)
        } else {
            goToNextScene()
        }
        
        // Small delay before speaking next scene
        try? await Task.sleep(nanoseconds: 500_000_000)
        await speakCurrentScene()
    }
    
    func goToScene(withId sceneId: String) {
        if let scene = story.scenes.first(where: { $0.id == sceneId }) {
            currentScene = scene
            sceneHistory.append(sceneId)
            showChoices = false
            pronunciationScore = nil
        }
    }
    
    func goToNextScene() {
        let currentNumber = currentScene.sceneNumber
        
        // Find next scene with higher scene number that we haven't visited
        // OR if we're in a branch scene, find the next main scene
        for (index, scene) in story.scenes.enumerated() {
            // Skip scenes we've already visited
            if sceneHistory.contains(scene.id) {
                continue
            }
            
            // Find next scene number (could be branch or main)
            if scene.sceneNumber > currentNumber {
                currentScene = scene
                currentSceneIndex = index
                sceneHistory.append(scene.id)
                showChoices = false
                pronunciationScore = nil
                print("📖 Moving to scene: \(scene.id) (number: \(scene.sceneNumber))")
                
                // Update session memory with progress
                SessionMemory.shared.saveActivity(
                    type: .story,
                    id: story.id,
                    title: story.titleArabic,
                    sceneIndex: index,
                    totalScenes: story.scenes.count
                )
                
                // Preload upcoming scenes in background (lazy loading)
                Task.detached { [weak self] in
                    guard let self = self else { return }
                    await AudioPreloader.shared.preloadUpcomingScenes(
                        story: self.story,
                        currentIndex: index,
                        using: self.geminiService
                    )
                }
                return
            }
        }
        
        // If no next scene found, story is complete
        isStoryComplete = true
        avatarMood = .celebrating
        SessionMemory.shared.clearLastActivity()
        print("🎉 Story complete!")
    }
    
    // MARK: - Pronunciation
    
    func startRecording() async {
        guard currentScene.requiresPronunciation else { return }
        
        // Stop any ongoing speech immediately
        if isPlaying {
            audioService.stopSpeaking()
            isPlaying = false
        }
        
        do {
            try await audioService.startRecording()
            isRecording = true
            avatarMood = .listening
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopRecordingAndCheck() async {
        guard isRecording else { return }
        
        do {
            let audioData = try await audioService.stopRecording()
            isRecording = false
            isProcessing = true
            avatarMood = .thinking
            
            guard let wordToLearn = currentScene.wordToLearn else {
                isProcessing = false
                return
            }
            
            // Try LOCAL speech recognition first (instant!)
            let localRecognizer = LocalSpeechRecognizer.shared
            var score: PronunciationScore
            
            do {
                let recognizedText = try await localRecognizer.recognize(audioData: audioData)
                print("🎤 Story - Recognized locally: \(recognizedText)")
                
                // Compare with expected word (instant!)
                let matchResult = localRecognizer.compareWords(recognized: recognizedText, expected: wordToLearn.arabic)
                
                score = PronunciationScore(
                    wordId: wordToLearn.id,
                    score: matchResult.score,
                    feedback: matchResult.isMatch ? "ممتاز!" : "حاول تاني",
                    timestamp: Date()
                )
            } catch {
                print("⚠️ Local recognition failed, falling back to Gemini: \(error)")
                
                // Fallback to Gemini (slower but more accurate)
                let response = try await geminiService.analyzePronunciation(
                    audioData: audioData,
                    expectedText: wordToLearn.arabic
                )
                score = parsePronunciationScore(from: response, word: wordToLearn)
            }
            
            pronunciationScore = score
            isProcessing = false
            
            // Handle result
            if score.score >= 0.6 {
                // Good pronunciation!
                avatarMood = .celebrating
                wordsLearned.append(wordToLearn)
                starsEarned += 1
                
                // Track progress
                await trackWordLearned(wordToLearn)
                
                // Celebrate and move to next scene
                isPlaying = true
                let celebrationText = "برافو عليك يا بطل! 🌟"
                await audioService.speakNaturalArabic(celebrationText, using: geminiService)
                isPlaying = false
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Move to next scene
                goToNextScene()
                
                if !isStoryComplete {
                    await speakCurrentScene()
                }
            } else {
                // Need to try again (use cached audio!)
                avatarMood = .encouraging
                isPlaying = true
                let tryAgainText = "حاول تاني!"
                await audioService.speakNaturalArabic(tryAgainText, using: geminiService)
                
                // Small pause
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                // Say the word
                await audioService.speakNaturalArabic(wordToLearn.arabic, using: geminiService)
                
                // Small pause
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                // Then say "كرر ورايا"
                let repeatPrompt = "كرر ورايا"
                await audioService.speakNaturalArabic(repeatPrompt, using: geminiService)
                
                isPlaying = false
                avatarMood = .listening
            }
            
        } catch {
            self.error = error.localizedDescription
            isRecording = false
            isProcessing = false
            avatarMood = .idle
        }
    }
    
    private func parsePronunciationScore(from response: GeminiPronunciationResponse, word: Word) -> PronunciationScore {
        return PronunciationScore(
            wordId: word.id,
            score: response.score,
            feedback: response.feedback,
            timestamp: Date()
        )
    }
    
    // MARK: - Helpers
    
    func replayScene() async {
        await speakCurrentScene()
    }
    
    func skipScene() {
        goToNextScene()
        
        if !isStoryComplete {
            Task {
                await speakCurrentScene()
            }
        }
    }
    
    var progress: Double {
        let totalMainScenes = story.scenes.filter {
            !$0.id.contains("_market") &&
            !$0.id.contains("_garden") &&
            !$0.id.contains("_home")
        }.count
        let currentNumber = currentScene.sceneNumber
        return Double(currentNumber) / Double(max(totalMainScenes, 1))
    }
    
    // MARK: - Progress Tracking
    
    private func trackWordLearned(_ word: Word) async {
        guard let useCase = trackWordLearnedUseCase else { return }
        
        do {
            try await useCase.execute(
                word: word,
                category: word.category,
                userId: "current_user"
            )
            print("✅ Story: Tracked word learned: \(word.arabic)")
        } catch {
            print("❌ Story: Failed to track word: \(error)")
        }
    }
}
