//
//  FavoritesViewModelTests.swift
//  LengyanTests
//
//  Comprehensive tests for FavoritesViewModel
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class FavoritesViewModelTests: QuickSpec {
    override class func spec() {
        describe("FavoritesViewModel") {
            var mockRepository: MockBookRepository!
            var mockPreferencesRepository: MockPreferencesRepository!
            var viewModel: FavoritesViewModel!

            beforeEach {
                mockRepository = MockBookRepository(
                    mockTree: [],
                    mockSutras: []
                )
                mockPreferencesRepository = MockPreferencesRepository()
                viewModel = FavoritesViewModel(
                    repository: mockRepository,
                    preferencesRepository: mockPreferencesRepository
                )
            }

            // MARK: - Initialization Tests

            describe("initialization") {
                it("should start with empty favorites") {
                    expect(viewModel.favorites).to(beEmpty())
                    expect(viewModel.isLoading).to(beFalse())
                }

                it("should initialize with bookmarks") {
                    let bookmarks = ["/A1/B1", "/A2/B2"]
                    let sutra1 = Sutra(path: "/A1/B1", name: "Test 1", type: .content)
                    let sutra2 = Sutra(path: "/A2/B2", name: "Test 2", type: .content)

                    mockRepository.mockSutras = [sutra1, sutra2]

                    let vmWithBookmarks = FavoritesViewModel(
                        repository: mockRepository,
                        bookmarks: bookmarks
                    )

                    // Wait for async loading
                    expect(vmWithBookmarks.favorites.isEmpty).toEventually(beFalse(), timeout: .milliseconds(500))
                }
            }

            // MARK: - Load Favorites Tests

            describe("loadFavorites()") {
                it("should load favorites from preferences") {
                    let bookmarks = ["/A1/B1", "/A2/B2"]
                    mockPreferencesRepository.bookmarks = bookmarks

                    let sutra1 = Sutra(path: "/A1/B1", name: "Favorite 1", type: .content)
                    let sutra2 = Sutra(path: "/A2/B2", name: "Favorite 2", type: .content)
                    mockRepository.mockSutras = [sutra1, sutra2]

                    viewModel.loadFavorites()

                    expect(viewModel.favorites.count).toEventually(equal(2), timeout: .milliseconds(500))
                    expect(viewModel.favorites.first?.name).toEventually(equal("Favorite 1"))
                }

                it("should handle non-existent paths") {
                    mockPreferencesRepository.bookmarks = ["/NonExistent"]
                    mockRepository.mockSutras = []

                    viewModel.loadFavorites()

                    expect(viewModel.favorites).toEventually(beEmpty(), timeout: .milliseconds(500))
                }

                it("should set loading state") {
                    mockPreferencesRepository.bookmarks = ["/A1/B1"]
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)
                    mockRepository.mockSutras = [sutra]

                    expect(viewModel.isLoading).to(beFalse())

                    viewModel.loadFavorites()

                    expect(viewModel.isLoading).toEventually(beTrue(), timeout: .milliseconds(100))
                    expect(viewModel.isLoading).toEventually(beFalse(), timeout: .milliseconds(500))
                }

                it("should handle empty bookmarks list") {
                    mockPreferencesRepository.bookmarks = []

                    viewModel.loadFavorites()

                    expect(viewModel.favorites).toEventually(beEmpty(), timeout: .milliseconds(500))
                }
            }

            // MARK: - Add Favorite Tests

            describe("addFavorite(_:)") {
                it("should add sutra to favorites") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)

                    viewModel.addFavorite(sutra)

                    expect(viewModel.favorites.count).to(equal(1))
                    expect(viewModel.favorites.first).to(equal(sutra))
                    expect(mockPreferencesRepository.bookmarks).to(contain("/A1/B1"))
                }

                it("should not add duplicate favorites") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)
                    viewModel.addFavorite(sutra)
                    mockPreferencesRepository.bookmarks.removeAll()

                    viewModel.addFavorite(sutra)

                    expect(viewModel.favorites.count).to(equal(1))
                }

                it("should persist favorites to preferences") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)

                    viewModel.addFavorite(sutra)

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }

                it("should add multiple favorites") {
                    let sutra1 = Sutra(path: "/A1/B1", name: "Test 1", type: .content)
                    let sutra2 = Sutra(path: "/A2/B2", name: "Test 2", type: .content)

                    viewModel.addFavorite(sutra1)
                    viewModel.addFavorite(sutra2)

                    expect(viewModel.favorites.count).to(equal(2))
                    expect(mockPreferencesRepository.bookmarks.count).to(equal(2))
                }
            }

            // MARK: - Remove Favorite Tests

            describe("removeFavorite(_:)") {
                beforeEach {
                    let sutra1 = Sutra(path: "/A1/B1", name: "Test 1", type: .content)
                    let sutra2 = Sutra(path: "/A2/B2", name: "Test 2", type: .content)
                    viewModel.addFavorite(sutra1)
                    viewModel.addFavorite(sutra2)
                }

                it("should remove sutra from favorites") {
                    let sutraToRemove = viewModel.favorites.first!

                    viewModel.removeFavorite(sutraToRemove)

                    expect(viewModel.favorites.count).to(equal(1))
                    expect(viewModel.favorites.first?.path).toNot(equal(sutraToRemove.path))
                }

                it("should remove from preferences") {
                    let sutraToRemove = viewModel.favorites.first!

                    viewModel.removeFavorite(sutraToRemove)

                    expect(mockPreferencesRepository.bookmarks).toNot(contain(sutraToRemove.path))
                }

                it("should persist removal") {
                    let sutraToRemove = viewModel.favorites.first!

                    viewModel.removeFavorite(sutraToRemove)

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }

                it("should handle removing non-existent favorite") {
                    let nonExistentSutra = Sutra(path: "/NonExistent", name: "NonExistent", type: .content)

                    viewModel.removeFavorite(nonExistentSutra)

                    expect(viewModel.favorites.count).to(equal(2)) // No change
                }
            }

            // MARK: - Remove Favorite at Offset Tests

            describe("removeFavorite(at:)") {
                beforeEach {
                    let sutras = [
                        Sutra(path: "/A1/B1", name: "Test 1", type: .content),
                        Sutra(path: "/A2/B2", name: "Test 2", type: .content),
                        Sutra(path: "/A3/B3", name: "Test 3", type: .content)
                    ]
                    for sutra in sutras {
                        viewModel.addFavorite(sutra)
                    }
                }

                it("should remove favorite at specific offset") {
                    let offsets = IndexSet(integer: 1)

                    viewModel.removeFavorite(at: offsets)

                    expect(viewModel.favorites.count).to(equal(2))
                    expect(viewModel.favorites.map { $0.path }).toNot(contain("/A2/B2"))
                }

                it("should handle multiple offsets") {
                    let offsets = IndexSet(arrayLiteral: 0, 2)

                    viewModel.removeFavorite(at: offsets)

                    expect(viewModel.favorites.count).to(equal(1))
                    expect(viewModel.favorites.first?.path).to(equal("/A2/B2"))
                }

                it("should remove from preferences") {
                    let offsets = IndexSet(integer: 0)

                    viewModel.removeFavorite(at: offsets)

                    expect(mockPreferencesRepository.bookmarks).toNot(contain("/A1/B1"))
                }

                it("should persist removal") {
                    let offsets = IndexSet(integer: 0)

                    viewModel.removeFavorite(at: offsets)

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }
            }

            // MARK: - Clear All Favorites Tests

            describe("clearAllFavorites()") {
                beforeEach {
                    let sutras = [
                        Sutra(path: "/A1/B1", name: "Test 1", type: .content),
                        Sutra(path: "/A2/B2", name: "Test 2", type: .content)
                    ]
                    for sutra in sutras {
                        viewModel.addFavorite(sutra)
                    }
                }

                it("should remove all favorites") {
                    expect(viewModel.favorites.count).to(beGreaterThan(0))

                    viewModel.clearAllFavorites()

                    expect(viewModel.favorites).to(beEmpty())
                }

                it("should clear preferences") {
                    viewModel.clearAllFavorites()

                    expect(mockPreferencesRepository.bookmarks).to(beEmpty())
                }

                it("should persist clearing") {
                    viewModel.clearAllFavorites()

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }

                it("should handle clearing empty favorites") {
                    viewModel.clearAllFavorites()
                    viewModel.clearAllFavorites() // Clear again

                    expect(viewModel.favorites).to(beEmpty())
                }
            }

            // MARK: - Open Sutra Tests

            describe("openSutra(_:)") {
                it("should handle opening sutra") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)

                    // This would normally navigate to reading view
                    // For now, we just verify it doesn't crash
                    viewModel.openSutra(sutra)

                    // In real implementation, coordinator would handle navigation
                }
            }

            // MARK: - Is Favorite Tests

            describe("isFavorite(_:)") {
                beforeEach {
                    let sutra1 = Sutra(path: "/A1/B1", name: "Test 1", type: .content)
                    let sutra2 = Sutra(path: "/A2/B2", name: "Test 2", type: .content)

                    viewModel.addFavorite(sutra1)
                }

                it("should return true for favorited sutra") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test 1", type: .content)

                    let isFavorite = viewModel.isFavorite(sutra)

                    expect(isFavorite).to(beTrue())
                }

                it("should return false for non-favorited sutra") {
                    let sutra = Sutra(path: "/A2/B2", name: "Test 2", type: .content)

                    let isFavorite = viewModel.isFavorite(sutra)

                    expect(isFavorite).to(beFalse())
                }

                it("should return false for sutra not in favorites list") {
                    let sutra = Sutra(path: "/A3/B3", name: "Test 3", type: .content)

                    let isFavorite = viewModel.isFavorite(sutra)

                    expect(isFavorite).to(beFalse())
                }
            }

            // MARK: - Edge Cases

            describe("edge cases") {
                it("should handle sutra with empty path") {
                    let sutra = Sutra(path: "", name: "Empty", type: .content)

                    viewModel.addFavorite(sutra)

                    expect(viewModel.favorites.count).to(equal(1))
                }

                it("should handle sutra with special characters in path") {
                    let sutra = Sutra(path: "/A1/B1/C1", name: "Test/With:Special", type: .content)

                    viewModel.addFavorite(sutra)

                    expect(viewModel.favorites.count).to(equal(1))
                    expect(viewModel.isFavorite(sutra)).to(beTrue())
                }

                it("should handle rapid add/remove operations") {
                    let sutra = Sutra(path: "/A1/B1", name: "Test", type: .content)

                    viewModel.addFavorite(sutra)
                    viewModel.removeFavorite(sutra)
                    viewModel.addFavorite(sutra)

                    expect(viewModel.favorites.count).to(equal(1))
                    expect(viewModel.isFavorite(sutra)).to(beTrue())
                }
            }

            // MARK: - Integration Tests

            describe("integration with repositories") {
                it("should work with real repository and preferences") {
                    let repository = BookRepositoryImpl(
                        loader: BookLoader(),
                        cache: BookCache()
                    )
                    let preferences = PreferencesRepositoryImpl()

                    let integratedViewModel = FavoritesViewModel(
                        repository: repository,
                        preferencesRepository: preferences
                    )

                    let sutra = Sutra(path: "/Test", name: "Test", type: .content)
                    integratedViewModel.addFavorite(sutra)

                    expect(integratedViewModel.favorites.count).to(equal(1))
                    expect(preferences.bookmarks).to(contain("/Test"))
                }
            }
        }
    }
}

// MARK: - Mock Implementation

class MockPreferencesRepository: PreferencesRepository {
    var isSimplifiedChinese: Bool = false
    var readingProgress: [String: Double] = [:]
    var bookmarks: [String] = []
    var saveCalled = false

    func save() {
        saveCalled = true
    }
}
