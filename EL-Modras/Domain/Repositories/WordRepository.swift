//
//  WordRepository.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

protocol WordRepository {
    func getAllWords() async throws -> [Word]
    func getWord(by id: String) async throws -> Word?
    func getWords(for category: LessonCategory) async throws -> [Word]
    func getWords(for lessonId: String) async throws -> [Word]
    func searchWords(query: String) async throws -> [Word]
    func getMasteredWords(for userId: String) async throws -> [Word]
    func markWordAsMastered(_ wordId: String, for userId: String) async throws
    func updatePracticeCount(_ wordId: String, for userId: String) async throws
}
