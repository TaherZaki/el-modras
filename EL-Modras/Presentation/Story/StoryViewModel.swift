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
    
    // MARK: - Initialization
    init(story: Story, audioService: AudioService, geminiService: GeminiService) {
        self.story = story
        self.audioService = audioService
        self.geminiService = geminiService
        self.currentScene = story.scenes.first!
        self.sceneHistory = [story.scenes.first!.id]
    }
    
    // MARK: - Story Navigation
    
    func startStory() async {
        currentSceneIndex = 0
        currentScene = story.scenes.first!
        sceneHistory = [currentScene.id]
        wordsLearned = []
        starsEarned = 0
        isStoryComplete = false
        
        // Speak the first scene
        await speakCurrentScene()
    }
    
    func speakCurrentScene() async {
        isPlaying = true
        avatarMood = .speaking
        
        // Speak the Arabic narrator text
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
        // Find next scene in order (not by ID, since some scenes are branches)
        let currentId = currentScene.id
        
        // Try to find the next sequential scene
        if let currentIndex = story.scenes.firstIndex(where: { $0.id == currentId }) {
            // Look for next scene that isn't a branch of current
            for i in (currentIndex + 1)..<story.scenes.count {
                let nextScene = story.scenes[i]
                // Skip branch scenes (scene_3_market, scene_3_garden, etc.)
                if !nextScene.id.contains("_market") &&
                   !nextScene.id.contains("_garden") &&
                   !nextScene.id.contains("_home") ||
                   sceneHistory.contains(where: { nextScene.id.hasPrefix($0.replacingOccurrences(of: "_market", with: "").replacingOccurrences(of: "_garden", with: "").replacingOccurrences(of: "_home", with: "")) }) {
                    
                    // Check if this is the logical next scene
                    let nextNumber = nextScene.sceneNumber
                    let currentNumber = currentScene.sceneNumber
                    
                    if nextNumber > currentNumber {
                        currentScene = nextScene
                        sceneHistory.append(nextScene.id)
                        showChoices = false
                        pronunciationScore = nil
                        return
                    }
                }
            }
        }
        
        // If no next scene found, story is complete
        isStoryComplete = true
        avatarMood = .celebrating
    }
    
    // MARK: - Pronunciation
    
    func startRecording() async {
        guard currentScene.requiresPronunciation else { return }
        
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
            
            // Check pronunciation with Gemini
            let response = try await geminiService.analyzePronunciation(
                audioData: audioData,
                expectedText: wordToLearn.arabic
            )
            
            // Parse score from response
            let score = parsePronunciationScore(from: response, word: wordToLearn)
            pronunciationScore = score
            
            isProcessing = false
            
            // Handle result
            if score.score >= 0.6 {
                // Good pronunciation!
                avatarMood = .celebrating
                wordsLearned.append(wordToLearn)
                starsEarned += 1
                
                // Celebrate and move to next scene
                isPlaying = true
                await audioService.speakNaturalArabic("برافو عليك يا بطل! 🌟", using: geminiService)
                isPlaying = false
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Move to next scene
                goToNextScene()
                
                if !isStoryComplete {
                    await speakCurrentScene()
                }
            } else {
                // Need to try again
                avatarMood = .encouraging
                isPlaying = true
                await audioService.speakNaturalArabic("حاول تاني! قول: \(wordToLearn.arabic)", using: geminiService)
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
}
