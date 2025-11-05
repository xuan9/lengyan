//
//  SutraReadingViewModelTests.swift
//  LengyanTests
//
//  Comprehensive tests for SutraReadingViewModel
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class SutraReadingViewModelTests: QuickSpec {
    override class func spec() {
        describe("SutraReadingViewModel") {
            var mockRepository: MockBookRepository!
            var viewModel: SutraReadingViewModel!

            beforeEach {
                let mockSutras = [
                    Sutra(path: "/A1/B1/C1", name: "First", type: .content, content: "Content 1"),
                    Sutra(path: "/A1/B1/C2", name: "Second", type: .content, content: "Content 2"),
                    Sutra(path: "/A1/B1/C3", name: "Third", type: .content, content: "Content 3"),
                ]
                mockRepository = MockBookRepository(mockTree: [], mockSutras: mockSutras)
                viewModel = SutraReadingViewModel(
                    repository: mockRepository,
                    initialPath: "/A1/B1/C2",
                    sutras: mockSutras
                )
            }

            // MARK: - Loading Tests

            describe("loadSutra(at:)") {
                it("should load sutra successfully") {
                    await viewModel.loadSutra(at: "/A1/B1/C1")

                    expect(viewModel.currentSutra).toNot(beNil())
                    expect(viewModel.currentSutra?.path).to(equal("/A1/B1/C1"))
                    expect(viewModel.currentContent).to(equal("Content 1"))
                }

                it("should update current path") {
                    await viewModel.loadSutra(at: "/A1/B1/C2")

                    expect(viewModel.currentPath).to(equal("/A1/B1/C2"))
                }

                it("should show error when sutra not found") {
                    await viewModel.loadSutra(at: "/NonExistent")

                    expect(viewModel.showingError).to(beTrue())
                    expect(viewModel.errorMessage).toNot(beNil())
                }
            }

            // MARK: - Navigation Tests

            describe("goToNextPage()") {
                context("when next page exists") {
                    it("should navigate to next page") {
                        await viewModel.loadSutra(at: "/A1/B1/C1")

                        await viewModel.goToNextPage()

                        expect(viewModel.currentPath).to(equal("/A1/B1/C2"))
                    }
                }

                context("when at last page") {
                    it("should not navigate beyond last page") {
                        await viewModel.loadSutra(at: "/A1/B1/C3")

                        await viewModel.goToNextPage()

                        expect(viewModel.currentPath).to(equal("/A1/B1/C3"))
                        expect(viewModel.hasNextPage).to(beFalse())
                    }
                }

                it("should update navigation state") {
                    await viewModel.loadSutra(at: "/A1/B1/C1")

                    await viewModel.goToNextPage()

                    expect(viewModel.hasNextPage).to(beTrue())
                    expect(viewModel.hasPreviousPage).to(beTrue())
                }
            }

            describe("goToPreviousPage()") {
                context("when previous page exists") {
                    it("should navigate to previous page") {
                        await viewModel.loadSutra(at: "/A1/B1/C2")

                        await viewModel.goToPreviousPage()

                        expect(viewModel.currentPath).to(equal("/A1/B1/C1"))
                    }
                }

                context("when at first page") {
                    it("should not navigate before first page") {
                        await viewModel.loadSutra(at: "/A1/B1/C1")

                        await viewModel.goToPreviousPage()

                        expect(viewModel.currentPath).to(equal("/A1/B1/C1"))
                        expect(viewModel.hasPreviousPage).to(beFalse())
                    }
                }

                it("should update navigation state") {
                    await viewModel.loadSutra(at: "/A1/B1/C2")

                    await viewModel.goToPreviousPage()

                    expect(viewModel.hasPreviousPage).to(beFalse())
                    expect(viewModel.hasNextPage).to(beTrue())
                }
            }

            // MARK: - Computed Properties Tests

            describe("pageInfo") {
                it("should return sutra name") {
                    viewModel.currentSutra = Sutra(
                        path: "/A1/B1/C1",
                        name: "Test Sutra",
                        type: .content
                    )

                    expect(viewModel.pageInfo).to(equal("Test Sutra"))
                }

                it("should handle nil currentSutra") {
                    viewModel.currentSutra = nil

                    expect(viewModel.pageInfo).to(equal(""))
                }
            }

            // MARK: - Bookmark Tests

            describe("toggleBookmark()") {
                it("should toggle bookmark state") {
                    // Implementation for bookmarking
                    // Will be added in future phase

                    viewModel.toggleBookmark()

                    // Should update bookmark state
                }
            }

            // MARK: - Edge Cases

            describe("edge cases") {
                it("should handle empty content") {
                    let sutraWithEmptyContent = Sutra(
                        path: "/Empty",
                        name: "Empty",
                        type: .content,
                        content: nil
                    )
                    mockRepository.mockSutras.append(sutraWithEmptyContent)

                    await viewModel.loadSutra(at: "/Empty")

                    expect(viewModel.currentContent).to(equal("No content available"))
                }

                it("should handle sutra with nil content") {
                    let sutraWithNilContent = Sutra(
                        path: "/Nil",
                        name: "Nil",
                        type: .content,
                        content: nil
                    )
                    mockRepository.mockSutras.append(sutraWithNilContent)

                    await viewModel.loadSutra(at: "/Nil")

                    expect(viewModel.currentContent).to(equal("No content available"))
                }

                it("should handle loading error gracefully") {
                    let failingRepository = FailingMockBookRepository()
                    let failingViewModel = SutraReadingViewModel(
                        repository: failingRepository,
                        initialPath: "/A1/B1/C1"
                    )

                    await failingViewModel.loadSutra(at: "/A1/B1/C1")

                    expect(failingViewModel.showingError).to(beTrue())
                }
            }

            // MARK: - Pagination State Tests

            describe("navigation state") {
                it("should correctly identify first page") {
                    viewModel.paginationService = PaginationService(
                        sutras: [
                            Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                            Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                        ]
                    )

                    await viewModel.loadSutra(at: "/A1/B1/C1")

                    expect(viewModel.hasPreviousPage).to(beFalse())
                    expect(viewModel.hasNextPage).to(beTrue())
                }

                it("should correctly identify last page") {
                    viewModel.paginationService = PaginationService(
                        sutras: [
                            Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                            Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                        ]
                    )

                    await viewModel.loadSutra(at: "/A1/B1/C2")

                    expect(viewModel.hasNextPage).to(beFalse())
                    expect(viewModel.hasPreviousPage).to(beTrue())
                }

                it("should correctly identify middle page") {
                    viewModel.paginationService = PaginationService(
                        sutras: [
                            Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                            Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                            Sutra(path: "/A1/B1/C3", name: "Third", type: .content),
                        ]
                    )

                    await viewModel.loadSutra(at: "/A1/B1/C2")

                    expect(viewModel.hasNextPage).to(beTrue())
                    expect(viewModel.hasPreviousPage).to(beTrue())
                }
            }
        }

        // MARK: - Integration Tests

        describe("SutraReadingViewModel integration") {
            var repository: BookRepositoryImpl!
            var cache: BookCache!
            var loader: BookLoader!
            var viewModel: SutraReadingViewModel!

            beforeEach {
                cache = BookCache()
                loader = BookLoader()
                repository = BookRepositoryImpl(loader: loader, cache: cache)
                viewModel = SutraReadingViewModel(
                    repository: repository,
                    initialPath: "/A1/B1/C1"
                )
            }

            it("should work with real repository") {
                expect(viewModel.currentPath).to(equal("/A1/B1/C1"))

                // Note: This will fail if JSON files don't exist
                // In a real test, we'd need to mock the loader or provide test data
            }
        }
    }
}

