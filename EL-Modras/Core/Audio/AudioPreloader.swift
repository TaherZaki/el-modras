//
//  AudioPreloader.swift
//  EL-Modras
//
//  Preloads audio for lessons to enable instant playback
//

import Foundation

// MARK: - Audio Preloader
final class AudioPreloader {
    
    static let shared = AudioPreloader()
    
    private let cacheManager = AudioCacheManager.shared
    private var preloadTask: Task<Void, Never>?
    private var isPreloading = false
    
    // Common responses that should always be cached
    private let commonResponses: [(text: String, type: AudioType)] = [
        ("برافو عليك يا بطل!", .response),
        ("شاطر أوي!", .response),
        ("ممتاز!", .response),
        ("حاول تاني!", .response),
        ("مش سامعك كويس، قول تاني", .response),
        ("يلا نجرب مرة تانية", .response),
        ("أحسنت!", .response),
        ("رائع!", .response),
        ("صح!", .response),
        ("أيوه كده!", .response),
        ("كمل كده!", .response),
        ("أهلاً يا بطل!", .instruction),
        ("يلا نبدأ الدرس!", .instruction),
        ("قول معايا", .instruction),
        ("كرر ورايا", .instruction),
        ("اسمع كويس", .instruction),
    ]
    
    private init() {}
    
    // MARK: - Preload Lesson
    
    /// Preloads all audio for a lesson
    func preloadLesson(_ lesson: Lesson, using geminiService: GeminiService) async {
        guard !isPreloading else { return }
        isPreloading = true
        
        print("🔄 Preloading audio for lesson: \(lesson.titleArabic)")
        
        // Preload words
        for word in lesson.words {
            await preloadWord(word, using: geminiService)
        }
        
        // Preload common responses
        await preloadCommonResponses(using: geminiService)
        
        isPreloading = false
        print("✅ Finished preloading lesson: \(lesson.titleArabic)")
    }
    
    // MARK: - Preload Word
    
    /// Preloads audio for a single word (word + sentence)
    func preloadWord(_ word: Word, using geminiService: GeminiService) async {
        // Preload word pronunciation
        if !cacheManager.hasAudio(for: word.arabic, type: .word) {
            if let audioData = try? await geminiService.getNaturalSpeech(text: word.arabic) {
                cacheManager.saveAudio(audioData, for: word.arabic, type: .word)
            }
        }
        
        // Preload example sentence if available
        if let sentence = word.exampleSentence, !cacheManager.hasAudio(for: sentence, type: .sentence) {
            if let audioData = try? await geminiService.getNaturalSpeech(text: sentence) {
                cacheManager.saveAudio(audioData, for: sentence, type: .sentence)
            }
        }
        
        // Generate and preload a simple sentence for this word
        let simplesentence = generateSimpleSentence(for: word)
        if !cacheManager.hasAudio(for: simplesentence, type: .sentence) {
            if let audioData = try? await geminiService.getNaturalSpeech(text: simplesentence) {
                cacheManager.saveAudio(audioData, for: simplesentence, type: .sentence)
            }
        }
    }
    
    // MARK: - Preload Common Responses
    
    /// Preloads common responses (bravo, try again, etc.)
    func preloadCommonResponses(using geminiService: GeminiService) async {
        for response in commonResponses {
            if !cacheManager.hasAudio(for: response.text, type: response.type) {
                if let audioData = try? await geminiService.getNaturalSpeech(text: response.text) {
                    cacheManager.saveAudio(audioData, for: response.text, type: response.type)
                }
            }
        }
    }
    
    // MARK: - Preload Story
    
    /// Preloads all audio for an interactive story
    func preloadStory(_ story: Story, using geminiService: GeminiService) async {
        print("🔄 Preloading audio for story: \(story.titleArabic)")
        
        for scene in story.scenes {
            // Preload narrator text
            if !cacheManager.hasAudio(for: scene.narratorTextArabic, type: .instruction) {
                if let audioData = try? await geminiService.getNaturalSpeech(text: scene.narratorTextArabic) {
                    cacheManager.saveAudio(audioData, for: scene.narratorTextArabic, type: .instruction)
                }
            }
            
            // Preload word to learn
            if let word = scene.wordToLearn {
                await preloadWord(word, using: geminiService)
            }
            
            // Preload choices
            if let choices = scene.choices {
                for choice in choices {
                    if !cacheManager.hasAudio(for: choice.textArabic, type: .word) {
                        if let audioData = try? await geminiService.getNaturalSpeech(text: choice.textArabic) {
                            cacheManager.saveAudio(audioData, for: choice.textArabic, type: .word)
                        }
                    }
                }
            }
        }
        
        // Preload common responses
        await preloadCommonResponses(using: geminiService)
        
        print("✅ Finished preloading story: \(story.titleArabic)")
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
