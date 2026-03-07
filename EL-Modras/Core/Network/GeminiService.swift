//
//  GeminiService.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

// MARK: - Gemini Service Protocol
protocol GeminiService {
    // Live Session Management
    func startLiveSession() async throws
    func endLiveSession() async throws
    func interruptSession(sessionId: String) async throws
    var isSessionActive: Bool { get }
    
    // Audio Communication
    func sendAudioMessage(audioData: Data) async throws -> GeminiAudioResponse
    func sendAudioMessageWithContext(audioData: Data, context: String) async throws -> GeminiAudioResponse
    func streamAudio(_ audioData: Data) async throws
    
    // Vision
    func recognizeObject(imageData: Data) async throws -> GeminiVisionResponse
    
    // Pronunciation
    func analyzePronunciation(audioData: Data, expectedText: String) async throws -> GeminiPronunciationResponse
    
    // Text Chat
    func sendTextMessage(_ text: String) async throws -> GeminiTextResponse
    func chat(message: String, context: String) async throws -> String
    
    // Natural Text-to-Speech
    func getNaturalSpeech(text: String) async throws -> Data?
    
    // Image Generation (for interactive stories)
    func generateStoryImage(prompt: String) async throws -> Data?
}

// MARK: - Response Models
struct GeminiAudioResponse {
    let text: String
    let arabicText: String?
    let audioData: Data?
    let audioURL: URL?
}

struct GeminiVisionResponse {
    let englishName: String
    let arabicName: String
    let transliteration: String
    let confidence: Double
    let description: String?
}

struct GeminiPronunciationResponse {
    let score: Double // 0.0 to 1.0
    let feedback: String
    let suggestions: [String]
}

struct GeminiTextResponse {
    let text: String
    let arabicText: String?
}

struct GeminiImageResponse {
    let imageData: Data
}

// MARK: - Gemini Service Implementation
final class GeminiServiceImpl: GeminiService {
    private let baseURL: String
    private let apiKey: String
    private var sessionId: String?
    private var webSocketTask: URLSessionWebSocketTask?
    
    private(set) var isSessionActive: Bool = false
    
    init(baseURL: String = AppConfig.backendURL, apiKey: String? = AppConfig.geminiAPIKey) {
        self.baseURL = baseURL
        self.apiKey = apiKey ?? "" // API Key not needed for iOS - backend handles Gemini calls
    }
    
    // MARK: - Live Session Management
    
    func startLiveSession() async throws {
        guard !isSessionActive else { return }
        
        let url = URL(string: "\(baseURL)/api/v1/session/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.sessionStartFailed
        }
        
        let sessionResponse = try JSONDecoder().decode(SessionStartResponse.self, from: data)
        self.sessionId = sessionResponse.sessionId
        self.isSessionActive = true
        
        // Establish WebSocket connection for real-time audio
        try await establishWebSocketConnection(sessionId: sessionResponse.sessionId)
    }
    
    func endLiveSession() async throws {
        guard isSessionActive, let sessionId = sessionId else { return }
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        
        let url = URL(string: "\(baseURL)/api/v1/session/\(sessionId)/end")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.sessionEndFailed
        }
        
