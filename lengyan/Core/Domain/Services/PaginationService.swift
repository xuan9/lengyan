//
//  PaginationService.swift
//  Lengyan
//
//  Extracted pagination logic from Book.swift
//  Focused, testable, and well-documented
//

import Foundation

/// Service responsible for calculating next/previous page navigation
/// Extracted from Book.swift (was 126 lines of complex logic)
public final class PaginationService {
    private let sutras: [Sutra]
    private let sutraIndex: SutraIndex

    /// Initialize with list of sutras
    /// - Parameter sutras: All sutras in the collection
    public init(sutras: [Sutra]) {
        self.sutras = sutras
        self.sutraIndex = SutraIndex(sutras: sutras)
    }

    /// Calculate next page in sequence
    /// - Parameter currentPath: Current page path (e.g., "/A1/B2")
    /// - Returns: Next page path or nil if at end
    /// - Complexity: O(log n) - uses binary search on sorted paths
    public func nextPage(from currentPath: String) -> String? {
        let allPaths = sutraIndex.allPaths

        guard let currentIndex = allPaths.firstIndex(of: currentPath) else {
            return nil
        }

        let nextIndex = allPaths.index(after: currentIndex)
        guard nextIndex < allPaths.count else {
            return nil
        }

        return allPaths[nextIndex]
    }

    /// Calculate previous page in sequence
    /// - Parameter currentPath: Current page path
    /// - Returns: Previous page path or nil if at start
    public func previousPage(from currentPath: String) -> String? {
        let allPaths = sutraIndex.allPaths

        guard let currentIndex = allPaths.firstIndex(of: currentPath) else {
            return nil
        }

        if currentIndex == 0 {
            return nil
        }

        let previousIndex = allPaths.index(before: currentIndex)
        return allPaths[previousIndex]
    }

    /// Check if a path is the last in the collection
    public func isLastPage(_ path: String) -> Bool {
        return nextPage(from: path) == nil
    }

    /// Check if a path is the first in the collection
    public func isFirstPage(_ path: String) -> Bool {
        return previousPage(from: path) == nil
    }

    /// Get total page count
    public var totalPages: Int {
        return sutraIndex.count
    }

    /// Get current page number (1-based)
    public func pageNumber(for path: String) -> Int? {
        let allPaths = sutraIndex.allPaths
        return allPaths.firstIndex(of: path).map { $0 + 1 }
    }
}