// MARK: - Mock Repository for Tests

class MockBookRepositoryForReading: BookRepository {
    var mockSutras: [Sutra] = []

    func getSutraTree() async throws -> [SutraNode] {
        return SutraNode.buildTree(from: mockSutras)
    }

    func getSutra(atPath path: String) async throws -> Sutra? {
        return mockSutras.first { $0.path == path }
    }

    func getNextPage(from currentPath: String) async throws -> String? {
        guard let index = mockSutras.firstIndex(where: { $0.path == currentPath }),
              index < mockSutras.count - 1 else {
            return nil
        }
        return mockSutras[index + 1].path
    }

    func getPreviousPage(from currentPath: String) async throws -> String? {
        guard let index = mockSutras.firstIndex(where: { $0.path == currentPath }),
              index > 0 else {
            return nil
        }
        return mockSutras[index - 1].path
    }

    func getKeyItems() async throws -> [[String]] {
        return mockSutras.map { [$0.path, $0.name] }
    }

    func getChapterContent(chapter: Int) async throws -> String {
        return mockSutras
            .filter { $0.chapter == chapter }
            .compactMap { $0.content }
            .joined(separator: "\n\n")
    }

    func searchSutras(query: String) async throws -> [Sutra] {
        return mockSutras.filter { $0.name.contains(query) }
    }

    func containsSutra(atPath path: String) async throws -> Bool {
        return mockSutras.contains { $0.path == path }
    }
}

class FailingMockBookRepository: BookRepository {
    func getSutraTree() async throws -> [SutraNode] {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load"])
    }

    func getSutra(atPath path: String) async throws -> Sutra? {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load sutra"])
    }

    func getNextPage(from currentPath: String) async throws -> String? {
        throw NSError(domain: "TestError", code: 1)
    }

    func getPreviousPage(from currentPath: String) async throws -> String? {
        throw NSError(domain: "TestError", code: 1)
    }

    func getKeyItems() async throws -> [[String]] {
        throw NSError(domain: "TestError", code: 1)
    }

    func getChapterContent(chapter: Int) async throws -> String {
        throw NSError(domain: "TestError", code: 1)
    }

    func searchSutras(query: String) async throws -> [Sutra] {
        throw NSError(domain: "TestError", code: 1)
    }

    func containsSutra(atPath path: String) async throws -> Bool {
        throw NSError(domain: "TestError", code: 1)
    }
}
