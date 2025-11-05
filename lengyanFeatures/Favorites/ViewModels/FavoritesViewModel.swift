//
//  FavoritesViewModel.swift
//  Lengyan
//
//  ViewModel for favorites view
//  Manages bookmarked sutras
//

import SwiftUI

/// ViewModel for favorites view
@MainActor
public final class FavoritesViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var favorites: [Sutra] = []
    @Published var isLoading: Bool = false

    // MARK: - Dependencies

    private let repository: BookRepository
    private let preferencesRepository: PreferencesRepository

    // MARK: - Initialization

    public init(
        repository: BookRepository,
        preferencesRepository: PreferencesRepository
    ) {
        self.repository = repository
        self.preferencesRepository = preferencesRepository
    }

    public init(
        repository: BookRepository,
        bookmarks: [String]
    ) {
        self.repository = repository
        self.preferencesRepository = PreferencesRepositoryImpl()
        // Load specific bookmarks for preview
        Task {
            await loadSpecificFavorites(bookmarks: bookmarks)
        }
    }

    // MARK: - Public Methods

    /// Load favorites from preferences
    public func loadFavorites() {
        isLoading = true

        Task {
            let bookmarks = preferencesRepository.bookmarks
            let sutras = await loadSutras(from: bookmarks)

            await MainActor.run {
                self.favorites = sutras
                self.isLoading = false
            }
        }
    }

    /// Add sutra to favorites
    public func addFavorite(_ sutra: Sutra) {
        var bookmarks = preferencesRepository.bookmarks

        if !bookmarks.contains(sutra.path) {
            bookmarks.append(sutra.path)
            preferencesRepository.bookmarks = bookmarks
            preferencesRepository.save()

            favorites.append(sutra)
        }
    }

    /// Remove sutra from favorites
    public func removeFavorite(_ sutra: Sutra) {
        removeFavorite(sutra)
    }

    /// Remove favorite at index
    public func removeFavorite(at offsets: IndexSet) {
        let pathsToRemove = offsets.map { favorites[$0].path }
        var bookmarks = preferencesRepository.bookmarks

        for path in pathsToRemove {
            bookmarks.removeAll { $0 == path }
        }

        preferencesRepository.bookmarks = bookmarks
        preferencesRepository.save()

        favorites.remove(atOffsets: offsets)
    }

    /// Clear all favorites
    public func clearAllFavorites() {
        preferencesRepository.bookmarks = []
        preferencesRepository.save()

        favorites.removeAll()
    }

    /// Open sutra for reading
    public func openSutra(_ sutra: Sutra) {
        // Implementation depends on coordinator pattern
        // Will navigate to reading view
    }

    /// Check if sutra is favorited
    public func isFavorite(_ sutra: Sutra) -> Bool {
        return favorites.contains { $0.path == sutra.path }
    }

    // MARK: - Private Methods

    private func loadSutras(from paths: [String]) async -> [Sutra] {
        var sutras: [Sutra] = []

        for path in paths {
            if let sutra = try? await repository.getSutra(atPath: path) {
                sutras.append(sutra)
            }
        }

        return sutras
    }

    private func loadSpecificFavorites(bookmarks: [String]) async {
        let sutras = await loadSutras(from: bookmarks)

        await MainActor.run {
            self.favorites = sutras
        }
    }

    private func removeFavorite(_ sutra: Sutra) {
        var bookmarks = preferencesRepository.bookmarks
        bookmarks.removeAll { $0 == sutra.path }
        preferencesRepository.bookmarks = bookmarks
        preferencesRepository.save()

        favorites.removeAll { $0.path == sutra.path }
    }
}
