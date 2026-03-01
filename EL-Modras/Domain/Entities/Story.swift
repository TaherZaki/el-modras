//
//  Story.swift
//  EL-Modras
//
//  Interactive Story Model for Kids
//

import Foundation

// MARK: - Story Model
struct Story: Identifiable {
    let id: String
    let title: String
    let titleArabic: String
    let description: String
    let coverEmoji: String
    let scenes: [StoryScene]
    let targetWords: [Word]  // Words to learn in this story
    let difficulty: ArabicLevel
    let estimatedMinutes: Int
    
    var totalScenes: Int { scenes.count }
}

// MARK: - Story Scene
struct StoryScene: Identifiable {
    let id: String
    let sceneNumber: Int
    let backgroundEmoji: String
    let characterEmoji: String
    let narratorText: String       // What the teacher says
    let narratorTextArabic: String // Arabic version
    let choices: [StoryChoice]?    // Optional choices for interactivity
    let wordToLearn: Word?         // Word to practice in this scene
    let requiresPronunciation: Bool // Does the child need to say the word?
}

// MARK: - Story Choice
struct StoryChoice: Identifiable {
    let id: String
    let emoji: String
    let textArabic: String
    let textEnglish: String
    let nextSceneId: String?  // Which scene to go to (nil = next scene)
    let word: Word?           // Word associated with this choice
}

// MARK: - Sample Stories
extension Story {
    
    // قصة ميمي القطة - تعلم الحيوانات والطعام
    static let mimiTheCat = Story(
        id: "mimi_the_cat",
        title: "Mimi the Cat",
        titleArabic: "ميمي القطة",
        description: "Join Mimi on her adventure to find food!",
        coverEmoji: "🐱",
        scenes: [
            // Scene 1: Introduction
            StoryScene(
                id: "scene_1",
                sceneNumber: 1,
                backgroundEmoji: "🏠",
                characterEmoji: "🐱",
                narratorText: "This is Mimi the cat. Say: Cat!",
                narratorTextArabic: "دي ميمي القطة! قطة، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "cat_story",
                    english: "Cat",
                    arabic: "قطة",
                    transliteration: "Qitta",
                    category: .animals,
                    emoji: "🐱"
                ),
                requiresPronunciation: true
            ),
            
            // Scene 2: Mimi is hungry - Choose where to go
            StoryScene(
                id: "scene_2",
                sceneNumber: 2,
                backgroundEmoji: "🏠",
                characterEmoji: "🐱",
                narratorText: "Mimi is hungry! Where should she go?",
                narratorTextArabic: "ميمي جعانة! تروح فين؟",
                choices: [
                    StoryChoice(
                        id: "choice_market",
                        emoji: "🏪",
                        textArabic: "السوق",
                        textEnglish: "Market",
                        nextSceneId: "scene_3_market",
                        word: Word(
                            id: "market_story",
                            english: "Market",
                            arabic: "سوق",
                            transliteration: "Souq",
                            category: .shopping,
                            emoji: "🏪"
                        )
                    ),
                    StoryChoice(
                        id: "choice_garden",
                        emoji: "🌳",
                        textArabic: "الحديقة",
                        textEnglish: "Garden",
                        nextSceneId: "scene_3_garden",
                        word: Word(
                            id: "garden_story",
                            english: "Garden",
                            arabic: "حديقة",
                            transliteration: "Hadiqa",
                            category: .household,
                            emoji: "🌳"
                        )
                    ),
                    StoryChoice(
                        id: "choice_home",
                        emoji: "🏡",
                        textArabic: "البيت",
                        textEnglish: "Home",
                        nextSceneId: "scene_3_home",
                        word: Word(
                            id: "home_story",
                            english: "Home",
                            arabic: "بيت",
                            transliteration: "Bait",
                            category: .household,
                            emoji: "🏡"
                        )
                    )
                ],
                wordToLearn: nil,
                requiresPronunciation: false
            ),
            
            // Scene 3A: Market - Find fish
            StoryScene(
                id: "scene_3_market",
                sceneNumber: 3,
                backgroundEmoji: "🏪",
                characterEmoji: "🐱",
                narratorText: "Mimi went to the market and found a fish! Say: Fish!",
                narratorTextArabic: "ميمي راحت السوق ولقت سمكة! سمكة، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "fish_story",
                    english: "Fish",
                    arabic: "سمكة",
                    transliteration: "Samaka",
                    category: .animals,
                    emoji: "🐟"
                ),
                requiresPronunciation: true
            ),
            
