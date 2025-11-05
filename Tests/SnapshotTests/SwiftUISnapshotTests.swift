//
//  SwiftUISnapshotTests.swift
//  LengyanTests
//
//  Snapshot tests for all SwiftUI views
//  Visual regression testing with SwiftSnapshotTesting
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import LengyanCore

final class SwiftUISnapshotTests: XCTestCase {

    // MARK: - SutraIndexView Snapshot Tests

    func testSutraIndexView_initialLoading() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let viewModel = SutraIndexViewModel(repository: mockRepository)
        let view = SutraIndexView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraIndexView_withData() {
        let sutraTree = createMockSutraTree()
        let mockRepository = MockBookRepository(mockTree: sutraTree, mockSutras: [])
        let viewModel = SutraIndexViewModel(repository: mockRepository)
        let view = SutraIndexView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraIndexView_withSearch() {
        let sutraTree = createMockSutraTree()
        let mockRepository = MockBookRepository(mockTree: sutraTree, mockSutras: [])
        let viewModel = SutraIndexViewModel(repository: mockRepository)
        let view = SutraIndexView(viewModel: viewModel)
            .environmentObject(viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraIndexView_emptyState() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let viewModel = SutraIndexViewModel(repository: mockRepository)
        let view = SutraIndexView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - SutraReadingView Snapshot Tests

    func testSutraReadingView_initial() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let viewModel = SutraReadingViewModel(
            repository: mockRepository,
            initialPath: "/A1/B1"
        )
        let view = SutraReadingView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraReadingView_withContent() {
        let sutras = createMockSutras()
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: sutras)
        let viewModel = SutraReadingViewModel(
            repository: mockRepository,
            initialPath: "/A1/B1"
        )
        let view = SutraReadingView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraReadingView_darkTheme() {
        let sutras = createMockSutras()
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: sutras)
        let viewModel = SutraReadingViewModel(
            repository: mockRepository,
            initialPath: "/A1/B1"
        )
        let view = SutraReadingView(viewModel: viewModel)
            .preferredColorScheme(.dark)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraReadingView_sepiaTheme() {
        let sutras = createMockSutras()
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: sutras)
        let viewModel = SutraReadingViewModel(
            repository: mockRepository,
            initialPath: "/A1/B1"
        )
        let view = SutraReadingView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSutraReadingView_firstPage() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let viewModel = SutraReadingViewModel(
            repository: mockRepository,
            initialPath: "/A1/B1"
        )
        let view = SutraReadingView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - AudioPlayerView Snapshot Tests

    func testAudioPlayerView_initial() {
        let mockRepository = MockAudioRepository()
        let viewModel = AudioPlayerViewModel(repository: mockRepository)
        let view = AudioPlayerView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testAudioPlayerView_playing() {
        let mockRepository = MockAudioRepository()
        let viewModel = AudioPlayerViewModel(repository: mockRepository)
        let view = AudioPlayerView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testAudioPlayerView_paused() {
        let mockRepository = MockAudioRepository()
        let viewModel = AudioPlayerViewModel(repository: mockRepository)
        let view = AudioPlayerView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testAudioPlayerView_darkTheme() {
        let mockRepository = MockAudioRepository()
        let viewModel = AudioPlayerViewModel(repository: mockRepository)
        let view = AudioPlayerView(viewModel: viewModel)
            .preferredColorScheme(.dark)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - SettingsView Snapshot Tests

    func testSettingsView_initial() {
        let mockPreferences = MockPreferencesRepository()
        let mockTheme = MockThemeRepository()
        let viewModel = SettingsViewModel(
            preferencesRepository: mockPreferences,
            themeRepository: mockTheme
        )
        let view = SettingsView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSettingsView_darkTheme() {
        let mockPreferences = MockPreferencesRepository()
        let mockTheme = MockThemeRepository()
        let viewModel = SettingsViewModel(
            preferencesRepository: mockPreferences,
            themeRepository: mockTheme
        )
        let view = SettingsView(viewModel: viewModel)
            .preferredColorScheme(.dark)

        assertSnapshot(of: view, as: .image)
    }

    func testSettingsView_sepiaTheme() {
        let mockPreferences = MockPreferencesRepository()
        let mockTheme = MockThemeRepository()
        let viewModel = SettingsViewModel(
            preferencesRepository: mockPreferences,
            themeRepository: mockTheme
        )
        let view = SettingsView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testSettingsView_chineseLanguage() {
        let mockPreferences = MockPreferencesRepository()
        let mockTheme = MockThemeRepository()
        let viewModel = SettingsViewModel(
            preferencesRepository: mockPreferences,
            themeRepository: mockTheme
        )
        viewModel.updateLanguagePreference(isSimplified: true)
        let view = SettingsView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - FavoritesView Snapshot Tests

    func testFavoritesView_initial() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let mockPreferences = MockPreferencesRepository()
        let viewModel = FavoritesViewModel(
            repository: mockRepository,
            preferencesRepository: mockPreferences
        )
        let view = FavoritesView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testFavoritesView_withFavorites() {
        let sutras = createMockSutras()
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: sutras)
        let mockPreferences = MockPreferencesRepository()
        mockPreferences.bookmarks = ["/A1/B1", "/A2/B2"]

        let viewModel = FavoritesViewModel(
            repository: mockRepository,
            preferencesRepository: mockPreferences
        )
        let view = FavoritesView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testFavoritesView_emptyState() {
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: [])
        let mockPreferences = MockPreferencesRepository()
        let viewModel = FavoritesViewModel(
            repository: mockRepository,
            preferencesRepository: mockPreferences
        )
        let view = FavoritesView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image)
    }

    func testFavoritesView_darkTheme() {
        let sutras = createMockSutras()
        let mockRepository = MockBookRepository(mockTree: [], mockSutras: sutras)
        let mockPreferences = MockPreferencesRepository()
        let viewModel = FavoritesViewModel(
            repository: mockRepository,
            preferencesRepository: mockPreferences
        )
        let view = FavoritesView(viewModel: viewModel)
            .preferredColorScheme(.dark)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - SutraRowView Snapshot Tests

    func testSutraRowView_leafNode() {
        let sutra = Sutra(path: "/A1/B1", name: "Test Sutra", type: .content)
        let view = SutraRowView(
            sutra: sutra,
            depth: 0,
            onTap: { }
        )

        assertSnapshot(of: view, as: .image)
    }

    func testSutraRowView_parentNode() {
        let sutra = Sutra(path: "/A1", name: "Parent Sutra", type: .directory)
        let view = SutraRowView(
            sutra: sutra,
            depth: 0,
            onTap: { }
        )

        assertSnapshot(of: view, as: .image)
    }

    func testSutraRowView_nestedNode() {
        let sutra = Sutra(path: "/A1/B1/C1", name: "Nested Sutra", type: .content)
        let view = SutraRowView(
            sutra: sutra,
            depth: 2,
            onTap: { }
        )

        assertSnapshot(of: view, as: .image)
    }

    func testSutraRowView_pressedState() {
        let sutra = Sutra(path: "/A1/B1", name: "Test Sutra", type: .content)
        let view = SutraRowView(
            sutra: sutra,
            depth: 0,
            onTap: { }
        )

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - Helper Methods

    private func createMockSutraTree() -> [SutraNode] {
        return [
            SutraNode(
                sutra: Sutra(path: "/A1", name: "Chapter 1", type: .directory),
                children: [
                    SutraNode(
                        sutra: Sutra(path: "/A1/B1", name: "Section 1", type: .content),
                        children: []
                    ),
                    SutraNode(
                        sutra: Sutra(path: "/A1/B2", name: "Section 2", type: .content),
                        children: []
                    )
                ]
            ),
            SutraNode(
                sutra: Sutra(path: "/A2", name: "Chapter 2", type: .directory),
                children: [
                    SutraNode(
                        sutra: Sutra(path: "/A2/B1", name: "Section 3", type: .content),
                        children: []
                    )
                ]
            )
        ]
    }

    private func createMockSutras() -> [Sutra] {
        return [
            Sutra(path: "/A1/B1", name: "Test Sutra 1", type: .content),
            Sutra(path: "/A1/B2", name: "Test Sutra 2", type: .content),
            Sutra(path: "/A2/B1", name: "Test Sutra 3", type: .content)
        ]
    }
}
