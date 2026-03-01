//
//  LocalSpeechRecognizer.swift
//  EL-Modras
//
//  Local speech recognition using iOS Speech framework
//  For instant pronunciation checking without network delay
//

import Foundation
import Speech
import AVFoundation

// MARK: - Local Speech Recognizer
final class LocalSpeechRecognizer: NSObject {
    
    static let shared = LocalSpeechRecognizer()
    
    // Speech recognizer for Arabic
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Callback for real-time results
    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Authorization status
    private(set) var isAuthorized = false
    
    private override init() {
        super.init()
        setupRecognizer()
    }
    
    // MARK: - Setup
    
    private func setupRecognizer() {
        // Use Arabic (Egypt) for better dialect recognition
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-EG"))
        
        // Fallback to standard Arabic
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar"))
        }
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    print("❌ Speech recognition not authorized")
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - Start Recognition
    
    func startRecognition() throws {
        // Cancel any existing task
        stopRecognition()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        guard isAuthorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // For on-device recognition (iOS 13+)
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false // Use server for better Arabic support
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                self?.onError?(error)
                return
            }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                if result.isFinal {
                    self?.onFinalResult?(text)
                    self?.stopRecognition()
                } else {
                    self?.onPartialResult?(text)
                }
            }
        }
        
        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎤 Local speech recognition started")
    }
    
    // MARK: - Stop Recognition
    
    func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        print("🛑 Local speech recognition stopped")
    }
    
    // MARK: - Recognize Audio Data
    
    /// Recognize speech from audio data (for pre-recorded audio)
    func recognize(audioData: Data) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        // Save audio data to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.wav")
        try audioData.write(to: tempURL)
        
        // Create recognition request from URL
        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - Compare Words
    
    /// Compares recognized text with expected word
    func compareWords(recognized: String, expected: String) -> SpeechMatchResult {
        let normalizedRecognized = normalizeArabic(recognized)
        let normalizedExpected = normalizeArabic(expected)
        
        // Exact match
        if normalizedRecognized == normalizedExpected {
            return SpeechMatchResult(score: 1.0, isMatch: true, matchType: .exact)
        }
        
        // Contains match
        if normalizedRecognized.contains(normalizedExpected) || normalizedExpected.contains(normalizedRecognized) {
            return SpeechMatchResult(score: 0.85, isMatch: true, matchType: .contains)
        }
        
        // Similarity check
        let similarity = calculateSimilarity(normalizedRecognized, normalizedExpected)
        
        if similarity >= 0.7 {
            return SpeechMatchResult(score: similarity, isMatch: true, matchType: .similar)
        }
        
        return SpeechMatchResult(score: similarity, isMatch: false, matchType: .noMatch)
    }
    
    // MARK: - Keyword Detection
    
    /// Detects keywords in recognized text
    func detectKeywords(in text: String) -> DetectedKeyword? {
        let normalized = normalizeArabic(text)
        
        // Repeat keywords
        let repeatKeywords = ["كرر", "تاني", "قولها", "مرة تانية", "اعيد", "أعد"]
        for keyword in repeatKeywords {
            if normalized.contains(keyword) {
                return .repeat
            }
        }
        
        // Sentence keywords
        let sentenceKeywords = ["جملة", "مثال", "في جملة", "استخدمها"]
        for keyword in sentenceKeywords {
            if normalized.contains(keyword) {
                return .sentence
            }
        }
        
        // Meaning keywords
        let meaningKeywords = ["معنى", "يعني", "بالإنجليزي", "ايه", "إيه"]
        for keyword in meaningKeywords {
            if normalized.contains(keyword) {
                return .meaning
            }
        }
        
        // Next keywords
        let nextKeywords = ["التالي", "بعدين", "خلاص", "كفاية", "اللي بعده"]
        for keyword in nextKeywords {
            if normalized.contains(keyword) {
                return .next
            }
        }
        
        // Help keywords
        let helpKeywords = ["صعب", "مش فاهم", "ساعدني", "مش قادر"]
        for keyword in helpKeywords {
            if normalized.contains(keyword) {
                return .help
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes Arabic text for comparison
    private func normalizeArabic(_ text: String) -> String {
        var normalized = text.lowercased()
        
        // Remove diacritics (tashkeel)
        let diacritics = ["ً", "ٌ", "ٍ", "َ", "ُ", "ِ", "ّ", "ْ"]
        for d in diacritics {
            normalized = normalized.replacingOccurrences(of: d, with: "")
        }
        
        // Normalize alef variations
        normalized = normalized.replacingOccurrences(of: "أ", with: "ا")
        normalized = normalized.replacingOccurrences(of: "إ", with: "ا")
        normalized = normalized.replacingOccurrences(of: "آ", with: "ا")
        
        // Normalize taa marbuta
        normalized = normalized.replacingOccurrences(of: "ة", with: "ه")
        
        // Normalize yaa
        normalized = normalized.replacingOccurrences(of: "ى", with: "ي")
        
        // Remove extra spaces
        normalized = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        
        return normalized.trimmingCharacters(in: .whitespaces)
    }
    
    /// Calculates similarity between two strings (0.0 to 1.0)
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1.isEmpty || s2.isEmpty {
            return 0
        }
        
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        let longerLength = Double(longer.count)
        
        if longerLength == 0 {
            return 1.0
        }
        
        let distance = levenshteinDistance(longer, shorter)
        return (longerLength - Double(distance)) / longerLength
    }
    
    /// Calculates Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
}

// MARK: - Supporting Types

enum SpeechRecognitionError: Error, LocalizedError {
    case recognizerNotAvailable
    case notAuthorized
    case requestCreationFailed
    case recognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .recognitionFailed:
            return "Speech recognition failed"
        }
    }
}

struct SpeechMatchResult {
    let score: Double  // 0.0 to 1.0
    let isMatch: Bool
    let matchType: MatchType
    
    enum MatchType {
        case exact      // Perfect match
        case contains   // One contains the other
        case similar    // Similar enough (>70%)
        case noMatch    // Not a match
    }
}

enum DetectedKeyword {
    case `repeat`   // "كرر", "تاني"
    case sentence   // "جملة", "مثال"
    case meaning    // "معنى", "يعني"
    case next       // "التالي", "خلاص"
    case help       // "صعب", "مش فاهم"
}
