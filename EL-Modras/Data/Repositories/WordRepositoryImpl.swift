//
//  WordRepositoryImpl.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

final class WordRepositoryImpl: WordRepository {
    private let remoteDataSource: WordRemoteDataSource
    private let localDataSource: WordLocalDataSource
    
    init(remoteDataSource: WordRemoteDataSource, localDataSource: WordLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getAllWords() async throws -> [Word] {
        let localWords = try await localDataSource.getAllWords()
        if !localWords.isEmpty {
            return localWords
        }
        
        let remoteWords = try await remoteDataSource.fetchAllWords()
        try await localDataSource.saveWords(remoteWords)
        return remoteWords
    }
    
    func getWord(by id: String) async throws -> Word? {
        let words = try await getAllWords()
        return words.first { $0.id == id }
    }
    
    func getWords(for category: LessonCategory) async throws -> [Word] {
        let words = try await getAllWords()
        return words.filter { $0.category == category }
    }
    
    func getWords(for lessonId: String) async throws -> [Word] {
        // In a real app, this would fetch words associated with a specific lesson
        return try await getAllWords()
    }
    
    func searchWords(query: String) async throws -> [Word] {
        let words = try await getAllWords()
        let lowercasedQuery = query.lowercased()
        return words.filter {
            $0.english.lowercased().contains(lowercasedQuery) ||
            $0.arabic.contains(query) ||
            $0.transliteration.lowercased().contains(lowercasedQuery)
        }
    }
    
    func getMasteredWords(for userId: String) async throws -> [Word] {
        try await localDataSource.getMasteredWords(for: userId)
    }
    
    func markWordAsMastered(_ wordId: String, for userId: String) async throws {
        try await localDataSource.markWordAsMastered(wordId, for: userId)
    }
    
    func updatePracticeCount(_ wordId: String, for userId: String) async throws {
        try await localDataSource.updatePracticeCount(wordId, for: userId)
    }
}

// MARK: - Remote Data Source
final class WordRemoteDataSource {
    func fetchAllWords() async throws -> [Word] {
        // Return sample words
        var allWords: [Word] = []
        allWords.append(contentsOf: Word.sampleGreetings)
        allWords.append(contentsOf: Word.sampleNumbers)
        allWords.append(contentsOf: Word.sampleFamily)
        return allWords
    }
}

// MARK: - Local Data Source
final class WordLocalDataSource {
    private let wordsKey = "cached_words"
    private let masteredWordsKey = "mastered_words"
    private let practiceCountKey = "practice_count"
    
    func getAllWords() async throws -> [Word] {
        guard let data = UserDefaults.standard.data(forKey: wordsKey) else {
            // Return default sample words
            var allWords: [Word] = []
            allWords.append(contentsOf: Word.sampleGreetings)
            allWords.append(contentsOf: Word.sampleNumbers)
            allWords.append(contentsOf: Word.sampleFamily)
            return allWords
        }
        return try JSONDecoder().decode([Word].self, from: data)
    }
    
    func saveWords(_ words: [Word]) async throws {
        let data = try JSONEncoder().encode(words)
        UserDefaults.standard.set(data, forKey: wordsKey)
    }
    
    func getMasteredWords(for userId: String) async throws -> [Word] {
        let masteredIds = getMasteredWordIds(for: userId)
        let allWords = try await getAllWords()
        return allWords.filter { masteredIds.contains($0.id) }
    }
    
    func markWordAsMastered(_ wordId: String, for userId: String) async throws {
        var masteredIds = getMasteredWordIds(for: userId)
        if !masteredIds.contains(wordId) {
            masteredIds.append(wordId)
            saveMasteredWordIds(masteredIds, for: userId)
        }
    }
    
    func updatePracticeCount(_ wordId: String, for userId: String) async throws {
        var counts = getPracticeCounts(for: userId)
        counts[wordId] = (counts[wordId] ?? 0) + 1
        savePracticeCounts(counts, for: userId)
    }
    
    private func getMasteredWordIds(for userId: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: "\(masteredWordsKey)_\(userId)") ?? []
    }
    
    private func saveMasteredWordIds(_ ids: [String], for userId: String) {
        UserDefaults.standard.set(ids, forKey: "\(masteredWordsKey)_\(userId)")
    }
    
    private func getPracticeCounts(for userId: String) -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: "\(practiceCountKey)_\(userId)"),
              let counts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return counts
    }
    
    private func savePracticeCounts(_ counts: [String: Int], for userId: String) {
        if let data = try? JSONEncoder().encode(counts) {
            UserDefaults.standard.set(data, forKey: "\(practiceCountKey)_\(userId)")
        }
    }
}
