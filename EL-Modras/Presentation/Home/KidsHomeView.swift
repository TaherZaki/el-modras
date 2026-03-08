//
//  KidsHomeView.swift
//  EL-Modras
//
//  A colorful, kid-friendly home screen with the teacher avatar
//

import SwiftUI

struct KidsHomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.dependencies) private var dependencies
    
    @State private var teacherMood: TeacherMood = .idle
    @State private var isSpeaking: Bool = false
    @State private var welcomeMessage: String = ""
    @State private var showingLesson: Lesson?
    @State private var showingStory: Story?
    @State private var showingCamera: Bool = false
    @State private var showingProgress: Bool = false
    @State private var bounceAnimation: Bool = false
    @State private var hasIntroduced: Bool = false
    
    // Services for avatar speech
    private var audioService: AudioService {
        dependencies.audioService
    }
    
    private var geminiService: GeminiService {
        dependencies.geminiService
    }
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fun animated background
                animatedBackground
                
                if viewModel.isLoading {
                    // Loading view
                    loadingView
                } else {
                    // Main content
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Welcome section with Avatar
                                welcomeSection
                                
                                // Daily Goal Card
                                dailyGoalCard
                                
                                // Lesson Categories
                                categoriesSection
                                
                                // Interactive Stories Section
                                storiesSection
                                
                                // Fun Lessons Grid
                                lessonsGrid
                            }
                            .padding()
                            .padding(.bottom, 100) // Space for bottom nav
                        }
                        
                        // Fun bottom navigation
                        bottomNavigation
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $showingLesson) { lesson in
                KidsLessonView(viewModel: dependencies.makeLessonViewModel(lesson: lesson))
            }
            .sheet(item: $showingStory) { story in
                InteractiveStoryView(
                    viewModel: dependencies.makeStoryViewModel(story: story)
                )
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraVocabView(viewModel: dependencies.makeCameraVocabViewModel())
            }
            .fullScreenCover(isPresented: $showingProgress) {
                KidsProgressView(viewModel: dependencies.makeProgressViewModel())
            }
            .task {
                await viewModel.loadData()
                animateWelcome()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            TeacherAvatarView(
                mood: .thinking,
                isSpeaking: false,
                message: L10n.loading
            )
            .frame(height: 250)
            
            Text(L10n.gettingReady)
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
    
    // MARK: - Bottom Navigation
    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            // Home button
            KidsNavButton(
                icon: "house.fill",
                label: L10n.home,
                color: .blue,
                isSelected: true
            ) {
                // Already on home
            }
            
            // Camera button (big center button)
            KidsCameraNavButton {
                showingCamera = true
            }
            
            // Stars/Progress button
            KidsNavButton(
                icon: "star.fill",
                label: L10n.stars,
                color: .yellow,
                isSelected: false
            ) {
                showingProgress = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Animated Background
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.6, blue: 1.0),
                    Color(red: 0.5, green: 0.4, blue: 0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Floating shapes
            FloatingShapes()
        }
    }
    
    // MARK: - Welcome Section
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            // Greeting based on time
            Text(greetingText)
                .font(.title.bold())
                .foregroundStyle(.white)
            
            // Teacher Avatar
            TeacherAvatarView(
                mood: teacherMood,
                isSpeaking: isSpeaking,
                message: welcomeMessage
            )
            .frame(height: 300)
            .onTapGesture {
                // Tap to hear introduction again
                Task {
                    await speakIntroduction()
                }
            }
            
            // Instruction text
            Text(welcomeMessage.isEmpty ? "اضغط على نور! 👆" : "اختار درس وابدأ تعلم! ")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Daily Goal Card
    private var dailyGoalCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.todayGoal)
                        .font(.headline)
                        .foregroundStyle(Color.black.opacity(0.85))
                    
                    Text(L10n.learnNewWords)
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                }
                
                Spacer()
                
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: 0.6)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("3")
                            .font(.title2.bold())
                            .foregroundStyle(Color.black)
                        Text("\(L10n.of) 5")
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                    }
                }
                .frame(width: 60, height: 60)
            }
            
            // Streak info
            HStack(spacing: 20) {
                StatBadge(icon: "flame.fill", value: "5", label: L10n.dayStreak, color: .orange)
                StatBadge(icon: "star.fill", value: "23", label: L10n.words, color: .yellow)
                StatBadge(icon: "clock.fill", value: "15m", label: L10n.today, color: .blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.categories)
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Camera Learn Button - First for visibility
                    CategoryButton(
                        emoji: "📷",
                        title: L10n.camera,
                        color: .cyan
                    ) {
                        showingCamera = true
                    }
                    
                    CategoryButton(
                        emoji: "👋",
                        title: L10n.greetings,
                        color: .pink
                    ) {
                        // Filter greetings
                    }
                    
                    CategoryButton(
                        emoji: "🔢",
                        title: L10n.numbers,
                        color: .orange
                    ) {
                        // Filter numbers
                    }
                    
                    CategoryButton(
                        emoji: "🎨",
                        title: L10n.colors,
                        color: .purple
                    ) {
                        // Filter colors
                    }
                    
                    CategoryButton(
                        emoji: "🍎",
                        title: L10n.food,
                        color: .red
                    ) {
                        // Filter food
                    }
                    
                    CategoryButton(
                        emoji: "🐱",
                        title: L10n.animals,
                        color: .green
                    ) {
                        // Filter animals
                    }
                    
                    CategoryButton(
                        emoji: "👨‍👩‍👧",
                        title: L10n.family,
                        color: .blue
                    ) {
                        // Filter family
                    }
                    
                    CategoryButton(
                        emoji: "🔤",
                        title: L10n.alphabet,
                        color: .indigo
                    ) {
                        // Filter alphabet
                    }
                }
            }
        }
    }
    
    // MARK: - Stories Section
    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📖 قصص تفاعلية")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("جديد!")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Story.allStories, id: \.id) { story in
                        StoryCard(story: story) {
                            showingStory = story
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Lessons Grid
    private var lessonsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.lessons)
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.allLessons) { lesson in
                    KidsLessonCard(lesson: lesson) {
                        showingLesson = lesson
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning! ☀️"
        } else if hour < 17 {
            return "Good Afternoon! 🌤"
        } else {
            return "Good Evening! 🌙"
        }
    }
    
    private var randomEncouragement: String {
        let messages = [
            "You're doing great! 🌟",
            "Let's learn something new!",
            "Arabic is fun! 🎉",
            "You're a superstar! ⭐️",
            "Keep going, champion! 💪"
        ]
        return messages.randomElement() ?? "مرحباً!"
    }
    
    // MARK: - Actions
    private func animateWelcome() {
        // Only introduce once per session
        guard !hasIntroduced else {
            teacherMood = .happy
            return
        }
        
        hasIntroduced = true
        
        // Start introduction
        Task {
            await speakIntroduction()
        }
    }
    
    private func speakIntroduction() async {
        // Egyptian Arabic introduction - more conversational and natural
        let introSequence: [(message: String, mood: TeacherMood, pauseMs: UInt64)] = [
            ("أهلاً يا بطل!", .happy, 600_000_000),
            ("أنا نور... المدرس بتاعك!", .speaking, 600_000_000),
            ("هعلمك عربي بطريقة ممتعة!", .celebrating, 800_000_000),
            ("يلا نبدأ...", .thinking, 500_000_000),
            ("اختار أي درس وابدأ معايا!", .happy, 0)
        ]
        
        for (index, intro) in introSequence.enumerated() {
            // 1. Update message and mood
            welcomeMessage = intro.message
            teacherMood = intro.mood
            
            // 2. Start mouth animation FIRST
            isSpeaking = true
            
            // 3. Small delay to ensure animation starts before audio
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            // 4. Speak the message
            await audioService.speakNaturalArabic(intro.message, using: geminiService)
            
            // 5. Stop mouth animation AFTER audio finishes
            isSpeaking = false
            
            // 6. Pause between sentences
            if index < introSequence.count - 1 && intro.pauseMs > 0 {
                try? await Task.sleep(nanoseconds: intro.pauseMs)
            }
        }
        
        // Final state
        welcomeMessage = "اضغط على أي درس! 👇"
        teacherMood = .happy
        isSpeaking = false
        
        // Go to idle after a moment
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        teacherMood = .idle
    }
}

