//
//  User.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var email: String
    var nativeLanguage: String
    var arabicLevel: ArabicLevel
    var createdAt: Date
    var lastActiveAt: Date
    var preferences: UserPreferences
    
    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        nativeLanguage: String = "English",
        arabicLevel: ArabicLevel = .beginner,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        preferences: UserPreferences = UserPreferences()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.nativeLanguage = nativeLanguage
        self.arabicLevel = arabicLevel
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.preferences = preferences
    }
}

enum ArabicLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case elementary = "elementary"
    case intermediate = "intermediate"
    case upperIntermediate = "upper_intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner (مبتدئ)"
        case .elementary: return "Elementary (أساسي)"
        case .intermediate: return "Intermediate (متوسط)"
        case .upperIntermediate: return "Upper Intermediate (فوق المتوسط)"
        case .advanced: return "Advanced (متقدم)"
        }
    }
    
    var arabicName: String {
        switch self {
        case .beginner: return "مبتدئ"
        case .elementary: return "أساسي"
        case .intermediate: return "متوسط"
        case .upperIntermediate: return "فوق المتوسط"
        case .advanced: return "متقدم"
        }
    }
}

struct UserPreferences: Codable, Equatable {
    var dialect: ArabicDialect
    var dailyGoalMinutes: Int
    var notificationsEnabled: Bool
    var voiceSpeed: Double
    var hapticFeedback: Bool
    
    init(
        dialect: ArabicDialect = .msa,
        dailyGoalMinutes: Int = 15,
        notificationsEnabled: Bool = true,
        voiceSpeed: Double = 1.0,
        hapticFeedback: Bool = true
    ) {
        self.dialect = dialect
        self.dailyGoalMinutes = dailyGoalMinutes
        self.notificationsEnabled = notificationsEnabled
        self.voiceSpeed = voiceSpeed
        self.hapticFeedback = hapticFeedback
    }
}

enum ArabicDialect: String, Codable, CaseIterable {
    case msa = "msa"           // Modern Standard Arabic
    case egyptian = "egyptian"
    case levantine = "levantine"
    case gulf = "gulf"
    case maghrebi = "maghrebi"
    
    var displayName: String {
        switch self {
        case .msa: return "Modern Standard (الفصحى)"
        case .egyptian: return "Egyptian (مصري)"
        case .levantine: return "Levantine (شامي)"
        case .gulf: return "Gulf (خليجي)"
        case .maghrebi: return "Maghrebi (مغربي)"
        }
    }
}
