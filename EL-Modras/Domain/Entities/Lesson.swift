//
//  Lesson.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

struct Lesson: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var titleArabic: String
    var description: String
    var category: LessonCategory
    var level: ArabicLevel
    var durationMinutes: Int
    var words: [Word]
    var objectives: [String]
    var isCompleted: Bool
    var progress: Double
    
    init(
        id: String = UUID().uuidString,
        title: String,
        titleArabic: String,
        description: String,
        category: LessonCategory,
        level: ArabicLevel,
        durationMinutes: Int = 10,
        words: [Word] = [],
        objectives: [String] = [],
        isCompleted: Bool = false,
        progress: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.titleArabic = titleArabic
        self.description = description
        self.category = category
        self.level = level
        self.durationMinutes = durationMinutes
        self.words = words
        self.objectives = objectives
        self.isCompleted = isCompleted
        self.progress = progress
    }
}

enum LessonCategory: String, Codable, CaseIterable {
    case greetings = "greetings"
    case numbers = "numbers"
    case family = "family"
    case food = "food"
    case travel = "travel"
    case shopping = "shopping"
    case weather = "weather"
    case colors = "colors"
    case bodyParts = "body_parts"
    case animals = "animals"
    case household = "household"
    case workplace = "workplace"
    case conversation = "conversation"
    case grammar = "grammar"
    case alphabet = "alphabet"  // الحروف العربية
    
    var displayName: String {
        switch self {
        case .greetings: return "Greetings"
        case .numbers: return "Numbers"
        case .family: return "Family"
        case .food: return "Food & Drink"
        case .travel: return "Travel"
        case .shopping: return "Shopping"
        case .weather: return "Weather"
        case .colors: return "Colors"
        case .bodyParts: return "Body Parts"
        case .animals: return "Animals"
        case .household: return "Household"
        case .workplace: return "Workplace"
        case .conversation: return "Conversation"
        case .grammar: return "Grammar"
        case .alphabet: return "Arabic Alphabet"
        }
    }
    
    var arabicName: String {
        switch self {
        case .greetings: return "التحيات"
        case .numbers: return "الأرقام"
        case .family: return "العائلة"
        case .food: return "الطعام"
        case .travel: return "السفر"
        case .shopping: return "التسوق"
        case .weather: return "الطقس"
        case .colors: return "الألوان"
        case .bodyParts: return "أجزاء الجسم"
        case .animals: return "الحيوانات"
        case .household: return "المنزل"
        case .workplace: return "العمل"
        case .conversation: return "المحادثة"
        case .grammar: return "القواعد"
        case .alphabet: return "الحروف العربية"
        }
    }
    
    var icon: String {
        switch self {
        case .greetings: return "hand.wave.fill"
        case .numbers: return "number.circle.fill"
        case .family: return "person.3.fill"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .shopping: return "cart.fill"
        case .weather: return "cloud.sun.fill"
        case .colors: return "paintpalette.fill"
        case .bodyParts: return "figure.stand"
        case .animals: return "hare.fill"
        case .household: return "house.fill"
        case .workplace: return "briefcase.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .grammar: return "textformat.abc"
        case .alphabet: return "character.book.closed.fill.ar"
        }
    }
}

struct LessonSession: Identifiable, Codable {
    let id: String
    let lessonId: String
    let userId: String
    var startedAt: Date
    var endedAt: Date?
    var messages: [ConversationMessage]
    var wordsLearned: [String]
    var pronunciationScores: [PronunciationScore]
    
    init(
        id: String = UUID().uuidString,
        lessonId: String,
        userId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        messages: [ConversationMessage] = [],
        wordsLearned: [String] = [],
        pronunciationScores: [PronunciationScore] = []
    ) {
        self.id = id
        self.lessonId = lessonId
        self.userId = userId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.messages = messages
        self.wordsLearned = wordsLearned
        self.pronunciationScores = pronunciationScores
    }
    
    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

struct ConversationMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: MessageRole
    let content: String
    let contentArabic: String?
    let timestamp: Date
    let audioURL: URL?
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        contentArabic: String? = nil,
        timestamp: Date = Date(),
        audioURL: URL? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.contentArabic = contentArabic
        self.timestamp = timestamp
        self.audioURL = audioURL
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

struct PronunciationScore: Identifiable, Codable, Equatable {
    let id: String
    let wordId: String
    let score: Double // 0.0 to 1.0
    let feedback: String
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        wordId: String,
        score: Double,
        feedback: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.wordId = wordId
        self.score = score
        self.feedback = feedback
        self.timestamp = timestamp
    }
}

// MARK: - Sample Lessons
extension Lesson {
    static let sampleLessons: [Lesson] = [
        // Greetings Lesson
        Lesson(
            id: "lesson_greetings",
            title: "Greetings",
            titleArabic: "التحيات",
            description: "Learn basic Arabic greetings",
            category: .greetings,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleGreetings,
            objectives: ["Say hello and goodbye", "Greet people politely", "Thank someone"]
        ),
        
        // Numbers Lesson
        Lesson(
            id: "lesson_numbers",
            title: "Numbers",
            titleArabic: "الأرقام",
            description: "Learn numbers 1-10 in Arabic",
            category: .numbers,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleNumbers,
            objectives: ["Count from 1 to 10", "Recognize Arabic numerals", "Use numbers in sentences"]
        ),
        
        // Colors Lesson
        Lesson(
            id: "lesson_colors",
            title: "Colors",
            titleArabic: "الألوان",
            description: "Learn colors in Arabic",
            category: .colors,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleColors,
            objectives: ["Name basic colors", "Describe objects by color", "Use colors in sentences"]
        ),
        
        // Animals Lesson
        Lesson(
            id: "lesson_animals",
            title: "Animals",
            titleArabic: "الحيوانات",
            description: "Learn animal names in Arabic",
            category: .animals,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleAnimals,
            objectives: ["Name common animals", "Describe animals", "Talk about pets"]
        ),
        
        // Food Lesson
        Lesson(
            id: "lesson_food",
            title: "Food & Drinks",
            titleArabic: "الطعام والشراب",
            description: "Learn food and drink words in Arabic",
            category: .food,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleFood,
            objectives: ["Name common foods", "Order food", "Talk about meals"]
        ),
        
        // Family Lesson
        Lesson(
            id: "lesson_family",
            title: "Family",
            titleArabic: "العائلة",
            description: "Learn family member names in Arabic",
            category: .family,
            level: .beginner,
            durationMinutes: 10,
            words: Word.sampleFamily,
            objectives: ["Name family members", "Introduce your family", "Talk about relatives"]
        ),
        
        // Arabic Alphabet Lesson
        Lesson(
            id: "lesson_alphabet",
            title: "Arabic Alphabet",
            titleArabic: "الحروف العربية",
            description: "Learn the Arabic alphabet from Alif to Ya",
            category: .alphabet,
            level: .beginner,
            durationMinutes: 15,
            words: Word.sampleAlphabet,
            objectives: ["Learn all 28 Arabic letters", "Pronounce each letter correctly", "Recognize letter shapes"]
        )
    ]
}
