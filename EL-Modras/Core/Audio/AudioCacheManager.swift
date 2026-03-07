//
//  AudioCacheManager.swift
//  EL-Modras
//
//  Manages caching of audio files for instant playback
//

import Foundation

// MARK: - Audio Cache Manager
final class AudioCacheManager {
    
    static let shared = AudioCacheManager()
    
    // Cache version - increment this to force clear old cache (e.g. when switching TTS voice)
    private static let cacheVersion = 2  // v2 = Gemini TTS Orus voice (WAV)
    private static let cacheVersionKey = "AudioCacheVersion"
    
    // Memory cache for quick access
    private var memoryCache: [String: Data] = [:]
    private let memoryCacheLimit = 50 // Max items in memory
    
    // File manager for disk cache
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Queue for thread safety
    private let queue = DispatchQueue(label: "com.elmodras.audiocache", attributes: .concurrent)
    
    private init() {
        // Create cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("AudioCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Check cache version - clear old cache if version changed
        let savedVersion = UserDefaults.standard.integer(forKey: AudioCacheManager.cacheVersionKey)
        if savedVersion != AudioCacheManager.cacheVersion {
            print("🔄 Cache version changed (\(savedVersion) → \(AudioCacheManager.cacheVersion)), clearing old audio cache...")
            clearAllCacheSync()
            UserDefaults.standard.set(AudioCacheManager.cacheVersion, forKey: AudioCacheManager.cacheVersionKey)
        }
        
        print("📁 Audio cache directory: \(cacheDirectory.path)")
    }
    
    // MARK: - Cache Key Generation
    
    func cacheKey(for text: String, type: AudioType) -> String {
        let sanitized = text
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "\(type.rawValue)_\(sanitized)"
    }
    
    // MARK: - Check Cache
    
    func hasAudio(for text: String, type: AudioType) -> Bool {
        let key = cacheKey(for: text, type: type)
        
        // Check memory first
        if memoryCache[key] != nil {
            return true
        }
        
        // Check disk
        let fileURL = cacheDirectory.appendingPathComponent("\(key).wav")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Get Audio
    
    func getAudio(for text: String, type: AudioType) -> Data? {
        let key = cacheKey(for: text, type: type)
        
        // Check memory cache first
        if let data = memoryCache[key] {
            print("✅ Audio from memory cache: \(text)")
            return data
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(key).wav")
        if let data = try? Data(contentsOf: fileURL) {
            // Add to memory cache
            queue.async(flags: .barrier) { [weak self] in
                self?.addToMemoryCache(key: key, data: data)
            }
            print("✅ Audio from disk cache: \(text)")
            return data
        }
        
        print("❌ Audio not in cache: \(text)")
        return nil
    }
    
    // MARK: - Save Audio
    
    func saveAudio(_ data: Data, for text: String, type: AudioType) {
        let key = cacheKey(for: text, type: type)
        
        // Save to memory
        queue.async(flags: .barrier) { [weak self] in
            self?.addToMemoryCache(key: key, data: data)
        }
        
        // Save to disk
        let fileURL = cacheDirectory.appendingPathComponent("\(key).wav")
        do {
            try data.write(to: fileURL)
            print("💾 Audio saved to cache: \(text)")
        } catch {
            print("❌ Failed to save audio: \(error)")
        }
    }
    
    // MARK: - Memory Cache Management
    
    private func addToMemoryCache(key: String, data: Data) {
        // Remove oldest if at limit
        if memoryCache.count >= memoryCacheLimit {
            if let firstKey = memoryCache.keys.first {
                memoryCache.removeValue(forKey: firstKey)
            }
        }
        memoryCache[key] = data
    }
    
    // MARK: - Clear Cache
    
    func clearMemoryCache() {
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAll()
        }
        print("🧹 Memory cache cleared")
    }
    
    func clearDiskCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("🧹 Disk cache cleared")
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }
    
    func clearAllCache() {
        clearMemoryCache()
        clearDiskCache()
    }
    
    /// Synchronous version for use during init
    private func clearAllCacheSync() {
        memoryCache.removeAll()
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("🧹 Old cache cleared successfully")
        } catch {
            print("❌ Failed to clear old cache: \(error)")
        }
    }
    
    // MARK: - Cache Size
    
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                size += (attributes[.size] as? Int64) ?? 0
            }
        } catch {
            print("❌ Failed to get cache size: \(error)")
        }
        return size
    }
    
    func getCacheSizeFormatted() -> String {
        let bytes = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Audio Type
enum AudioType: String {
    case word = "word"
    case sentence = "sentence"
    case response = "response"
    case instruction = "instruction"
}
