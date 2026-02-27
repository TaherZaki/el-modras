//
//  UserRepositoryImpl.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation

final class UserRepositoryImpl: UserRepository {
    private let remoteDataSource: UserRemoteDataSource
    private let localDataSource: UserLocalDataSource
    
    init(remoteDataSource: UserRemoteDataSource, localDataSource: UserLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getCurrentUser() async throws -> User? {
        // Try local first
        if let localUser = try await localDataSource.getUser() {
            return localUser
        }
        
        // Fetch from remote
        if let remoteUser = try await remoteDataSource.fetchCurrentUser() {
            try await localDataSource.saveUser(remoteUser)
            return remoteUser
        }
        
        return nil
    }
    
    func saveUser(_ user: User) async throws {
        try await localDataSource.saveUser(user)
        try await remoteDataSource.saveUser(user)
    }
    
    func updateUser(_ user: User) async throws {
        try await localDataSource.saveUser(user)
        try await remoteDataSource.updateUser(user)
    }
    
    func deleteUser(_ userId: String) async throws {
        try await localDataSource.deleteUser()
        try await remoteDataSource.deleteUser(userId)
    }
    
    func updatePreferences(_ preferences: UserPreferences, for userId: String) async throws {
        var user = try await getCurrentUser()
        user?.preferences = preferences
        if let user = user {
            try await updateUser(user)
        }
    }
    
    func updateArabicLevel(_ level: ArabicLevel, for userId: String) async throws {
        var user = try await getCurrentUser()
        user?.arabicLevel = level
        if let user = user {
            try await updateUser(user)
        }
    }
}

// MARK: - Remote Data Source
final class UserRemoteDataSource {
    private let baseURL = AppConfig.backendURL
    
    func fetchCurrentUser() async throws -> User? {
        // In production, this would fetch from Firestore
        // For now, return nil to use local storage
        return nil
    }
    
    func saveUser(_ user: User) async throws {
        let url = URL(string: "\(baseURL)/api/v1/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(user)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RepositoryError.saveFailed
        }
    }
    
    func updateUser(_ user: User) async throws {
        let url = URL(string: "\(baseURL)/api/v1/users/\(user.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(user)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RepositoryError.updateFailed
        }
    }
    
    func deleteUser(_ userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RepositoryError.deleteFailed
        }
    }
}

// MARK: - Local Data Source
final class UserLocalDataSource {
    private let userDefaultsKey = "current_user"
    
    func getUser() async throws -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    func saveUser(_ user: User) async throws {
        let data = try JSONEncoder().encode(user)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    func deleteUser() async throws {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Repository Errors
enum RepositoryError: Error, LocalizedError {
    case notFound
    case saveFailed
    case updateFailed
    case deleteFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notFound: return "Resource not found"
        case .saveFailed: return "Failed to save"
        case .updateFailed: return "Failed to update"
        case .deleteFailed: return "Failed to delete"
        case .networkError: return "Network error occurred"
        }
    }
}
