//
//  Localizable.swift
//  EL-Modras
//
//  Localization keys for the app
//

import Foundation

// MARK: - Localized String Extension
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys
enum L10n {
    // MARK: - General
    static let appName = "app_name".localized
    static let loading = "loading".localized
    static let gettingReady = "getting_ready".localized
    
    // MARK: - Greetings
    static let goodMorning = "good_morning".localized
    static let goodAfternoon = "good_afternoon".localized
    static let goodEvening = "good_evening".localized
    
    // MARK: - Lesson
    static let tapToHear = "tap_to_hear".localized
    static let wordsToLearn = "words_to_learn".localized
    static let recording = "recording".localized
    static let analyzingPronunciation = "analyzing_pronunciation".localized
    static let pressAndSay = "كرر 🎤"
    static let listening = "listening".localized
    static let letsStartLesson = "lets_start_lesson".localized
    static let letMeListen = "let_me_listen".localized
    static let listeningSayWord = "listening_say_word".localized
    static let checkingPronunciation = "checking_pronunciation".localized
    
    // MARK: - Feedback
    static let greatJob = "great_job".localized
    static let goodTry = "good_try".localized
    static let keepGoing = "keep_going".localized
    static let lessonComplete = "lesson_complete".localized
    static let letsLearn = "lets_learn".localized
    static let amazing = "amazing".localized
    
    // MARK: - Home
    static let todayGoal = "today_goal".localized
    static let learnNewWords = "learn_new_words".localized
    static let dayStreak = "day_streak".localized
    static let words = "words".localized
    static let today = "today".localized
    static let categories = "categories".localized
    static let lessons = "lessons".localized
    static let tapTeacher = "tap_teacher".localized
    static let chooseLesson = "choose_lesson".localized
    static let tapAnyLesson = "tap_any_lesson".localized
    
    // MARK: - Categories
    static let greetings = "greetings".localized
    static let numbers = "numbers".localized
    static let colors = "colors".localized
    static let food = "food".localized
    static let animals = "animals".localized
    static let family = "family".localized
    static let camera = "camera".localized
    static let alphabet = "alphabet".localized
    
    // MARK: - Navigation
    static let home = "home".localized
    static let stars = "stars".localized
    
    // MARK: - Stories
    static let interactiveStories = "interactive_stories".localized
    static let newBadge = "new".localized
    static let minutes = "minutes".localized
    static let storyComplete = "story_complete".localized
    static let wordsLearned = "words_learned".localized
    static let backToHome = "back_to_home".localized
    
    // MARK: - Units
    static let of = "of".localized
}