// MARK: - Supporting Views

struct FloatingShapes: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Floating circles
                ForEach(0..<6) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 50...150))
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: animate ? -100 : geometry.size.height + 100
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 8...15))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 2),
                            value: animate
                        )
                }
                
                // Stars
                ForEach(0..<10) { index in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(0.3))
                        .font(.system(size: CGFloat.random(in: 10...25)))
                        .offset(
                            x: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                            y: CGFloat.random(in: -geometry.size.height/2...geometry.size.height/2)
                        )
                        .scaleEffect(animate ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Color.black)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryButton: View {
    let emoji: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Text(emoji)
                        .font(.title)
                }
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

struct KidsLessonCard: View {
    let lesson: Lesson
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon and difficulty
                HStack {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: lesson.category.icon)
                            .font(.title2)
                            .foregroundStyle(categoryColor)
                    }
                    
                    Spacer()
                    
                    // Stars for difficulty
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Image(systemName: index < difficultyStars ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                
                // Lesson info
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.titleArabic)
                        .font(.headline)
                        .foregroundStyle(Color.black.opacity(0.85))
                    
                    Text(lesson.title)
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                    
                    // Word count
                    HStack(spacing: 4) {
                        Image(systemName: "textformat.abc")
                            .font(.caption)
                        Text("\(lesson.words.count) words")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.gray)
                }
                
                // Play button
                HStack {
                    Spacer()
                    
                    Text("Start")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(categoryColor)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
    
    private var categoryColor: Color {
        switch lesson.category {
        case .greetings: return .pink
        case .numbers: return .orange
        case .colors: return .purple
        case .food: return .red
        case .animals: return .green
        case .family: return .blue
        case .travel: return .teal
        case .shopping: return .indigo
        case .weather: return .cyan
        case .bodyParts: return .mint
        case .household: return .brown
        case .workplace: return .gray
        case .conversation: return .yellow
        case .grammar: return .secondary
        case .alphabet: return .indigo
        }
    }
    
    private var difficultyStars: Int {
        switch lesson.level {
        case .beginner: return 1
        case .elementary: return 1
        case .intermediate: return 2
        case .upperIntermediate: return 2
        case .advanced: return 3
        }
    }
}