        self.sessionId = nil
        self.isSessionActive = false
    }
    
    func interruptSession(sessionId: String) async throws {
        // Implementation for interrupting a session
        let url = URL(string: "\(baseURL)/api/v1/session/\(sessionId)/interrupt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.sessionInterruptFailed
        }
        
        // Optionally, handle any response data
    }
    
    // MARK: - Audio Communication
    
    func sendAudioMessage(audioData: Data) async throws -> GeminiAudioResponse {
        guard isSessionActive, let sessionId = sessionId else {
            throw GeminiError.noActiveSession
        }
        
        let url = URL(string: "\(baseURL)/api/v1/session/\(sessionId)/audio")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // Add audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.audioSendFailed
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.networkError(errorMessage)
        }
        
        let audioResponse = try JSONDecoder().decode(AudioResponseDTO.self, from: data)
        
        return GeminiAudioResponse(
            text: audioResponse.text,
            arabicText: audioResponse.arabicText,
            audioData: audioResponse.audioBase64.flatMap { Data(base64Encoded: $0) },
            audioURL: audioResponse.audioURL.flatMap { URL(string: $0) }
        )
    }
    
    func sendAudioMessageWithContext(audioData: Data, context: String) async throws -> GeminiAudioResponse {
        let url = URL(string: "\(baseURL)/api/v1/session/audio-with-context")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // Add context part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"context\"\r\n\r\n".data(using: .utf8)!)
        body.append(context.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.audioSendFailed
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.networkError(errorMessage)
        }
        
        let audioResponse = try JSONDecoder().decode(AudioResponseDTO.self, from: data)
        
        return GeminiAudioResponse(
            text: audioResponse.text,
            arabicText: audioResponse.arabicText,
            audioData: audioResponse.audioBase64.flatMap { Data(base64Encoded: $0) },
            audioURL: audioResponse.audioURL.flatMap { URL(string: $0) }
        )
    }
    
    func streamAudio(_ audioData: Data) async throws {
        guard let webSocketTask = webSocketTask else {
            throw GeminiError.noWebSocketConnection
        }
        
        let message = URLSessionWebSocketTask.Message.data(audioData)
        try await webSocketTask.send(message)
    }
    
    // MARK: - Vision
    
    func recognizeObject(imageData: Data) async throws -> GeminiVisionResponse {
        let url = URL(string: "\(baseURL)/api/v1/vision/recognize")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // Add image file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.visionRecognitionFailed
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.networkError(errorMessage)
        }
        
        let visionResponse = try JSONDecoder().decode(VisionResponseDTO.self, from: data)
        
        return GeminiVisionResponse(
            englishName: visionResponse.englishName,
            arabicName: visionResponse.arabicName,
            transliteration: visionResponse.transliteration,
            confidence: visionResponse.confidence,
            description: visionResponse.description
        )
    }
    
    // MARK: - Pronunciation
    
    func analyzePronunciation(audioData: Data, expectedText: String) async throws -> GeminiPronunciationResponse {
        let url = URL(string: "\(baseURL)/api/v1/pronunciation/analyze-json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = PronunciationRequestDTO(
            audioBase64: audioData.base64EncodedString(),
            expectedText: expectedText
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.pronunciationAnalysisFailed
        }
        
        let pronunciationResponse = try JSONDecoder().decode(PronunciationResponseDTO.self, from: data)
        
        return GeminiPronunciationResponse(
            score: pronunciationResponse.score,
            feedback: pronunciationResponse.feedback,
            suggestions: pronunciationResponse.suggestions
        )
    }
    
    // MARK: - Text (Fallback)
    
    func sendTextMessage(_ text: String) async throws -> GeminiTextResponse {
        let url = URL(string: "\(baseURL)/api/v1/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = TextRequestDTO(text: text, sessionId: sessionId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.textSendFailed
        }
        
        let textResponse = try JSONDecoder().decode(TextResponseDTO.self, from: data)
        
        return GeminiTextResponse(
            text: textResponse.text,
            arabicText: textResponse.arabicText
        )
    }
    
    func chat(message: String, context: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/v1/chat/message")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = ChatRequestDTO(message: message, context: context, sessionId: sessionId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.chatSendFailed
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponseDTO.self, from: data)
        
        return chatResponse.reply
    }
    
    // MARK: - Natural Text-to-Speech
    
    func getNaturalSpeech(text: String) async throws -> Data? {
        let url = URL(string: "\(baseURL)/api/v1/tts/speak")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // 15 second timeout for TTS
        
        let body = TTSRequestDTO(text: text, voiceStyle: "friendly_teacher")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.networkError("TTS failed with status \(statusCode)")
        }
        
        let ttsResponse = try JSONDecoder().decode(TTSResponseDTO.self, from: data)
        
        // If successful, decode and return audio data
        if ttsResponse.success, let audioBase64 = ttsResponse.audioBase64 {
            if let audioData = Data(base64Encoded: audioBase64), !audioData.isEmpty {
                return audioData
            }
            throw GeminiError.networkError("TTS returned empty audio data")
        }
        
        throw GeminiError.networkError("TTS returned success=false")
    }
    
    // MARK: - Image Generation
    
    func generateStoryImage(prompt: String) async throws -> Data? {
        let url = URL(string: "\(baseURL)/api/v1/image/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = ImageGenerationRequestDTO(prompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.imageGenerationFailed
        }
        
        let imageResponse = try JSONDecoder().decode(ImageGenerationResponseDTO.self, from: data)
        
        return imageResponse.imageBase64.flatMap { Data(base64Encoded: $0) }
    }
    
    // MARK: - Private Methods
    
    private func establishWebSocketConnection(sessionId: String) async throws {
        let wsURL = URL(string: "\(baseURL.replacingOccurrences(of: "https", with: "wss"))/ws/\(sessionId)")!
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        Task {
            await receiveWebSocketMessages()
        }
    }
    
    private func receiveWebSocketMessages() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            while isSessionActive {
                let message = try await webSocketTask.receive()
                switch message {
                case .data(let data):
                    // Handle incoming audio data
                    await handleIncomingAudio(data)
                case .string(let text):
                    // Handle incoming text message
                    await handleIncomingText(text)
                @unknown default:
                    break
                }
            }
        } catch {
            print("WebSocket error: \(error)")
        }
    }
    
    private func handleIncomingAudio(_ data: Data) async {
        // Post notification for audio player
        NotificationCenter.default.post(
            name: .geminiAudioReceived,
            object: nil,
            userInfo: ["audioData": data]
        )
    }
    
    private func handleIncomingText(_ text: String) async {
        // Post notification for UI update
        NotificationCenter.default.post(
            name: .geminiTextReceived,
            object: nil,
            userInfo: ["text": text]
        )
    }
}

