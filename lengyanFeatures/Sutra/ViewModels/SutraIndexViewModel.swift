//
//  SutraIndexViewModel.swift
//  Lengyan
//
//  ViewModel for SutraIndexView
//  <200 lines, pure Swift, 100% testable
//

import SwiftUI
import Combine

/// ViewModel for sutra index view
/// Reactive, testable, no UI code
@MainActor
public final class SutraIndexViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var sutraTree: [SutraNode] = []
    @Published var navigationPath: [SutraNode] = []
    @Published var showingError: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let repository: BookRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(repository: BookRepository) {
        self.repository = repository
    }

    // MARK: - Public Methods

    /// Load sutra tree from repository
    public func loadSutraTree() async {
        do {
            let tree = try await repository.getSutraTree()
            sutraTree = tree
        } catch {
            showError("Failed to load sutras: \(error.localizedDescription)")
        }
    }

    /// Handle sutra selection
    public func selectSutra(_ sutra: Sutra) {
        if sutra.hasChildren {
            navigateToChildren(of: sutra)
        } else if sutra.hasContent {
            openSutra(sutra)
        }
    }

    /// Set theme preference
    public func setTheme(_ theme: ThemeType) {
        // Implementation for theme setting
        UserDefaults.standard.set(theme.rawValue, forKey: "CurrentTheme")
    }

    /// Search sutras
    public func searchSutras(query: String) async {
        guard !query.isEmpty else {
            sutraTree = []
            return
        }

        do {
            let results = try await repository.searchSutras(query: query)
            // Update search results
            // This is a simplified implementation
        } catch {
            showError("Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func navigateToChildren(of sutra: Sutra) {
        // Find node in tree and navigate
        // Implementation depends on tree structure
    }

    private func openSutra(_ sutra: Sutra) {
        // Navigate to reading view
        // Will be implemented with coordinator pattern
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Theme Type

extension SutraIndexViewModel {
    public enum ThemeType: String, CaseIterable {
        case light
        case sepia
        case dark
    }
}
