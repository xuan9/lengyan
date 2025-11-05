//
//  SutraReadingViewModel.swift
//  Lengyan
//
//  ViewModel for sutra reading view
//  Handles pagination, content loading, and state
//

import SwiftUI

/// ViewModel for reading sutra content
/// Reactive, testable, MVVM pattern
@MainActor
public final class SutraReadingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentSutra: Sutra?
    @Published var currentContent: String = ""
    @Published var currentPath: String
    @Published var hasNextPage: Bool = false
    @Published var hasPreviousPage: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    var pageInfo: String {
        guard let sutra = currentSutra else { return "" }
        return "\(sutra.name)"
    }

    // MARK: - Dependencies

    private let repository: BookRepository
    private let paginationService: PaginationService?

    // MARK: - Initialization

    public init(
        repository: BookRepository,
        initialPath: String
    ) {
        self.repository = repository
        self.currentPath = initialPath
        self.paginationService = nil
    }

    public init(
        repository: BookRepository,
        initialPath: String,
        sutras: [Sutra]
    ) {
        self.repository = repository
        self.currentPath = initialPath
        self.paginationService = PaginationService(sutras: sutras)
    }

    // MARK: - Public Methods

    /// Load sutra at specific path
    public func loadSutra(at path: String) async {
        do {
            guard let sutra = try await repository.getSutra(atPath: path) else {
                showError("Sutra not found at path: \(path)")
                return
            }

            currentSutra = sutra
            currentContent = sutra.content ?? "No content available"
            currentPath = path

            await updateNavigationState()
        } catch {
            showError("Failed to load sutra: \(error.localizedDescription)")
        }
    }

    /// Navigate to next page
    public func goToNextPage() async {
        guard let nextPath = await getNextPagePath() else {
            return
        }

        await loadSutra(at: nextPath)
    }

    /// Navigate to previous page
    public func goToPreviousPage() async {
        guard let previousPath = await getPreviousPagePath() else {
            return
        }

        await loadSutra(at: previousPath)
    }

    /// Toggle bookmark
    public func toggleBookmark() {
        // Implementation for bookmarking
        // Will be added in future phase
    }

    // MARK: - Private Methods

    private func getNextPagePath() async -> String? {
        if let paginationService = paginationService {
            return paginationService.nextPage(from: currentPath)
        } else {
            do {
                return try await repository.getNextPage(from: currentPath)
            } catch {
                showError("Failed to get next page: \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func getPreviousPagePath() async -> String? {
        if let paginationService = paginationService {
            return paginationService.previousPage(from: currentPath)
        } else {
            do {
                return try await repository.getPreviousPage(from: currentPath)
            } catch {
                showError("Failed to get previous page: \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func updateNavigationState() async {
        let nextPath = await getNextPagePath()
        let previousPath = await getPreviousPagePath()

        hasNextPage = nextPath != nil
        hasPreviousPage = previousPath != nil
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