// MARK: - Errors
enum GeminiError: Error, LocalizedError {
    case sessionStartFailed
    case sessionEndFailed
    case sessionInterruptFailed
    case noActiveSession
    case noWebSocketConnection
    case audioSendFailed
    case visionRecognitionFailed
    case pronunciationAnalysisFailed
    case textSendFailed
    case chatSendFailed
    case networkError(String)
    case imageGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionStartFailed:
            return "Failed to start Gemini session. Please check your internet connection and try again."
        case .sessionEndFailed:
            return "Failed to end Gemini session"
        case .sessionInterruptFailed:
            return "Failed to interrupt Gemini session"
        case .noActiveSession:
            return "No active session. Please start a new lesson."
        case .noWebSocketConnection:
            return "Lost connection to server. Please try again."
        case .audioSendFailed:
            return "Failed to send audio. Please check your microphone and try again."
        case .visionRecognitionFailed:
            return "Failed to recognize object. Please try with a clearer image."
        case .networkError(let message):
            return "Network error: \(message)"
        case .pronunciationAnalysisFailed:
            return "Failed to analyze pronunciation. Please try speaking more clearly."
        case .textSendFailed:
            return "Failed to send message. Please check your connection and try again."
        case .chatSendFailed:
            return "Failed to send chat message. Please try again."
        case .imageGenerationFailed:
            return "Failed to generate image. Please try again."
        }
    }
}

// MARK: - DTOs
private struct SessionStartResponse: Codable {
    let sessionId: String
    let status: String
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case expiresAt = "expires_at"
    }
}

private struct AudioResponseDTO: Codable {
    let text: String
    let arabicText: String?
    let audioBase64: String?
    let audioURL: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case arabicText = "arabic_text"
        case audioBase64 = "audio_base64"
        case audioURL = "audio_url"
    }
}

private struct VisionResponseDTO: Codable {
    let englishName: String
    let arabicName: String
    let transliteration: String
    let confidence: Double
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case englishName = "english_name"
        case arabicName = "arabic_name"
        case transliteration
        case confidence
        case description
    }
}

private struct PronunciationRequestDTO: Codable {
    let audioBase64: String
    let expectedText: String
    
    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case expectedText = "expected_text"
    }
}

private struct PronunciationResponseDTO: Codable {
    let score: Double
    let feedback: String
    let suggestions: [String]
}

private struct TextRequestDTO: Codable {
    let text: String
    let sessionId: String?
}

private struct TextResponseDTO: Codable {
    let text: String
    let arabicText: String?
}

private struct TTSRequestDTO: Codable {
    let text: String
    let voiceStyle: String
    
    enum CodingKeys: String, CodingKey {
        case text
        case voiceStyle = "voice_style"
    }
}

private struct TTSResponseDTO: Codable {
    let audioBase64: String?
    let success: Bool
    let fallbackToDevice: Bool
    
    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case success
        case fallbackToDevice = "fallback_to_device"
    }
}

private struct ChatRequestDTO: Codable {
    let message: String
    let context: String
    let sessionId: String?
}

private struct ChatResponseDTO: Codable {
    let reply: String
}

private struct ImageGenerationRequestDTO: Codable {
    let prompt: String
}

private struct ImageGenerationResponseDTO: Codable {
    let imageBase64: String?
    let mimeType: String?
    let success: Bool
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
        case success
        case error
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let geminiAudioReceived = Notification.Name("geminiAudioReceived")
    static let geminiTextReceived = Notification.Name("geminiTextReceived")
}