            // Scene 3B: Garden - Find bird
            StoryScene(
                id: "scene_3_garden",
                sceneNumber: 3,
                backgroundEmoji: "🌳",
                characterEmoji: "🐱",
                narratorText: "Mimi went to the garden and saw a bird! Say: Bird!",
                narratorTextArabic: "ميمي راحت الحديقة وشافت طائر! طائر، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "bird_story",
                    english: "Bird",
                    arabic: "طائر",
                    transliteration: "Ta'ir",
                    category: .animals,
                    emoji: "🐦"
                ),
                requiresPronunciation: true
            ),
            
            // Scene 3C: Home - Find milk
            StoryScene(
                id: "scene_3_home",
                sceneNumber: 3,
                backgroundEmoji: "🏡",
                characterEmoji: "🐱",
                narratorText: "Mimi went home and found milk! Say: Milk!",
                narratorTextArabic: "ميمي راحت البيت ولقت حليب! حليب، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "milk_story",
                    english: "Milk",
                    arabic: "حليب",
                    transliteration: "Haleeb",
                    category: .food,
                    emoji: "🥛"
                ),
                requiresPronunciation: true
            ),
            
            // Scene 4: Mimi is happy - What does she say?
            StoryScene(
                id: "scene_4",
                sceneNumber: 4,
                backgroundEmoji: "🌟",
                characterEmoji: "🐱",
                narratorText: "Mimi is happy now! What does she say?",
                narratorTextArabic: "ميمي مبسوطة دلوقتي! بتقول إيه؟",
                choices: [
                    StoryChoice(
                        id: "choice_thanks",
                        emoji: "🙏",
                        textArabic: "شكراً",
                        textEnglish: "Thank you",
                        nextSceneId: "scene_5",
                        word: Word(
                            id: "thanks_story",
                            english: "Thank you",
                            arabic: "شكراً",
                            transliteration: "Shukran",
                            category: .greetings,
                            emoji: "🙏"
                        )
                    ),
                    StoryChoice(
                        id: "choice_yay",
                        emoji: "🎉",
                        textArabic: "يااااي",
                        textEnglish: "Yay!",
                        nextSceneId: "scene_5",
                        word: nil
                    )
                ],
                wordToLearn: nil,
                requiresPronunciation: false
            ),
            
            // Scene 5: The End
            StoryScene(
                id: "scene_5",
                sceneNumber: 5,
                backgroundEmoji: "🌙",
                characterEmoji: "🐱",
                narratorText: "Mimi says goodbye! Say: Goodbye!",
                narratorTextArabic: "ميمي بتقول مع السلامة! مع السلامة، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "goodbye_story",
                    english: "Goodbye",
                    arabic: "مع السلامة",
                    transliteration: "Ma'a Salama",
                    category: .greetings,
                    emoji: "👋"
                ),
                requiresPronunciation: true
            )
        ],
        targetWords: Word.sampleAnimals.prefix(3).map { $0 },
        difficulty: .beginner,
        estimatedMinutes: 5
    )
    
    // قصة أحمد في السوق - تعلم الطعام والأرقام
    static let ahmedAtMarket = Story(
        id: "ahmed_at_market",
        title: "Ahmed at the Market",
        titleArabic: "أحمد في السوق",
        description: "Help Ahmed buy fruits at the market!",
        coverEmoji: "🧒",
        scenes: [
            StoryScene(
                id: "ahmed_1",
                sceneNumber: 1,
                backgroundEmoji: "🏪",
                characterEmoji: "🧒",
                narratorText: "This is Ahmed. He's going to the market!",
                narratorTextArabic: "ده أحمد! رايح السوق! سوق، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "market_ahmed",
                    english: "Market",
                    arabic: "سوق",
                    transliteration: "Souq",
                    category: .shopping,
                    emoji: "🏪"
                ),
                requiresPronunciation: true
            ),
            StoryScene(
                id: "ahmed_2",
                sceneNumber: 2,
                backgroundEmoji: "🏪",
                characterEmoji: "🧒",
                narratorText: "What should Ahmed buy?",
                narratorTextArabic: "أحمد يشتري إيه؟",
                choices: [
                    StoryChoice(
                        id: "apple_choice",
                        emoji: "🍎",
                        textArabic: "تفاحة",
                        textEnglish: "Apple",
                        nextSceneId: "ahmed_3",
                        word: Word(
                            id: "apple_ahmed",
                            english: "Apple",
                            arabic: "تفاحة",
                            transliteration: "Tuffaha",
                            category: .food,
                            emoji: "🍎"
                        )
                    ),
                    StoryChoice(
                        id: "banana_choice",
                        emoji: "🍌",
                        textArabic: "موزة",
                        textEnglish: "Banana",
                        nextSceneId: "ahmed_3",
                        word: Word(
                            id: "banana_ahmed",
                            english: "Banana",
                            arabic: "موزة",
                            transliteration: "Mawza",
                            category: .food,
                            emoji: "🍌"
                        )
                    ),
                    StoryChoice(
                        id: "orange_choice",
                        emoji: "🍊",
                        textArabic: "برتقالة",
                        textEnglish: "Orange",
                        nextSceneId: "ahmed_3",
                        word: Word(
                            id: "orange_ahmed",
                            english: "Orange",
                            arabic: "برتقالة",
                            transliteration: "Burtuqala",
                            category: .food,
                            emoji: "🍊"
                        )
                    )
                ],
                wordToLearn: nil,
                requiresPronunciation: false
            ),
            StoryScene(
                id: "ahmed_3",
                sceneNumber: 3,
                backgroundEmoji: "🏪",
                characterEmoji: "🧒",
                narratorText: "Ahmed bought it! Now he says thank you!",
                narratorTextArabic: "أحمد اشتراها! دلوقتي بيقول شكراً! شكراً، كرر ورايا!",
                choices: nil,
                wordToLearn: Word(
                    id: "thanks_ahmed",
                    english: "Thank you",
                    arabic: "شكراً",
                    transliteration: "Shukran",
                    category: .greetings,
                    emoji: "🙏"
                ),
                requiresPronunciation: true
            )
        ],
        targetWords: Word.sampleFood.prefix(3).map { $0 },
        difficulty: .beginner,
        estimatedMinutes: 4
    )
    
    static let allStories: [Story] = [mimiTheCat, ahmedAtMarket]
}