// MARK: - Kids Navigation Button
struct KidsNavButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? color : .gray)
                
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? color : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Kids Camera Navigation Button (Big Center Button)
struct KidsCameraNavButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulse = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .cyan.opacity(0.5), radius: pulse ? 15 : 8, y: 3)
                
                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .offset(y: -20) // Float above the bar
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Kids Progress View
struct KidsProgressView: View {
    @StateObject private var viewModel: ProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: ProgressViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Fun gradient background
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.8, blue: 0.3),
                    Color(red: 1.0, green: 0.5, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating stars background
            FloatingStars()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text("My Stars ⭐️")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Circle()
                        .fill(.clear)
                        .frame(width: 44, height: 44)
                }
                .padding()
                .padding(.top, 20)
                
                // Trophy/Avatar area
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 180, height: 180)
                    
                    Text("🏆")
                        .font(.system(size: 100))
                }
                
                // Stats cards
                VStack(spacing: 16) {
                    // Total Stars
                    KidsStatCard(
                        emoji: "⭐️",
                        title: "Total Stars",
                        value: "\(viewModel.totalWordsLearned)",
                        color: .yellow
                    )
                    
                    // Day Streak
                    KidsStatCard(
                        emoji: "🔥",
                        title: "Day Streak",
                        value: "\(viewModel.currentStreak) days",
                        color: .orange
                    )
                    
                    // Words Learned
                    KidsStatCard(
                        emoji: "📚",
                        title: "Lessons Done",
                        value: "\(viewModel.totalLessonsCompleted)",
                        color: .blue
                    )
                    
                    // Time Spent
                    KidsStatCard(
                        emoji: "⏱️",
                        title: "Time Learning",
                        value: "\(viewModel.totalMinutesPracticed) min",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Encouraging message
                Text("You're doing amazing! Keep it up! 🎉")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
            }
        }
        .task {
            await viewModel.loadProgress()
        }
    }
}

// MARK: - Kids Stat Card
struct KidsStatCard: View {
    let emoji: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(emoji)
                    .font(.title)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.6))
                
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.black)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
        )
    }
}

// MARK: - Story Card
struct StoryCard: View {
    let story: Story
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Story cover
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: storyColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                    
                    Text(story.coverEmoji)
                        .font(.system(size: 60))
                }
                
                // Story title
                Text(story.titleArabic)
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.85))
                
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("\(story.estimatedMinutes) دقايق")
                        .font(.caption)
                }
                .foregroundStyle(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var storyColors: [Color] {
        switch story.coverEmoji {
        case "🐱":
            return [Color.orange.opacity(0.6), Color.yellow.opacity(0.6)]
        case "🧒":
            return [Color.blue.opacity(0.6), Color.cyan.opacity(0.6)]
        default:
            return [Color.purple.opacity(0.6), Color.pink.opacity(0.6)]
        }
    }
}

// MARK: - Floating Stars Animation
struct FloatingStars: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15) { index in
                    Text("⭐️")
                        .font(.system(size: CGFloat.random(in: 15...30)))
                        .offset(
                            x: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                            y: animate ? -100 : geometry.size.height + 100
                        )
                        .opacity(0.6)
                        .animation(
                            .easeInOut(duration: Double.random(in: 6...12))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                            value: animate
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Preview
#Preview {
    KidsHomeView(viewModel: DependencyContainer.shared.makeHomeViewModel())
}
