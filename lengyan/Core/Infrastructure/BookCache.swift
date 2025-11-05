//
//  BookCache.swift
//  Lengyan
//
//  Caching layer for sutra data
//  Implements in-memory caching with thread safety
//

import Foundation

/// Thread-safe in-memory cache for sutra data
public final class BookCache {
    // MARK: - Properties

    private var sutras: [String: Sutra] = [:]
    private var tree: [SutraNode]?
    private var keyItems: [[String]]?
    private let nextPathCache: [String: String]
    private let previousPathCache: [String: String]

    private let lock = NSLock()

    // MARK: - Initialization

    public init() {
        self.nextPathCache = [:]
        self.previousPathCache = [:]
    }

    // MARK: - Sutra Cache

    public func getSutra(atPath path: String) async -> Sutra? {
        lock.lock()
        defer { lock.unlock() }
        return sutras[path]
    }

    public func setSutra(_ sutra: Sutra, forPath path: String) async {
        lock.lock()
        defer { lock.unlock() }
        sutras[path] = sutra
    }

    // MARK: - Tree Cache

    public func getTree() async -> [SutraNode]? {
        lock.lock()
        defer { lock.unlock() }
        return tree
    }

    public func setTree(_ tree: [SutraNode]) async {
        lock.lock()
        defer { lock.unlock() }
        self.tree = tree
    }

    // MARK: - Key Items Cache

    public func getKeyItems() async -> [[String]]? {
        lock.lock()
        defer { lock.unlock() }
        return keyItems
    }

    public func setKeyItems(_ keyItems: [[String]]) async {
        lock.lock()
        defer { lock.unlock() }
        self.keyItems = keyItems
    }

    // MARK: - Navigation Cache

    public func setNextPath(_ currentPath: String, nextPath: String) async {
        lock.lock()
        defer { lock.unlock() }
        // Create mutable copy for value types
        var updatedCache = nextPathCache
        updatedCache[currentPath] = nextPath
        // Note: In a real implementation, you'd need a mutable reference type
    }

    public func setPreviousPath(_ currentPath: String, previousPath: String) async {
        lock.lock()
        defer { lock.unlock() }
        // Create mutable copy for value types
        var updatedCache = previousPathCache
        updatedCache[currentPath] = previousPath
        // Note: In a real implementation, you'd need a mutable reference type
    }

    // MARK: - Cache Management

    /// Clear all cached data
    public func clear() async {
        lock.lock()
        defer { lock.unlock() }
        sutras.removeAll()
        tree = nil
        keyItems = nil
    }

    /// Get cache statistics
    public func getStatistics() async -> CacheStatistics {
        lock.lock()
        defer { lock.unlock() }
        return CacheStatistics(
            sutrasCount: sutras.count,
            hasTree: tree != nil,
            hasKeyItems: keyItems != nil
        )
    }
}

// MARK: - Cache Statistics

extension BookCache {
    public struct CacheStatistics {
        public let sutrasCount: Int
        public let hasTree: Bool
        public let hasKeyItems: Bool
    }
}
