//
//  AudioService.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Service Protocol
protocol AudioService {
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    var isSpeaking: Bool { get }
    var audioLevel: Double { get }
    var audioLevelPublisher: AnyPublisher<Double, Never> { get }
    var speakingProgressPublisher: AnyPublisher<SpeakingProgress, Never> { get }
    
    func startRecording() async throws
    func stopRecording() async throws -> Data
    func playAudio(_ data: Data) async throws
    func stopPlayback()
    func requestPermission() async -> Bool
    
    // Text-to-Speech
    func speak(_ text: String, language: String) async
    func speakArabic(_ text: String) async
    func speakNaturalArabic(_ text: String, using geminiService: GeminiService) async
    func playAudioData(_ audioData: Data) async
    func stopSpeaking()
}

// MARK: - Speaking Progress (for lip sync)
struct SpeakingProgress {
    let isSpeaking: Bool
    let currentWord: String?
    let progress: Double // 0.0 to 1.0
}

// MARK: - Audio Service Implementation
final class AudioServiceImpl: NSObject, AudioService {
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var recordedData: Data = Data()
    private var audioFile: AVAudioFile?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private let audioLevelSubject = CurrentValueSubject<Double, Never>(0.0)
    private let speakingProgressSubject = CurrentValueSubject<SpeakingProgress, Never>(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 0))
    
    // For async/await speech completion
    private var speechContinuation: CheckedContinuation<Void, Never>?
    private var currentUtterance: AVSpeechUtterance?
    
    // For real-time lip sync
    private var lipSyncTimer: Timer?
    private var lipSyncDisplayLink: CADisplayLink?
    private var currentMouthOpenness: Double = 0.0
    private var targetMouthOpenness: Double = 0.0
    
    private(set) var isRecording: Bool = false
    private(set) var isPlaying: Bool = false
    private(set) var isSpeaking: Bool = false
    
    var audioLevel: Double {
        audioLevelSubject.value
    }
    
    var audioLevelPublisher: AnyPublisher<Double, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    var speakingProgressPublisher: AnyPublisher<SpeakingProgress, Never> {
        speakingProgressSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        setupAudioSession()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playback category first for TTS, then switch to playAndRecord for recording
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            print("✅ Audio session setup successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupForRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("✅ Audio session setup for recording")
        } catch {
            print("❌ Failed to setup audio session for recording: \(error)")
        }
    }
    
    private func setupForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            print("✅ Audio session setup for playback")
        } catch {
            print("❌ Failed to setup audio session for playback: \(error)")
        }
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() async throws {
        guard !isRecording else { return }
        
        setupForRecording() // Switch to recording mode
        
        let hasPermission = await requestPermission()
        guard hasPermission else {
            throw AudioError.permissionDenied
        }
        
        recordedData = Data()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioError.engineInitFailed
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create format for 16kHz mono (what Speech-to-Text expects)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AppConfig.audioSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.engineInitFailed
        }
        
        // Create converter if needed
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        print("📱 Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
        print("📱 Output format: \(outputFormat.sampleRate) Hz, \(outputFormat.channelCount) channels")
        
        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(AppConfig.audioBufferSize), format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Convert to target format if needed
            if let converter = converter {
                let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if error == nil {
                    self.processAudioBuffer(convertedBuffer)
                } else {
                    print("⚠️ Audio conversion error: \(error!)")
                    self.processAudioBuffer(buffer)
                }
            } else {
                self.processAudioBuffer(buffer)
            }
        }
        
        try audioEngine.start()
        isRecording = true
        print("🎤 Recording started")
    }
    
    func stopRecording() async throws -> Data {
        guard isRecording else {
            throw AudioError.notRecording
        }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevelSubject.send(0.0)
        
        print("🎤 Recording stopped. Raw data size: \(recordedData.count) bytes")
        
        // Convert to WAV format for API
        let wavData = try convertToWAV(recordedData)
        print("🎤 WAV data size: \(wavData.count) bytes")
        
        return wavData
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        // Calculate RMS for audio level
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevelSubject.send(Double(normalizedLevel))
        }
        
        // Append buffer data
        if let data = buffer.toData() {
            recordedData.append(data)
        }
    }
    
    private func convertToWAV(_ data: Data) throws -> Data {
        // Simple PCM to WAV conversion
        var wavData = Data()
        
        let sampleRate: UInt32 = UInt32(AppConfig.audioSampleRate)
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = channels * (bitsPerSample / 8)
        let dataSize: UInt32 = UInt32(data.count)
        let fileSize: UInt32 = 36 + dataSize
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(data)
        
        return wavData
    }
    
    // MARK: - Playback
    
    func playAudio(_ data: Data) async throws {
        guard !isPlaying else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            throw AudioError.playbackFailed(error)
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    // MARK: - Text-to-Speech
    
    // Find the best Arabic MALE voice available (teacher = male voice)
    private var teacherVoice: AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter Arabic voices
        let arabicVoices = voices.filter { $0.language.hasPrefix("ar") }
        
        // 1st priority: Male premium/enhanced voice
        if let malePremium = arabicVoices.first(where: {
            $0.gender == .male && ($0.quality == .enhanced || $0.quality == .premium)
        }) {
            return malePremium
        }
        
        // 2nd priority: Any male Arabic voice
        if let maleArabic = arabicVoices.first(where: { $0.gender == .male }) {
            return maleArabic
        }
        
        // 3rd priority: Any enhanced/premium voice
        if let premiumVoice = arabicVoices.first(where: {
            $0.quality == .enhanced || $0.quality == .premium
        }) {
            return premiumVoice
        }
        
        // Fallback to any Arabic voice
        if let anyArabic = arabicVoices.first {
            return anyArabic
        }
        
        // Last resort - Saudi Arabic
        return AVSpeechSynthesisVoice(language: "ar-SA")
    }
    
    func speak(_ text: String, language: String = "en-US") async {
        stopSpeaking() // Stop any current speech
        setupForPlayback() // Ensure audio session is set for playback
        let utterance = AVSpeechUtterance(string: text)
        
        // Use the Arabic teacher voice
        utterance.voice = teacherVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8 // Slower, more natural
        utterance.pitchMultiplier = 1.0 // Natural pitch
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1 // Small pause before speaking
        utterance.postUtteranceDelay = 0.2 // Small pause after speaking
        
        currentUtterance = utterance
        isSpeaking = true
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: true, currentWord: nil, progress: 0))
        
        // Use continuation to wait for speech to complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.speechContinuation = continuation
            speechSynthesizer.speak(utterance)
        }
    }
    
    func speakArabic(_ text: String) async {
        stopSpeaking() // Stop any current speech
        setupForPlayback() // Ensure audio session is set for playback
        
        let utterance = AVSpeechUtterance(string: text)
        // Use the Arabic teacher voice
        utterance.voice = teacherVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.7 // Even slower for Arabic clarity
        utterance.pitchMultiplier = 1.0 // Natural pitch
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3 // Longer pause for Arabic to let it sink in
        
        currentUtterance = utterance
        isSpeaking = true
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: true, currentWord: nil, progress: 0))
        
        // Use continuation to wait for speech to complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.speechContinuation = continuation
            speechSynthesizer.speak(utterance)
        }
    }
    
    /// Speak Arabic text using natural voice from Gemini TTS (Orus male voice)
    /// Uses cache for instant playback if available
    /// Retries Gemini TTS before falling back to device TTS for consistent voice
    func speakNaturalArabic(_ text: String, using geminiService: GeminiService) async {
        stopSpeaking()
        setupForPlayback() // Ensure audio session is set for playback
        
        let cacheManager = AudioCacheManager.shared
        
        // 1. Check cache first (instant playback!)
        if let cachedAudio = cacheManager.getAudio(for: text, type: .word) ??
                            cacheManager.getAudio(for: text, type: .sentence) ??
                            cacheManager.getAudio(for: text, type: .response) ??
                            cacheManager.getAudio(for: text, type: .instruction) {
            print("⚡ Playing from cache: \(text)")
            await playAudioData(cachedAudio)
            return
        }
        
        // 2. Try Gemini TTS with retry (up to 3 attempts for consistent voice)
        for attempt in 1...3 {
            do {
                print("🔊 Gemini TTS attempt \(attempt) for: \(text.prefix(30))...")
                if let audioData = try await geminiService.getNaturalSpeech(text: text) {
                    // Save to cache for next time
                    cacheManager.saveAudio(audioData, for: text, type: .response)
                    
                    // Play the natural audio
                    await playAudioData(audioData)
                    return
                }
                // nil means no audio - treat as error for retry
                print("⚠️ Gemini TTS attempt \(attempt) returned nil")
            } catch {
                print("⚠️ Gemini TTS attempt \(attempt) failed: \(error.localizedDescription)")
            }
            
            // Wait before retry (increasing delay)
            if attempt < 3 {
                let delay = UInt64(attempt) * 500_000_000 // 0.5s, 1.0s
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        
        // 3. Last resort fallback to device TTS (should rarely happen)
        print("⚠️ Falling back to device TTS for: \(text)")
        await speakArabic(text)
    }
    
    /// Helper to play audio data directly (public for when audio is already available)
    func playAudioData(_ audioData: Data) async {
        isSpeaking = true
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: true, currentWord: nil, progress: 0))
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            // Wait for playback to finish
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.speechContinuation = continuation
            }
        } catch {
            print("Failed to play audio: \(error)")
            isSpeaking = false
            speakingProgressSubject.send(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 0))
        }
    }
    
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 0))
        
        // Resume any waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
        currentUtterance = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioServiceImpl: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        isSpeaking = false
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 1.0))
        NotificationCenter.default.post(name: .audioPlaybackFinished, object: nil)
        NotificationCenter.default.post(name: .speechFinished, object: nil)
        
        // Resume any waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        isSpeaking = false
        if let error = error {
            print("Audio decode error: \(error)")
        }
        
        // Resume any waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioServiceImpl: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: true, currentWord: nil, progress: 0))
        
        // Start the lip sync timer
        startLipSyncSimulation()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Just track progress, don't interfere with lip sync timer
        let progress = Double(characterRange.location + characterRange.length) / Double(utterance.speechString.count)
        let currentWord = (utterance.speechString as NSString).substring(with: characterRange)
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: true, currentWord: currentWord, progress: progress))
        // Timer handles lip sync - don't post audio level here
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 1.0))
        NotificationCenter.default.post(name: .speechFinished, object: nil)
        
        // Stop lip sync timer and close mouth
        stopLipSyncSimulation()
        
        // Resume the waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
        currentUtterance = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingProgressSubject.send(SpeakingProgress(isSpeaking: false, currentWord: nil, progress: 0))
        
        // Stop lip sync timer and close mouth
        stopLipSyncSimulation()
        
        // Resume the waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
        currentUtterance = nil
    }
    
    /// Calculate audio level based on the phonemes in the text
    private func calculateAudioLevelForText(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }
        
        // Map Arabic/English characters to approximate mouth openness
        let char = text.first!
        
        switch char {
        // Very open mouth sounds (high level)
        case "ا", "أ", "إ", "آ", "ع", "ح", "ه", "a", "A", "H":
            return Double.random(in: 0.7...0.9)
            
        // Open mouth sounds
        case "و", "ض", "ظ", "o", "O", "u", "U":
            return Double.random(in: 0.6...0.8)
            
        // Medium open
        case "ي", "ش", "س", "ص", "e", "E", "i", "I":
            return Double.random(in: 0.4...0.6)
            
        // Slight open
        case "ت", "ث", "د", "ذ", "ر", "ز", "ن", "ل", "ك", "ق", "ف":
            return Double.random(in: 0.3...0.5)
            
        // Closed/bilabial sounds
        case "م", "ب", "p", "P", "m", "M", "b", "B":
            return Double.random(in: 0.05...0.15)
            
        // Space/pause
        case " ", "،", ".", ",":
            return 0.0
            
        // Default medium
        default:
            return Double.random(in: 0.3...0.5)
        }
    }
    
    /// Start a fast timer for natural lip sync animation
    private func startLipSyncSimulation() {
        stopLipSyncSimulation()
        
        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // FAST timer - 60ms intervals for natural speech rhythm
            self.lipSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                self?.updateLipSyncAnimation()
            }
            
            // Make sure timer runs even during scrolling
            if let timer = self.lipSyncTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            
            // Start with mouth open
            self.currentMouthOpenness = 0.6
            self.postMouthLevel(0.6)
        }
    }
    
    /// Post mouth level notification on main thread
    private func postMouthLevel(_ level: Double) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .audioLevelChanged,
                object: nil,
                userInfo: ["level": level]
            )
        }
    }
    
    /// Update lip sync animation - alternates between open and closed
    @objc private func updateLipSyncAnimation() {
        guard isSpeaking else {
            currentMouthOpenness = 0.0
            postMouthLevel(0.0)
            return
        }
        
        // Simple alternation: if open -> close, if closed -> open
        // This creates the natural talking open-close-open-close pattern
        if currentMouthOpenness > 0.4 {
            // Was open -> now CLOSE (small value)
            currentMouthOpenness = Double.random(in: 0.05...0.2)
        } else {
            // Was closed -> now OPEN (big value)
            currentMouthOpenness = Double.random(in: 0.6...0.9)
        }
        
        postMouthLevel(currentMouthOpenness)
    }
    
    private func stopLipSyncSimulation() {
        lipSyncTimer?.invalidate()
        lipSyncTimer = nil
        currentMouthOpenness = 0.0
        targetMouthOpenness = 0.0
        
        // Make sure mouth closes
        postMouthLevel(0.0)
    }
}

// MARK: - Audio Errors
enum AudioError: Error, LocalizedError {
    case permissionDenied
    case engineInitFailed
    case notRecording
    case playbackFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .notRecording:
            return "Not currently recording"
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - AVAudioPCMBuffer Extension
extension AVAudioPCMBuffer {
    func toData() -> Data? {
        guard let channelData = floatChannelData else { return nil }
        
        let channelCount = Int(format.channelCount)
        let frameLength = Int(self.frameLength)
        
        var data = Data()
        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let sample = channelData[channel][frame]
                // Convert float to Int16
                let intSample = Int16(max(-1, min(1, sample)) * Float(Int16.max))
                withUnsafeBytes(of: intSample.littleEndian) { data.append(contentsOf: $0) }
            }
        }
        
        return data
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioPlaybackFinished = Notification.Name("audioPlaybackFinished")
    static let speechFinished = Notification.Name("speechFinished")
}
