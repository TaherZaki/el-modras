//
//  HomeView.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.dependencies) private var dependencies
    @State private var showingLesson: Lesson?
    @State private var showingCamera = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Progress Card
                    progressCard
                    
                    // Recommended Lessons
                    if !viewModel.recommendedLessons.isEmpty {
                        recommendedSection
                    }
                    
                    // Categories
                    categoriesSection
                    
                    // All Lessons
                    lessonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("EL-Modras")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $showingLesson) { lesson in
                LessonView(viewModel: dependencies.makeLessonViewModel(lesson: lesson))
            }
            .sheet(isPresented: $showingCamera) {
                CameraVocabView(viewModel: dependencies.makeCameraVocabViewModel())
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: viewModel.error) { oldValue, newValue in
                if let error = newValue {
                    errorMessage = error
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.greeting)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(viewModel.greetingEnglish)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            if let userName = viewModel.user?.name, !userName.isEmpty {
                Text("Welcome back, \(userName)!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                title: "Start Talking",
                arabicTitle: "ابدأ المحادثة",
                icon: "mic.fill",
                color: .blue
            ) {
                if let lesson = viewModel.recommendedLessons.first {
                    showingLesson = lesson
                }
            }
            
            QuickActionButton(
                title: "Camera Learn",
                arabicTitle: "تعلم بالكاميرا",
                icon: "camera.fill",
                color: .green
            ) {
                showingCamera = true
            }
        }
    }
    
    // MARK: - Progress Card
    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.streakText)
                        .font(.headline)
                    Text(viewModel.wordsLearnedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: viewModel.progress?.averageAccuracy ?? 0,
                    lineWidth: 8
                )
                .frame(width: 60, height: 60)
            }
            
            // Weekly progress bars
            WeeklyProgressView(dailyProgress: viewModel.progress?.dailyProgress ?? [])
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recommended Section
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Learning")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recommendedLessons) { lesson in
                        RecommendedLessonCard(lesson: lesson)
                            .onTapGesture {
                                showingLesson = lesson
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryChip(
                        title: "All",
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        viewModel.selectCategory(nil)
                    }
                    
                    ForEach(LessonCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Lessons Section
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Lessons")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredLessons) { lesson in
                    LessonCard(lesson: lesson)
                        .onTapGesture {
                            showingLesson = lesson
                        }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let title: String
    let arabicTitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(color.gradient)
                    .clipShape(Circle())
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(arabicTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.caption.weight(.bold))
        }
    }
}

struct WeeklyProgressView: View {
    let dailyProgress: [DailyProgress]
    
    private var weekDays: [(String, Int)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let minutes = dailyProgress
                .first { calendar.isDate($0.date, inSameDayAs: date) }?
                .minutesPracticed ?? 0
            return (dayName, minutes)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.0) { day, minutes in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(minutes > 0 ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 32, height: CGFloat(min(40, max(8, minutes))))
                    
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RecommendedLessonCard: View {
    let lesson: Lesson
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: lesson.category.icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(lesson.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            
            Text(lesson.titleArabic)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "clock")
                Text("\(lesson.durationMinutes) min")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            
            ProgressView(value: lesson.progress)
                .tint(.blue)
        }
        .padding()
        .frame(width: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CategoryChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct LessonCard: View {
    let lesson: Lesson
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: lesson.category.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.subheadline.weight(.semibold))
                
                Text(lesson.titleArabic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Label("\(lesson.durationMinutes) min", systemImage: "clock")
                    Label(lesson.level.displayName, systemImage: "chart.bar.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if lesson.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView(viewModel: DependencyContainer.shared.makeHomeViewModel())
}
