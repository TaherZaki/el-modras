//
//  AppConfig.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

enum AppConfig {
    // MARK: - Backend Configuration
    static var backendURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "https://el-modras-backend-508801329902.us-central1.run.app"
        #else
        return "https://el-modras-backend-508801329902.us-central1.run.app"
        #endif
    }
    
    // MARK: - API Keys
    static var geminiAPIKey: String {
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ??
              Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String else {
            // Fallback for development - in production, use environment variables
            return "AIzaSyBe-ZTUBG3tBg5ycC7nymQvV9UINdP_f9M"
        }
        return key
    }
    
    // MARK: - Firebase Configuration
    static var firebaseProjectId: String {
        return ProcessInfo.processInfo.environment["FIREBASE_PROJECT_ID"] ?? "el-modras"
    }
    
    // MARK: - Feature Flags
    static var isVoiceEnabled: Bool {
        return true
    }
    
    static var isCameraEnabled: Bool {
        return true
    }
    
    static var isOfflineModeEnabled: Bool {
        return false
    }
    
    // MARK: - Audio Configuration
    static var audioSampleRate: Double {
        return 16000.0
    }
    
    static var audioBufferSize: Int {
        return 4096
    }
    
    // MARK: - Timeouts
    static var sessionTimeout: TimeInterval {
        return 300 // 5 minutes
    }
    
    static var networkTimeout: TimeInterval {
        return 30
    }
}
