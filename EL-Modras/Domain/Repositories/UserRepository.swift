//
//  UserRepository.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

protocol UserRepository {
    func getCurrentUser() async throws -> User?
    func saveUser(_ user: User) async throws
    func updateUser(_ user: User) async throws
    func deleteUser(_ userId: String) async throws
    func updatePreferences(_ preferences: UserPreferences, for userId: String) async throws
    func updateArabicLevel(_ level: ArabicLevel, for userId: String) async throws
}
