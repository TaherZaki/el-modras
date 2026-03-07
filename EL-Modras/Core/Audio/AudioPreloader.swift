//
//  AudioPreloader.swift
//  EL-Modras
//
//  Smart audio preloader - minimizes API calls, maximizes cache hits
//  Only preloads what's immediately needed, rest is on-demand + cached forever
//

import Foundation

// MARK: - Audio Preloader
final class AudioPreloader {
    
    static let shared = AudioPreloader()
    
    private let cacheManager = AudioCacheManager.shared
    private var preloadTask: Task<Void, Never>?
    private var isPreloading = false
    private var commonResponsesLoaded = false
    
    // ONLY the most essential responses (5 instead of 24)
    // Everything else gets cached on first use and stays forever
    private let essentialResponses: [(text: String, type: AudioType)] = [
        ("برافو عليك يا بطل!", .response),
        ("حاول تاني!", .response),
        ("كرر ورايا", .instruction),
    ]
    
    private init() {}
    
    // MARK: - Preload Lesson (SMART - minimal API calls)
    
    /// Preloads only the essential audio for a lesson
    /// ~11 API calls instead of ~70: just the words + 3 essential responses
    func preloadLesson(_ lesson: Lesson, using geminiService: GeminiService) async {
        guard !isPreloading else { return }
        isPreloading = true
        
        let uncachedWords = lesson.words.filter { !cacheManager.hasAudio(for: $0.arabic, type: .word) }
        print("🔄 Preloading lesson: \(lesson.titleArabic) (\(uncachedWords.count) uncached words)")
        
        // Only preload the WORD itself (1 request per uncached word)
        // Sentences, repeat prompts etc. get cached on first use
        for word in uncachedWords {
            if let audioData = try? await geminiService.getNaturalSpeech(text: word.arabic) {
                cacheManager.saveAudio(audioData, for: word.arabic, type: .word)
            }
        }
        
        // Preload essential responses (only once ever, then cached)
        await preloadEssentialResponses(using: geminiService)
        
        isPreloading = false
        print("✅ Lesson preloaded: \(lesson.titleArabic)")
    }
    
    // MARK: - Preload Essential Responses (only 3)
    
    private func preloadEssentialResponses(using geminiService: GeminiService) async {
        guard !commonResponsesLoaded else { return }
        
        for response in essentialResponses {
            if !cacheManager.hasAudio(for: response.text, type: response.type) {
                if let audioData = try? await geminiService.getNaturalSpeech(text: response.text) {
                    cacheManager.saveAudio(audioData, for: response.text, type: response.type)
                }
            }
        }
        commonResponsesLoaded = true
    }
    
    // MARK: - Preload Story (SMART - only first 2 scenes)
    
    /// Preloads only the first 2 scenes of a story
    /// Rest gets preloaded as user progresses
    func preloadStory(_ story: Story, using geminiService: GeminiService) async {
        print("🔄 Preloading story: \(story.titleArabic)")
        
        // Only preload first 2 scenes
        let scenesToPreload = Array(story.scenes.prefix(2))
        
        for scene in scenesToPreload {
            await preloadScene(scene, using: geminiService)
        }
        
        // Preload essential responses
        await preloadEssentialResponses(using: geminiService)
        
        print("✅ Story preloaded (first 2 scenes): \(story.titleArabic)")
    }
    
    /// Preload a single scene (narrator text + word only)
    func preloadScene(_ scene: StoryScene, using geminiService: GeminiService) async {
        // Preload narrator text
        if !cacheManager.hasAudio(for: scene.narratorTextArabic, type: .instruction) {
            if let audioData = try? await geminiService.getNaturalSpeech(text: scene.narratorTextArabic) {
                cacheManager.saveAudio(audioData, for: scene.narratorTextArabic, type: .instruction)
            }
        }
        
        // Preload word to learn (just the word itself)
        if let word = scene.wordToLearn {
            if !cacheManager.hasAudio(for: word.arabic, type: .word) {
                if let audioData = try? await geminiService.getNaturalSpeech(text: word.arabic) {
                    cacheManager.saveAudio(audioData, for: word.arabic, type: .word)
                }
            }
        }
    }
    
    /// Call this when user moves to next scene - preloads upcoming scenes
    func preloadUpcomingScenes(story: Story, currentIndex: Int, using geminiService: GeminiService) async {
        // Preload next 2 scenes ahead
        let startIdx = currentIndex + 1
        let endIdx = min(currentIndex + 2, story.scenes.count - 1)
        guard startIdx <= endIdx, startIdx < story.scenes.count else { return }
        
        for i in startIdx...endIdx {
            await preloadScene(story.scenes[i], using: geminiService)
        }
    }
    
    // MARK: - Cancel Preloading
    
    func cancelPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
        isPreloading = false
    }
    
    // MARK: - Helper Methods
    
    /// Generates a simple sentence for a word (Egyptian Arabic)
    private func generateSimpleSentence(for word: Word) -> String {
        switch word.category {
        case .animals:
            return "شوف! ده \(word.arabic)"
        case .food:
            return "أنا بحب \(word.arabic) أوي"
        case .colors:
            return "اللون \(word.arabic) حلو أوي"
        case .numbers:
            return "ده رقم \(word.arabic)"
        case .family:
            return "ده \(word.arabic) بتاعي"
        case .greetings:
            return "لما نقابل حد نقول \(word.arabic)"
        case .alphabet:
            return "ده حرف \(word.arabic)"
        case .bodyParts:
            return "ده \(word.arabic) بتاعي"
        case .household:
            return "ده \(word.arabic) في البيت"
        case .weather:
            return "الجو \(word.arabic) النهاردة"
        case .travel:
            return "أنا رايح \(word.arabic)"
        case .shopping:
            return "أنا عايز أشتري \(word.arabic)"
        default:
            return "ده \(word.arabic)"
        }
    }
    
    /// Checks if a lesson is preloaded
    func isLessonPreloaded(_ lesson: Lesson) -> Bool {
        for word in lesson.words {
            if !cacheManager.hasAudio(for: word.arabic, type: .word) {
                return false
            }
        }
        return true
    }
    
    /// Gets preload progress for a lesson
    func getPreloadProgress(for lesson: Lesson) -> Double {
        var cached = 0
        let total = lesson.words.count
        
        for word in lesson.words {
            if cacheManager.hasAudio(for: word.arabic, type: .word) {
                cached += 1
            }
        }
        
        return total > 0 ? Double(cached) / Double(total) : 0
    }
}
