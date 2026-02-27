//
//  Word.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

struct Word: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var english: String
    var arabic: String
    var transliteration: String
    var category: LessonCategory
    var difficulty: WordDifficulty
    var exampleSentence: String?
    var exampleSentenceArabic: String?
    var audioURL: URL?
    var imageURL: URL?
    var emoji: String?  // Emoji/image for visual learning (especially for kids)
    var isMastered: Bool
    var practiceCount: Int
    var lastPracticedAt: Date?
    
    init(
        id: String = UUID().uuidString,
        english: String,
        arabic: String,
        transliteration: String,
        category: LessonCategory,
        difficulty: WordDifficulty = .easy,
        exampleSentence: String? = nil,
        exampleSentenceArabic: String? = nil,
        audioURL: URL? = nil,
        imageURL: URL? = nil,
        emoji: String? = nil,
        isMastered: Bool = false,
        practiceCount: Int = 0,
        lastPracticedAt: Date? = nil
    ) {
        self.id = id
        self.english = english
        self.arabic = arabic
        self.transliteration = transliteration
        self.category = category
        self.difficulty = difficulty
        self.exampleSentence = exampleSentence
        self.exampleSentenceArabic = exampleSentenceArabic
        self.audioURL = audioURL
        self.imageURL = imageURL
        self.emoji = emoji
        self.isMastered = isMastered
        self.practiceCount = practiceCount
        self.lastPracticedAt = lastPracticedAt
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum WordDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

// MARK: - Sample Words for Initial Content
extension Word {
    static let sampleGreetings: [Word] = [
        Word(
            english: "Hello",
            arabic: "مرحبا",
            transliteration: "Marhaba",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Hello, how are you?",
            exampleSentenceArabic: "مرحبا، كيف حالك؟",
            emoji: "👋"
        ),
        Word(
            english: "Peace be upon you",
            arabic: "السلام عليكم",
            transliteration: "Assalamu Alaikum",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Peace be upon you, my friend",
            exampleSentenceArabic: "السلام عليكم يا صديقي",
            emoji: "🙏"
        ),
        Word(
            english: "Good morning",
            arabic: "صباح الخير",
            transliteration: "Sabah al-khair",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Good morning, how did you sleep?",
            exampleSentenceArabic: "صباح الخير، كيف نمت؟",
            emoji: "🌅"
        ),
        Word(
            english: "Good evening",
            arabic: "مساء الخير",
            transliteration: "Masa' al-khair",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Good evening everyone",
            exampleSentenceArabic: "مساء الخير للجميع",
            emoji: "🌆"
        ),
        Word(
            english: "Goodbye",
            arabic: "مع السلامة",
            transliteration: "Ma'a as-salama",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Goodbye, see you tomorrow",
            exampleSentenceArabic: "مع السلامة، أراك غداً",
            emoji: "👋"
        ),
        Word(
            english: "Thank you",
            arabic: "شكراً",
            transliteration: "Shukran",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Thank you very much",
            exampleSentenceArabic: "شكراً جزيلاً",
            emoji: "🙏"
        ),
        Word(
            english: "Please",
            arabic: "من فضلك",
            transliteration: "Min fadlak",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "Please help me",
            exampleSentenceArabic: "من فضلك ساعدني",
            emoji: "🙏"
        ),
        Word(
            english: "You're welcome",
            arabic: "عفواً",
            transliteration: "Afwan",
            category: .greetings,
            difficulty: .easy,
            exampleSentence: "You're welcome, anytime",
            exampleSentenceArabic: "عفواً، في أي وقت",
            emoji: "😊"
        )
    ]
    
    static let sampleNumbers: [Word] = [
        Word(english: "One", arabic: "واحد", transliteration: "Wahid", category: .numbers, difficulty: .easy,
             exampleSentence: "I have one apple", exampleSentenceArabic: "عندي تفاحة واحدة", emoji: "١"),
        Word(english: "Two", arabic: "اثنان", transliteration: "Ithnan", category: .numbers, difficulty: .easy,
             exampleSentence: "I have two hands", exampleSentenceArabic: "عندي يدان اثنتان", emoji: "٢"),
        Word(english: "Three", arabic: "ثلاثة", transliteration: "Thalatha", category: .numbers, difficulty: .easy,
             exampleSentence: "Three cats", exampleSentenceArabic: "ثلاث قطط", emoji: "٣"),
        Word(english: "Four", arabic: "أربعة", transliteration: "Arba'a", category: .numbers, difficulty: .easy,
             exampleSentence: "Four birds", exampleSentenceArabic: "أربعة طيور", emoji: "٤"),
        Word(english: "Five", arabic: "خمسة", transliteration: "Khamsa", category: .numbers, difficulty: .easy,
             exampleSentence: "Five fingers", exampleSentenceArabic: "خمسة أصابع", emoji: "٥"),
        Word(english: "Six", arabic: "ستة", transliteration: "Sitta", category: .numbers, difficulty: .easy,
             exampleSentence: "Six eggs", exampleSentenceArabic: "ست بيضات", emoji: "٦"),
        Word(english: "Seven", arabic: "سبعة", transliteration: "Sab'a", category: .numbers, difficulty: .easy,
             exampleSentence: "Seven days", exampleSentenceArabic: "سبعة أيام", emoji: "٧"),
        Word(english: "Eight", arabic: "ثمانية", transliteration: "Thamaniya", category: .numbers, difficulty: .easy,
             exampleSentence: "Eight stars", exampleSentenceArabic: "ثماني نجوم", emoji: "٨"),
        Word(english: "Nine", arabic: "تسعة", transliteration: "Tis'a", category: .numbers, difficulty: .easy,
             exampleSentence: "Nine books", exampleSentenceArabic: "تسعة كتب", emoji: "٩"),
        Word(english: "Ten", arabic: "عشرة", transliteration: "Ashara", category: .numbers, difficulty: .easy,
             exampleSentence: "Ten friends", exampleSentenceArabic: "عشرة أصدقاء", emoji: "١٠")
    ]
    
    static let sampleFamily: [Word] = [
        Word(english: "Father", arabic: "أب", transliteration: "Ab", category: .family, difficulty: .easy,
             exampleSentence: "My father is kind", exampleSentenceArabic: "أبي طيب", emoji: "👨"),
        Word(english: "Mother", arabic: "أم", transliteration: "Umm", category: .family, difficulty: .easy,
             exampleSentence: "My mother is beautiful", exampleSentenceArabic: "أمي جميلة", emoji: "👩"),
        Word(english: "Brother", arabic: "أخ", transliteration: "Akh", category: .family, difficulty: .easy,
             exampleSentence: "My brother is tall", exampleSentenceArabic: "أخي طويل", emoji: "👦"),
        Word(english: "Sister", arabic: "أخت", transliteration: "Ukht", category: .family, difficulty: .easy,
             exampleSentence: "My sister is smart", exampleSentenceArabic: "أختي ذكية", emoji: "👧"),
        Word(english: "Son", arabic: "ابن", transliteration: "Ibn", category: .family, difficulty: .easy,
             exampleSentence: "The son is playing", exampleSentenceArabic: "الابن يلعب", emoji: "👦"),
        Word(english: "Daughter", arabic: "ابنة", transliteration: "Ibna", category: .family, difficulty: .easy,
             exampleSentence: "The daughter is reading", exampleSentenceArabic: "الابنة تقرأ", emoji: "👧"),
        Word(english: "Grandfather", arabic: "جد", transliteration: "Jadd", category: .family, difficulty: .medium,
             exampleSentence: "My grandfather is wise", exampleSentenceArabic: "جدي حكيم", emoji: "👴"),
        Word(english: "Grandmother", arabic: "جدة", transliteration: "Jadda", category: .family, difficulty: .medium,
             exampleSentence: "My grandmother cooks well", exampleSentenceArabic: "جدتي تطبخ جيداً", emoji: "👵"),
        Word(english: "Baby", arabic: "طفل", transliteration: "Tifl", category: .family, difficulty: .easy,
             exampleSentence: "The baby is sleeping", exampleSentenceArabic: "الطفل نائم", emoji: "👶"),
        Word(english: "Family", arabic: "عائلة", transliteration: "A'ila", category: .family, difficulty: .easy,
             exampleSentence: "I love my family", exampleSentenceArabic: "أحب عائلتي", emoji: "👨‍👩‍👧‍👦")
    ]
    
    // MARK: - Colors
    static let sampleColors: [Word] = [
        Word(english: "Red", arabic: "أحمر", transliteration: "Ahmar", category: .colors, difficulty: .easy,
             exampleSentence: "The apple is red", exampleSentenceArabic: "التفاحة حمراء", emoji: "🔴"),
        Word(english: "Blue", arabic: "أزرق", transliteration: "Azraq", category: .colors, difficulty: .easy,
             exampleSentence: "The sky is blue", exampleSentenceArabic: "السماء زرقاء", emoji: "🔵"),
        Word(english: "Green", arabic: "أخضر", transliteration: "Akhdar", category: .colors, difficulty: .easy,
             exampleSentence: "The grass is green", exampleSentenceArabic: "العشب أخضر", emoji: "🟢"),
        Word(english: "Yellow", arabic: "أصفر", transliteration: "Asfar", category: .colors, difficulty: .easy,
             exampleSentence: "The sun is yellow", exampleSentenceArabic: "الشمس صفراء", emoji: "🟡"),
        Word(english: "Orange", arabic: "برتقالي", transliteration: "Burtuqali", category: .colors, difficulty: .easy,
             exampleSentence: "The orange is orange", exampleSentenceArabic: "البرتقالة برتقالية", emoji: "🟠"),
        Word(english: "Purple", arabic: "بنفسجي", transliteration: "Banafsaji", category: .colors, difficulty: .medium,
             exampleSentence: "The flower is purple", exampleSentenceArabic: "الزهرة بنفسجية", emoji: "🟣"),
        Word(english: "Pink", arabic: "وردي", transliteration: "Wardi", category: .colors, difficulty: .easy,
             exampleSentence: "The dress is pink", exampleSentenceArabic: "الفستان وردي", emoji: "🩷"),
        Word(english: "Black", arabic: "أسود", transliteration: "Aswad", category: .colors, difficulty: .easy,
             exampleSentence: "The cat is black", exampleSentenceArabic: "القطة سوداء", emoji: "⚫"),
        Word(english: "White", arabic: "أبيض", transliteration: "Abyad", category: .colors, difficulty: .easy,
             exampleSentence: "The snow is white", exampleSentenceArabic: "الثلج أبيض", emoji: "⚪"),
        Word(english: "Brown", arabic: "بني", transliteration: "Bunni", category: .colors, difficulty: .easy,
             exampleSentence: "The tree is brown", exampleSentenceArabic: "الشجرة بنية", emoji: "🟤")
    ]
    
    // MARK: - Animals
    static let sampleAnimals: [Word] = [
        Word(english: "Cat", arabic: "قطة", transliteration: "Qitta", category: .animals, difficulty: .easy,
             exampleSentence: "The cat is cute", exampleSentenceArabic: "القطة جميلة", emoji: "🐱"),
        Word(english: "Dog", arabic: "كلب", transliteration: "Kalb", category: .animals, difficulty: .easy,
             exampleSentence: "The dog is big", exampleSentenceArabic: "الكلب كبير", emoji: "🐕"),
        Word(english: "Bird", arabic: "طائر", transliteration: "Ta'ir", category: .animals, difficulty: .easy,
             exampleSentence: "The bird is flying", exampleSentenceArabic: "الطائر يطير", emoji: "🐦"),
        Word(english: "Fish", arabic: "سمكة", transliteration: "Samaka", category: .animals, difficulty: .easy,
             exampleSentence: "The fish swims", exampleSentenceArabic: "السمكة تسبح", emoji: "🐟"),
        Word(english: "Lion", arabic: "أسد", transliteration: "Asad", category: .animals, difficulty: .easy,
             exampleSentence: "The lion is strong", exampleSentenceArabic: "الأسد قوي", emoji: "🦁"),
        Word(english: "Elephant", arabic: "فيل", transliteration: "Fil", category: .animals, difficulty: .easy,
             exampleSentence: "The elephant is big", exampleSentenceArabic: "الفيل كبير", emoji: "🐘"),
        Word(english: "Rabbit", arabic: "أرنب", transliteration: "Arnab", category: .animals, difficulty: .easy,
             exampleSentence: "The rabbit is fast", exampleSentenceArabic: "الأرنب سريع", emoji: "🐰"),
        Word(english: "Horse", arabic: "حصان", transliteration: "Hisan", category: .animals, difficulty: .easy,
             exampleSentence: "The horse runs fast", exampleSentenceArabic: "الحصان يجري بسرعة", emoji: "🐴"),
        Word(english: "Cow", arabic: "بقرة", transliteration: "Baqara", category: .animals, difficulty: .easy,
             exampleSentence: "The cow gives milk", exampleSentenceArabic: "البقرة تعطي الحليب", emoji: "🐄"),
        Word(english: "Chicken", arabic: "دجاجة", transliteration: "Dajaja", category: .animals, difficulty: .easy,
             exampleSentence: "The chicken lays eggs", exampleSentenceArabic: "الدجاجة تبيض", emoji: "🐔")
    ]
    
    // MARK: - Food
    static let sampleFood: [Word] = [
        Word(english: "Apple", arabic: "تفاحة", transliteration: "Tuffaha", category: .food, difficulty: .easy,
             exampleSentence: "I eat an apple", exampleSentenceArabic: "آكل تفاحة", emoji: "🍎"),
        Word(english: "Banana", arabic: "موزة", transliteration: "Mawza", category: .food, difficulty: .easy,
             exampleSentence: "The banana is yellow", exampleSentenceArabic: "الموزة صفراء", emoji: "🍌"),
        Word(english: "Bread", arabic: "خبز", transliteration: "Khubz", category: .food, difficulty: .easy,
             exampleSentence: "I like bread", exampleSentenceArabic: "أحب الخبز", emoji: "🍞"),
        Word(english: "Water", arabic: "ماء", transliteration: "Ma'", category: .food, difficulty: .easy,
             exampleSentence: "I drink water", exampleSentenceArabic: "أشرب الماء", emoji: "💧"),
        Word(english: "Milk", arabic: "حليب", transliteration: "Halib", category: .food, difficulty: .easy,
             exampleSentence: "Milk is healthy", exampleSentenceArabic: "الحليب صحي", emoji: "🥛"),
        Word(english: "Rice", arabic: "أرز", transliteration: "Aruz", category: .food, difficulty: .easy,
             exampleSentence: "I eat rice", exampleSentenceArabic: "آكل الأرز", emoji: "🍚"),
        Word(english: "Meat", arabic: "لحم", transliteration: "Lahm", category: .food, difficulty: .easy,
             exampleSentence: "The meat is delicious", exampleSentenceArabic: "اللحم لذيذ", emoji: "🥩"),
        Word(english: "Chicken", arabic: "دجاج", transliteration: "Dajaj", category: .food, difficulty: .easy,
             exampleSentence: "I like chicken", exampleSentenceArabic: "أحب الدجاج", emoji: "🍗"),
        Word(english: "Orange", arabic: "برتقالة", transliteration: "Burtuqala", category: .food, difficulty: .easy,
             exampleSentence: "The orange is sweet", exampleSentenceArabic: "البرتقالة حلوة", emoji: "🍊"),
        Word(english: "Egg", arabic: "بيضة", transliteration: "Bayda", category: .food, difficulty: .easy,
             exampleSentence: "I eat eggs for breakfast", exampleSentenceArabic: "آكل البيض في الفطور", emoji: "🥚")
    ]
    
    // MARK: - Arabic Alphabet (الحروف العربية)
    static let sampleAlphabet: [Word] = [
        Word(english: "Alif", arabic: "أ", transliteration: "Alif", category: .alphabet, difficulty: .easy,
             exampleSentence: "Alif is the first letter", exampleSentenceArabic: "ألف هو الحرف الأول", emoji: "أ"),
        Word(english: "Ba", arabic: "ب", transliteration: "Ba", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ba has one dot below", exampleSentenceArabic: "باء تحتها نقطة", emoji: "ب"),
        Word(english: "Ta", arabic: "ت", transliteration: "Ta", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ta has two dots above", exampleSentenceArabic: "تاء فوقها نقطتان", emoji: "ت"),
        Word(english: "Tha", arabic: "ث", transliteration: "Tha", category: .alphabet, difficulty: .easy,
             exampleSentence: "Tha has three dots above", exampleSentenceArabic: "ثاء فوقها ثلاث نقاط", emoji: "ث"),
        Word(english: "Jeem", arabic: "ج", transliteration: "Jeem", category: .alphabet, difficulty: .easy,
             exampleSentence: "Jeem is like J", exampleSentenceArabic: "جيم مثل حرف J", emoji: "ج"),
        Word(english: "Ha", arabic: "ح", transliteration: "Ha", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ha is a throat sound", exampleSentenceArabic: "حاء صوت حلقي", emoji: "ح"),
        Word(english: "Kha", arabic: "خ", transliteration: "Kha", category: .alphabet, difficulty: .easy,
             exampleSentence: "Kha has a dot above", exampleSentenceArabic: "خاء فوقها نقطة", emoji: "خ"),
        Word(english: "Dal", arabic: "د", transliteration: "Dal", category: .alphabet, difficulty: .easy,
             exampleSentence: "Dal is like D", exampleSentenceArabic: "دال مثل حرف D", emoji: "د"),
        Word(english: "Thal", arabic: "ذ", transliteration: "Thal", category: .alphabet, difficulty: .easy,
             exampleSentence: "Thal has a dot above", exampleSentenceArabic: "ذال فوقها نقطة", emoji: "ذ"),
        Word(english: "Ra", arabic: "ر", transliteration: "Ra", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ra is like R", exampleSentenceArabic: "راء مثل حرف R", emoji: "ر"),
        Word(english: "Zay", arabic: "ز", transliteration: "Zay", category: .alphabet, difficulty: .easy,
             exampleSentence: "Zay is like Z", exampleSentenceArabic: "زاي مثل حرف Z", emoji: "ز"),
        Word(english: "Seen", arabic: "س", transliteration: "Seen", category: .alphabet, difficulty: .easy,
             exampleSentence: "Seen is like S", exampleSentenceArabic: "سين مثل حرف S", emoji: "س"),
        Word(english: "Sheen", arabic: "ش", transliteration: "Sheen", category: .alphabet, difficulty: .easy,
             exampleSentence: "Sheen is like Sh", exampleSentenceArabic: "شين مثل Sh", emoji: "ش"),
        Word(english: "Sad", arabic: "ص", transliteration: "Sad", category: .alphabet, difficulty: .medium,
             exampleSentence: "Sad is emphatic S", exampleSentenceArabic: "صاد حرف مفخم", emoji: "ص"),
        Word(english: "Dad", arabic: "ض", transliteration: "Dad", category: .alphabet, difficulty: .medium,
             exampleSentence: "Dad is unique to Arabic", exampleSentenceArabic: "ضاد حرف عربي فريد", emoji: "ض"),
        Word(english: "Tah", arabic: "ط", transliteration: "Tah", category: .alphabet, difficulty: .medium,
             exampleSentence: "Tah is emphatic T", exampleSentenceArabic: "طاء حرف مفخم", emoji: "ط"),
        Word(english: "Thah", arabic: "ظ", transliteration: "Thah", category: .alphabet, difficulty: .medium,
             exampleSentence: "Thah is emphatic Th", exampleSentenceArabic: "ظاء حرف مفخم", emoji: "ظ"),
        Word(english: "Ain", arabic: "ع", transliteration: "Ain", category: .alphabet, difficulty: .medium,
             exampleSentence: "Ain is a throat sound", exampleSentenceArabic: "عين صوت حلقي", emoji: "ع"),
        Word(english: "Ghain", arabic: "غ", transliteration: "Ghain", category: .alphabet, difficulty: .medium,
             exampleSentence: "Ghain is like French R", exampleSentenceArabic: "غين مثل R الفرنسية", emoji: "غ"),
        Word(english: "Fa", arabic: "ف", transliteration: "Fa", category: .alphabet, difficulty: .easy,
             exampleSentence: "Fa is like F", exampleSentenceArabic: "فاء مثل حرف F", emoji: "ف"),
        Word(english: "Qaf", arabic: "ق", transliteration: "Qaf", category: .alphabet, difficulty: .medium,
             exampleSentence: "Qaf is a deep K", exampleSentenceArabic: "قاف حرف عميق", emoji: "ق"),
        Word(english: "Kaf", arabic: "ك", transliteration: "Kaf", category: .alphabet, difficulty: .easy,
             exampleSentence: "Kaf is like K", exampleSentenceArabic: "كاف مثل حرف K", emoji: "ك"),
        Word(english: "Lam", arabic: "ل", transliteration: "Lam", category: .alphabet, difficulty: .easy,
             exampleSentence: "Lam is like L", exampleSentenceArabic: "لام مثل حرف L", emoji: "ل"),
        Word(english: "Meem", arabic: "م", transliteration: "Meem", category: .alphabet, difficulty: .easy,
             exampleSentence: "Meem is like M", exampleSentenceArabic: "ميم مثل حرف M", emoji: "م"),
        Word(english: "Noon", arabic: "ن", transliteration: "Noon", category: .alphabet, difficulty: .easy,
             exampleSentence: "Noon is like N", exampleSentenceArabic: "نون مثل حرف N", emoji: "ن"),
        Word(english: "Ha", arabic: "ه", transliteration: "Ha", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ha is like H", exampleSentenceArabic: "هاء مثل حرف H", emoji: "ه"),
        Word(english: "Waw", arabic: "و", transliteration: "Waw", category: .alphabet, difficulty: .easy,
             exampleSentence: "Waw is like W or OO", exampleSentenceArabic: "واو مثل W أو OO", emoji: "و"),
        Word(english: "Ya", arabic: "ي", transliteration: "Ya", category: .alphabet, difficulty: .easy,
             exampleSentence: "Ya is like Y or EE", exampleSentenceArabic: "ياء مثل Y أو EE", emoji: "ي")
    ]
}
