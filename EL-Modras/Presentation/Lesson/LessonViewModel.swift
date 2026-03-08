//
//  LessonViewModel.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import Combine

@MainActor
final class LessonViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var lesson: Lesson
    @Published var messages: [ConversationMessage] = []
    @Published var currentWord: Word?
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isPlaying = false
    @Published var isInterrupted = false  // Track interruption state
    @Published var audioLevel: Double = 0
    @Published var error: String?
    @Published var sessionState: SessionState = .idle
    @Published var pronunciationScore: PronunciationScore?
    
    enum SessionState {
        case idle
        case connecting
        case active
        case ended
    }
    
    // MARK: - Dependencies
    private let startConversationUseCase: StartConversationUseCase
    private let sendVoiceMessageUseCase: SendVoiceMessageUseCase
    private let endConversationUseCase: EndConversationUseCase
    private let getPronunciationFeedbackUseCase: GetPronunciationFeedbackUseCase
    private let trackWordLearnedUseCase: TrackWordLearnedUseCase
    private let trackLessonCompletedUseCase: TrackLessonCompletedUseCase
    let audioService: AudioService
    private let geminiService: GeminiService
    
    private var session: ConversationSession?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var canStartSession: Bool {
        sessionState == .idle || sessionState == .ended
    }
    
    var isSessionActive: Bool {
        sessionState == .active
    }
    
    var wordsInLesson: [Word] {
        lesson.words
    }
    
    // MARK: - Initialization
    init(
        lesson: Lesson,
        startConversationUseCase: StartConversationUseCase,
        sendVoiceMessageUseCase: SendVoiceMessageUseCase,
        endConversationUseCase: EndConversationUseCase,
        getPronunciationFeedbackUseCase: GetPronunciationFeedbackUseCase,
        trackWordLearnedUseCase: TrackWordLearnedUseCase,
        trackLessonCompletedUseCase: TrackLessonCompletedUseCase,
        audioService: AudioService,
        geminiService: GeminiService
    ) {
        self.lesson = lesson
        self.startConversationUseCase = startConversationUseCase
        self.sendVoiceMessageUseCase = sendVoiceMessageUseCase
        self.endConversationUseCase = endConversationUseCase
        self.getPronunciationFeedbackUseCase = getPronunciationFeedbackUseCase
        self.trackWordLearnedUseCase = trackWordLearnedUseCase
        self.trackLessonCompletedUseCase = trackLessonCompletedUseCase
        self.audioService = audioService
        self.geminiService = geminiService
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        audioService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        // Listen for Gemini responses
        NotificationCenter.default.publisher(for: .geminiTextReceived)
            .compactMap { $0.userInfo?["text"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.handleGeminiResponse(text: text)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .geminiAudioReceived)
            .compactMap { $0.userInfo?["audioData"] as? Data }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] audioData in
                Task { @MainActor in
                    await self?.playAudioResponse(audioData)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    func startSession() async {
        guard canStartSession else { return }
        
        sessionState = .connecting
        error = nil
        
        // Start preloading audio in background
        Task.detached { [weak self] in
            guard let self = self else { return }
            await AudioPreloader.shared.preloadLesson(self.lesson, using: self.geminiService)
        }
        
        do {
            // Request microphone permission
            let hasPermission = await audioService.requestPermission()
            guard hasPermission else {
                error = "Microphone permission required"
                sessionState = .idle
                return
            }
            
            // Start conversation with Gemini
            session = try await startConversationUseCase.execute(
                lessonId: lesson.id,
                userId: "current_user" // In production, get from auth
            )
            
            sessionState = .active
            
            // Add welcome message based on lesson category
            let welcomeMessage = createWelcomeMessage()
            messages.append(welcomeMessage)
            
            // Speak the welcome message
            await speakResponse(welcomeMessage)
            
            // Set first word to practice
            if let firstWord = lesson.words.first {
                currentWord = firstWord
            }
            
        } catch {
            self.error = "Failed to start Gemini session: \(error.localizedDescription)"
            sessionState = .idle
        }
    }
    
    // Create context-aware welcome message based on lesson category (Egyptian Arabic)
    private func createWelcomeMessage() -> ConversationMessage {
        let (_, arabicIntro, prompt) = getWelcomeTexts()
        
        let firstWord = lesson.words.first
        let wordExample = firstWord.map { "\($0.arabic)" } ?? ""
        
        // Egyptian Arabic message only
        let fullMessage = "\(arabicIntro) \(lesson.titleArabic). \(prompt) \(wordExample)!"
        
        return ConversationMessage(
            role: .assistant,
            content: fullMessage,
            contentArabic: fullMessage
        )
    }
    
    private func getWelcomeTexts() -> (english: String, arabic: String, prompt: String) {
        switch lesson.category {
        case .greetings:
            return (
                "يلا نتعلم التحيات!",
                "يلا نتعلم نسلم على بعض!",
                "نبدأ بـ"
            )
        case .numbers:
            return (
                "يلا نعد بالعربي!",
                "هيا نعد مع بعض!",
                "نبدأ بالرقم"
            )
        case .colors:
            return (
                "يلا نشوف الألوان!",
                "هيا نكتشف الألوان الحلوة!",
                "نبدأ باللون"
            )
        case .food:
            return (
                "يم يم! أكل لذيذ!",
                "يلا نتعلم أسماء الأكل!",
                "نبدأ بـ"
            )
        case .animals:
            return (
                "يلا نتعرف على الحيوانات!",
                "هيا نشوف الحيوانات!",
                "نبدأ بـ"
            )
        case .family:
            return (
                "العيلة مهمة أوي!",
                "يلا نتعلم كلمات العيلة!",
                "نبدأ بـ"
            )
        case .travel:
            return (
                "يلا نروح رحلة!",
                "هيا نتعلم كلمات السفر!",
                "نبدأ بـ"
            )
        case .shopping:
            return (
                "يلا نتسوق!",
                "وقت التسوق!",
                "نبدأ بـ"
            )
        case .weather:
            return (
                "الجو عامل إيه النهاردة؟",
                "يلا نتكلم عن الطقس!",
                "نبدأ بـ"
            )
        case .bodyParts:
            return (
                "يلا نتعرف على جسمنا!",
                "هيا نتعلم أجزاء الجسم!",
                "نبدأ بـ"
            )
        case .household:
            return (
                "يلا نستكشف البيت!",
                "هيا نتعلم حاجات البيت!",
                "نبدأ بـ"
            )
        case .workplace:
            return (
                "يلا نتعلم كلمات الشغل!",
                "هيا نعرف مكان العمل!",
                "نبدأ بـ"
            )
        case .conversation:
            return (
                "يلا نتكلم مع بعض!",
                "هيا نتعلم نتكلم بالعامية!",
                "نبدأ بـ"
            )
        case .grammar:
            return (
                "وقت القواعد!",
                "يلا نفهم القواعد!",
                "نبدأ بـ"
            )
        case .alphabet:
            return (
                "يلا نتعلم الحروف!",
                "هيا نتعلم الأبجدية العربية!",
                "نبدأ بحرف"
            )
        }
    }
    
    func endSession() async {
        guard isSessionActive, let session = session else { return }
        
        do {
            let summary = try await endConversationUseCase.execute(session: session)
            
            // Add summary message
            let summaryMessage = ConversationMessage(
                role: .assistant,
                content: "Great session! You practiced for \(Int(summary.duration / 60)) minutes. Keep up the excellent work! 🎉",
                contentArabic: "جلسة رائعة! لقد تدربت لمدة \(Int(summary.duration / 60)) دقائق."
            )
            messages.append(summaryMessage)
            
            sessionState = .ended
            self.session = nil
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Recording
    func startRecording() async {
        guard isSessionActive, !isRecording else { return }
        
        do {
            try await audioService.startRecording()
            isRecording = true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        do {
            let audioData = try await audioService.stopRecording()
            isRecording = false
            isProcessing = true
            
            // Add user message placeholder
            let userMessage = ConversationMessage(
                role: .user,
                content: "🎤 Speaking..."
            )
            messages.append(userMessage)
            
            // Check if we're practicing a word
            if let word = currentWord {
                // Try LOCAL speech recognition first (instant!)
                let localRecognizer = LocalSpeechRecognizer.shared
                
                do {
                    let recognizedText = try await localRecognizer.recognize(audioData: audioData)
                    print("🎤 Recognized locally: \(recognizedText)")
                    
                    // Update message with recognized text
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex] = ConversationMessage(
                            role: .user,
                            content: recognizedText
                        )
                    }
                    
                    // Compare with expected word (instant!)
                    let matchResult = localRecognizer.compareWords(recognized: recognizedText, expected: word.arabic)
                    
                    // Create pronunciation score
                    pronunciationScore = PronunciationScore(
                        wordId: word.id,
                        score: matchResult.score,
                        feedback: matchResult.isMatch ? "ممتاز!" : "حاول تاني",
                        timestamp: Date()
                    )
                    
                    isProcessing = false
                    return
                    
                } catch {
                    print("⚠️ Local recognition failed, falling back to Gemini: \(error)")
                }
            }
            
            // Fallback: Send to Gemini (slower but more accurate)
            guard let session = session else {
                isProcessing = false
                return
            }
            
            let response = try await sendVoiceMessageUseCase.execute(
                audioData: audioData,
                session: session
            )
            
            // Update last message with transcription
            if let lastIndex = messages.indices.last {
                messages[lastIndex] = ConversationMessage(
                    role: .user,
                    content: "Audio message sent"
                )
            }
            
            // Add assistant response
            messages.append(response)
            
            // Check pronunciation if practicing a specific word
            if let word = currentWord {
                let score = try await getPronunciationFeedbackUseCase.execute(
                    audioData: audioData,
                    expectedWord: word
                )
                pronunciationScore = score
            }
            
            isProcessing = false
            
        } catch {
            self.error = error.localizedDescription
            isRecording = false
            isProcessing = false
        }
    }
    
    // MARK: - Helpers
    private func handleGeminiResponse(text: String) {
        let message = ConversationMessage(
            role: .assistant,
            content: text
        )
        messages.append(message)
    }
    
    private func playAudioResponse(_ data: Data) async {
        isPlaying = true
        do {
            try await audioService.playAudio(data)
        } catch {
            self.error = error.localizedDescription
        }
        isPlaying = false
    }
    
    private func moveToNextWord() {
        guard let currentWord = currentWord,
              let currentIndex = lesson.words.firstIndex(where: { $0.id == currentWord.id }) else {
            return
        }
        
        // Track that this word was learned
        Task {
            await trackWordLearned(currentWord)
        }
        
        // Move to next word or finish lesson
        if currentIndex + 1 < lesson.words.count {
            self.currentWord = lesson.words[currentIndex + 1]
        } else {
            // Lesson completed!
            Task {
                await trackLessonCompleted()
            }
        }
    }
    
    func selectWord(_ word: Word) {
        currentWord = word
        pronunciationScore = nil
    }
    
    func speakWord(_ word: Word) async {
        // Step 1: Say the word
        let wordMessage = ConversationMessage(
            role: .assistant,
            content: word.arabic,
            contentArabic: word.arabic
        )
        messages.append(wordMessage)
        
        isPlaying = true
        await audioService.speakNaturalArabic(word.arabic, using: geminiService)
        isPlaying = false
        
        // Small pause
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Step 2: Ask the student to repeat
        let repeatRequest = "قول معايا: \(word.arabic)"
        let repeatMessage = ConversationMessage(
            role: .assistant,
            content: repeatRequest,
            contentArabic: repeatRequest
        )
        messages.append(repeatMessage)
        
        isPlaying = true
        await audioService.speakNaturalArabic(repeatRequest, using: geminiService)
        isPlaying = false
    }
    
    /// Speak intro before sentence
    func speakSentenceIntro() async {
        let intro = "هاحطهالك في جملة، ركز معايا!"
        
        let introMessage = ConversationMessage(
            role: .assistant,
            content: intro,
            contentArabic: intro
        )
        messages.append(introMessage)
        
        isPlaying = true
        await audioService.speakNaturalArabic(intro, using: geminiService)
        isPlaying = false
    }
    
    /// Called after student successfully pronounces the word - says just the sentence
    func speakWordInSentence(_ word: Word) async {
        // Generate or get the sentence (Arabic first, then generate if not available)
        let sentence = word.exampleSentenceArabic ?? word.exampleSentence ?? generateSimpleSentence(for: word)
        
        // Say the sentence
        let sentenceMessage = ConversationMessage(
            role: .assistant,
            content: sentence,
            contentArabic: sentence
        )
        messages.append(sentenceMessage)
        
        isPlaying = true
        await audioService.speakNaturalArabic(sentence, using: geminiService)
        isPlaying = false
    }
    
    func speakText(_ text: String, isArabic: Bool = false) async {
        isPlaying = true
        if isArabic {
            // Use Gemini's natural Arabic voice
            await audioService.speakNaturalArabic(text, using: geminiService)
        } else {
            // For English, use device TTS (or could add English natural voice too)
            await audioService.speak(text, language: "en-US")
        }
        isPlaying = false
    }
    
    func speakResponse(_ message: ConversationMessage) async {
        isPlaying = true
        
        // Speak ONLY Arabic using Gemini's natural voice
        if let arabicText = message.contentArabic {
            await audioService.speakNaturalArabic(arabicText, using: geminiService)
        }
        
        isPlaying = false
    }
    
    // MARK: - Progress Tracking
    
    // MARK: - Interruption (Barge-in)
    func interruptTeacher() async {
        // Stop any ongoing speech immediately
        audioService.stopSpeaking()
        isPlaying = false
        isInterrupted = true
        
        // Notify backend about interruption
        if let session = session {
            do {
                try await geminiService.interruptSession(sessionId: session.id)
            } catch {
                print("Failed to notify backend of interruption: \(error)")
            }
        }
        
        // Reset interruption state after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            isInterrupted = false
        }
    }
    
    // Ask a question to the teacher
    func askTeacher(question: String) async {
        guard isSessionActive else { return }
        
        // First interrupt if teacher is speaking
        if isPlaying {
            await interruptTeacher()
        }
        
        isProcessing = true
        
        // Add user's question to chat
        let userMessage = ConversationMessage(
            role: .user,
            content: question
        )
        messages.append(userMessage)
        
        do {
            // Send question to Gemini
            let response = try await geminiService.chat(
                message: question,
                context: "You are a friendly Arabic teacher for kids. The child is asking: \(question). Respond in simple Egyptian Arabic (عامية مصرية). Be encouraging and helpful."
            )
            
            // Add response to chat
            let assistantMessage = ConversationMessage(
                role: .assistant,
                content: response,
                contentArabic: response
            )
            messages.append(assistantMessage)
            
            // Speak the response
            isPlaying = true
            await audioService.speakNaturalArabic(response, using: geminiService)
            isPlaying = false
            
        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    // MARK: - Voice Question Recording
    
    private var questionAudioData: Data?
    
    func startRecordingQuestion() async {
        // First interrupt if teacher is speaking
        if isPlaying {
            await interruptTeacher()
        }
        
        do {
            try await audioService.startRecording()
            isRecording = true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopRecordingAndAskQuestion() async {
        guard isRecording else { return }
        
        do {
            let audioData = try await audioService.stopRecording()
            isRecording = false
            isProcessing = true
            
            // 1. Try LOCAL speech recognition first (instant!)
            let localRecognizer = LocalSpeechRecognizer.shared
            let cacheManager = AudioCacheManager.shared
            
            do {
                let recognizedText = try await localRecognizer.recognize(audioData: audioData)
                print("🎤 Question recognized locally: \(recognizedText)")
                
                // Add user's question
                let userMessage = ConversationMessage(
                    role: .user,
                    content: recognizedText
                )
                messages.append(userMessage)
                
                // 2. Check for keywords (instant response!)
                if let keyword = localRecognizer.detectKeywords(in: recognizedText) {
                    let response = await handleKeyword(keyword)
                    
                    // Add response
                    let assistantMessage = ConversationMessage(
                        role: .assistant,
                        content: response,
                        contentArabic: response
                    )
                    messages.append(assistantMessage)
                    
                    // Speak response (from cache if available!)
                    isPlaying = true
                    await audioService.speakNaturalArabic(response, using: geminiService)
                    isPlaying = false
                    
                    isProcessing = false
                    return
                }
                
            } catch {
                print("⚠️ Local recognition failed: \(error)")
            }
            
            // 3. Fallback: Send to Gemini (slower but handles complex questions)
            // Backend now does transcribe + answer + TTS in ONE call
            let lessonContext = buildLessonContext()
            let response = try await geminiService.sendAudioMessageWithContext(
                audioData: audioData,
                context: lessonContext
            )
            
            // Add user's question (transcribed)
            if messages.last?.role != .user {
                let userMessage = ConversationMessage(
                    role: .user,
                    content: "🎤 سؤال صوتي"
                )
                messages.append(userMessage)
            }
            
            // Add response to chat
            let responseText = response.arabicText ?? response.text
            let assistantMessage = ConversationMessage(
                role: .assistant,
                content: response.text,
                contentArabic: responseText
            )
            messages.append(assistantMessage)
            
            // Play audio - use audio from response directly if available (no second round trip!)
            if let audioData = response.audioData {
                // Audio came with the response - play it directly (fastest!)
                isPlaying = true
                await audioService.playAudioData(audioData)
                isPlaying = false
                
                // Cache it for next time
                AudioCacheManager.shared.saveAudio(audioData, for: responseText, type: .response)
            } else {
                // Fallback: get TTS separately (slower)
                isPlaying = true
                await audioService.speakNaturalArabic(responseText, using: geminiService)
                isPlaying = false
            }
            
            isProcessing = false
            
        } catch {
            self.error = error.localizedDescription
            isRecording = false
            isProcessing = false
        }
    }
    
    // Handle detected keyword with instant response
    private func handleKeyword(_ keyword: DetectedKeyword) async -> String {
        guard let word = currentWord else {
            return "اختار كلمة الأول!"
        }
        
        switch keyword {
        case .repeat:
            // Play the word again
            isPlaying = true
            await audioService.speakNaturalArabic(word.arabic, using: geminiService)
            isPlaying = false
            return "أيوه! \(word.arabic)"
            
        case .sentence:
            // Generate/retrieve sentence (Arabic first!)
            let sentence = word.exampleSentenceArabic ?? word.exampleSentence ?? generateSimpleSentence(for: word)
            return sentence
            
        case .meaning:
            return "\(word.arabic) يعني \(word.english)"
            
        case .next:
            // Move to next word
            moveToNextWord()
            if let newWord = currentWord {
                return "يلا! الكلمة الجديدة: \(newWord.arabic)"
            } else {
                return "خلصت الدرس! برافو عليك!"
            }
            
        case .help:
            return "مفيش مشكلة يا بطل! خلينا نجربها سوا. قول معايا: \(word.arabic)"
        }
    }
    
    // Generate simple sentence for a word (Egyptian Arabic)
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
    
    // Build context string with current lesson and word information
    private func buildLessonContext() -> String {
        var context = """
        أنت نور، المدرس في تطبيق تعليم اللغة العربية للأطفال.
        اسمك نور ولو حد سألك قولّه "أنا نور، المدرس بتاعك!"
        
        الدرس الحالي: \(lesson.title) (\(lesson.titleArabic))
        نوع الدرس: \(lesson.category.rawValue)
        """
        
        if let word = currentWord {
            context += """
            
            الكلمة الحالية اللي بنتعلمها:
            - بالعربي: \(word.arabic)
            - بالإنجليزي: \(word.english)
            - النطق: \(word.transliteration)
            """
            
            if let emoji = word.emoji {
                context += "\n- الإيموجي: \(emoji)"
            }
            
            if let example = word.exampleSentence {
                context += "\n- مثال: \(example)"
            }
        }
        
        // Add all words in the lesson for context
        let allWords = lesson.words.map { "\($0.arabic) (\($0.english))" }.joined(separator: "، ")
        context += """
        
        كل كلمات الدرس: \(allWords)
        
        لما الطفل يسأل سؤال:
        1. جاوب بناءً على الدرس والكلمة الحالية
        2. استخدم العامية المصرية البسيطة
        3. لو سأل عن جملة، استخدم الكلمة الحالية (\(currentWord?.arabic ?? ""))
        4. كن مشجع وإيجابي
        5. خلي الرد قصير ومفهوم للطفل
        """
        
        return context
    }

    func trackWordLearned(_ word: Word) async {
        do {
            try await trackWordLearnedUseCase.execute(
                word: word,
                category: lesson.category,
                userId: "current_user"
            )
            print("✅ Tracked word learned: \(word.arabic)")
        } catch {
            print("❌ Failed to track word: \(error)")
        }
    }
    
    func trackLessonCompleted() async {
        do {
            try await trackLessonCompletedUseCase.execute(
                lesson: lesson,
                userId: "current_user"
            )
            print("✅ Tracked lesson completed: \(lesson.title)")
        } catch {
            print("❌ Failed to track lesson: \(error)")
        }
    }
}
