//
//  BookRepository.swift
//  Lengyan
//
//  Repository pattern for data access
//  Decouples data layer from presentation layer
//

import Foundation

/// Repository protocol for accessing sutra content
/// Provides a clean API for data operations
public protocol BookRepository {
    /// Get sutra tree structure
    func getSutraTree() async throws -> [SutraNode]

    /// Get sutra content by path
    func getSutra(atPath path: String) async throws -> Sutra?

    /// Get next page in sequence
    func getNextPage(from currentPath: String) async throws -> String?

    /// Get previous page in sequence
    func getPreviousPage(from currentPath: String) async throws -> String?

    /// Get all key items (navigation index)
    func getKeyItems() async throws -> [[String]]

    /// Get chapter content
    func getChapterContent(chapter: Int) async throws -> String

    /// Search sutras by name
    func searchSutras(query: String) async throws -> [Sutra]

    /// Check if sutra exists at path
    func containsSutra(atPath path: String) async throws -> Bool
}

/// Implementation of BookRepository
public final class BookRepositoryImpl: BookRepository {
    private let loader: BookLoader
    private let cache: BookCache

    public init(loader: BookLoader, cache: BookCache) {
        self.loader = loader
        self.cache = cache
    }

    // MARK: - BookRepository Implementation

    public func getSutraTree() async throws -> [SutraNode] {
        if let cached = await cache.getTree() {
            return cached
        }

        let sutras = try await loader.loadAllSutras()
        let tree = SutraNode.buildTree(from: sutras)

        await cache.setTree(tree)
        return tree
    }

    public func getSutra(atPath path: String) async throws -> Sutra? {
        if let cached = await cache.getSutra(atPath: path) {
            return cached
        }

        let sutras = try await loader.loadAllSutras()
        if let sutra = sutras.first(where: { $0.path == path }) {
            await cache.setSutra(sutra, forPath: path)
            return sutra
        }

        return nil
    }

    public func getNextPage(from currentPath: String) async throws -> String? {
        return try await withThrowingTaskGroup(of: String?.self) { group in
            // Get pagination service
            let sutras = try await loader.loadAllSutras()
            let paginationService = PaginationService(sutras: sutras)

            // Calculate next path
            let nextPath = paginationService.nextPage(from: currentPath)

            // Cache if found
            if let nextPath = nextPath {
                await cache.setNextPath(currentPath, nextPath: nextPath)
            }

            return nextPath
        }
    }

    public func getPreviousPage(from currentPath: String) async throws -> String? {
        let sutras = try await loader.loadAllSutras()
        let paginationService = PaginationService(sutras: sutras)
        let previousPath = paginationService.previousPage(from: currentPath)

        if let previousPath = previousPath {
            await cache.setPreviousPath(currentPath, previousPath: previousPath)
        }

        return previousPath
    }

    public func getKeyItems() async throws -> [[String]] {
        if let cached = await cache.getKeyItems() {
            return cached
        }

        let sutras = try await loader.loadAllSutras()
        let keyItems = sutras
            .filter { $0.type == .chapter || $0.type == .section }
            .map { [$0.path, $0.name] }

        await cache.setKeyItems(keyItems)
        return keyItems
    }

    public func getChapterContent(chapter: Int) async throws -> String {
        let sutras = try await loader.loadAllSutras()
        let chapterSutras = sutras.filter { $0.chapter == chapter }

        return chapterSutras.compactMap { $0.content }.joined(separator: "\n\n")
    }

    public func searchSutras(query: String) async throws -> [Sutra] {
        let sutras = try await loader.loadAllSutras()
        return sutras.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    public func containsSutra(atPath path: String) async throws -> Bool {
        return try await getSutra(atPath: path) != nil
    }
}

/// Mock implementation for testing
public final class MockBookRepository: BookRepository {
    private let mockTree: [SutraNode]
    private let mockSutras: [Sutra]

    public init(mockTree: [SutraNode], mockSutras: [Sutra]) {
        self.mockTree = mockTree
        self.mockSutras = mockSutras
    }

    public func getSutraTree() async throws -> [SutraNode] {
        return mockTree
    }

    public func getSutra(atPath path: String) async throws -> Sutra? {
        return mockSutras.first { $0.path == path }
    }

    public func getNextPage(from currentPath: String) async throws -> String? {
        return mockSutras.first { $0.path != currentPath }?.path
    }

    public func getPreviousPage(from currentPath: String) async throws -> String? {
        return mockSutras.first { $0.path != currentPath }?.path
    }

    public func getKeyItems() async throws -> [[String]] {
        return mockSutras.map { [$0.path, $0.name] }
    }

    public func getChapterContent(chapter: Int) async throws -> String {
        return "Mock chapter content for chapter \(chapter)"
    }

    public func searchSutras(query: String) async throws -> [Sutra] {
        return mockSutras.filter { $0.name.contains(query) }
    }

    public func containsSutra(atPath path: String) async throws -> Bool {
        return mockSutras.contains { $0.path == path }
    }
}
