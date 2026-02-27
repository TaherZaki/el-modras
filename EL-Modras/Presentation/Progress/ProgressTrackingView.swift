//
//  ProgressTrackingView.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import SwiftUI

struct ProgressTrackingView: View {
    @StateObject private var viewModel: ProgressViewModel
    
    init(viewModel: ProgressViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats Overview
                    statsOverview
                    
                    // Streak Card
                    streakCard
                    
                    // Time Range Picker
                    timeRangePicker
                    
                    // Activity Chart
                    activityChart
                    
                    // Category Progress
                    categoryProgressSection
                    
                    // Achievements
                    achievementsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .refreshable {
                await viewModel.loadProgress()
            }
            .task {
                await viewModel.loadProgress()
            }
        }
    }
    
    // MARK: - Stats Overview
    private var statsOverview: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Words Learned",
                value: "\(viewModel.totalWordsLearned)",
                icon: "textformat.abc",
                color: .blue
            )
            
            StatCard(
                title: "Lessons Done",
                value: "\(viewModel.totalLessonsCompleted)",
                icon: "book.fill",
                color: .green
            )
            
            StatCard(
                title: "Minutes",
                value: "\(viewModel.totalMinutesPracticed)",
                icon: "clock.fill",
                color: .orange
            )
            
            StatCard(
                title: "Accuracy",
                value: "\(Int(viewModel.averageAccuracy * 100))%",
                icon: "target",
                color: .purple
            )
        }
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                }
                
                Text("\(viewModel.currentStreak) days")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                
                Text("Longest: \(viewModel.longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
            
            Spacer()
            
            // Streak visualization
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Circle()
                        .fill(day < viewModel.currentStreak % 7 ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(ProgressViewModel.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Activity Chart
    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
                .foregroundStyle(Color.black.opacity(0.85))
            
            if viewModel.recentActivity.isEmpty {
                Text("No activity yet. Start learning!")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Simple bar chart
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(viewModel.recentActivity.prefix(14).reversed()) { day in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.gradient)
                                .frame(width: 20, height: max(8, CGFloat(day.minutesPracticed) * 2))
                            
                            Text(dayLabel(for: day.date))
                                .font(.system(size: 8))
                                .foregroundStyle(Color.gray)
                        }
                    }
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    // MARK: - Category Progress
    private var categoryProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(Color.black.opacity(0.85))
            
            if viewModel.categoryProgressList.isEmpty {
                defaultCategoryProgress
            } else {
                ForEach(viewModel.categoryProgressList) { categoryProgress in
                    CategoryProgressRow(progress: categoryProgress)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var defaultCategoryProgress: some View {
        ForEach([LessonCategory.greetings, .numbers, .family], id: \.self) { category in
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                Text(category.displayName)
                    .font(.subheadline)
                
                Spacer()
                
                Text("0%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Achievements
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
            
            // Unlocked
            if !viewModel.unlockedAchievements.isEmpty {
                Text("Unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.unlockedAchievements) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
            
            // Locked
            if !viewModel.lockedAchievements.isEmpty {
                Text("In Progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.lockedAchievements) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.85))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CategoryProgressRow: View {
    let progress: CategoryProgress
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: progress.category.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                Text(progress.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.85))
                
                Spacer()
                
                Text("\(Int(progress.progressPercentage * 100))%")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
            
            ProgressView(value: progress.progressPercentage)
                .tint(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.type.icon)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .yellow : .gray)
            }
            
            Text(achievement.type.displayName)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isUnlocked ? Color.black.opacity(0.85) : Color.gray)
            
            if !achievement.isUnlocked {
                Text("\(achievement.progress)/\(achievement.target)")
                    .font(.caption2)
                    .foregroundStyle(Color.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressTrackingView(viewModel: DependencyContainer.shared.makeProgressViewModel())
}
