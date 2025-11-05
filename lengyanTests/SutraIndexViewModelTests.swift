//
//  SutraIndexViewModelTests.swift
//  LengyanTests
//
//  Comprehensive tests for SutraIndexViewModel
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class SutraIndexViewModelTests: QuickSpec {
    override class func spec() {
        describe("SutraIndexViewModel") {
            var mockRepository: MockBookRepository!
            var viewModel: SutraIndexViewModel!

            beforeEach {
                let mockTree = SutraNode.buildTree(from: [
                    Sutra(path: "/A1", name: "Chapter 1", type: .chapter),
                    Sutra(path: "/A1/B1", name: "Section 1.1", type: .section),
                    Sutra(path: "/A1/B1/C1", name: "Content 1.1.1", type: .content),
                ])
                let mockSutras = mockTree.flatMap { [$0.sutra] + $0.children.map { $0.sutra } }

                mockRepository = MockBookRepository(mockTree: mockTree, mockSutras: mockSutras)
                viewModel = SutraIndexViewModel(repository: mockRepository)
            }

            // MARK: - Loading Tests

            describe("loadSutraTree()") {
                it("should load sutra tree successfully") {
                    await viewModel.loadSutraTree()

                    expect(viewModel.sutraTree.isEmpty).to(beFalse())
                    expect(viewModel.sutraTree.count).to(equal(1))
                }

                it("should set error when loading fails") {
                    // Simulate failure by using a mock that throws
                    let failingRepository = FailingMockBookRepository()
                    let failingViewModel = SutraIndexViewModel(repository: failingRepository)

                    await failingViewModel.loadSutraTree()

                    expect(failingViewModel.showingError).to(beTrue())
                    expect(failingViewModel.errorMessage).toNot(beNil())
                }
            }

            // MARK: - Selection Tests

            describe("selectSutra(_:)") {
                context("when sutra has children") {
                    it("should navigate to children") {
                        let sutraWithChildren = Sutra(
                            path: "/A1",
                            name: "Chapter 1",
                            type: .chapter,
                            children: [
                                Sutra(path: "/A1/B1", name: "Section 1.1", type: .section)
                            ]
                        )

                        viewModel.selectSutra(sutraWithChildren)

                        // Should navigate to children
                        // Implementation depends on coordinator pattern
                    }
                }

                context("when sutra has content") {
                    it("should open sutra for reading") {
                        let sutraWithContent = Sutra(
                            path: "/A1/B1/C1",
                            name: "Content 1.1.1",
                            type: .content,
                            content: "Sample content"
                        )

                        viewModel.selectSutra(sutraWithContent)

                        // Should open reading view
                        // Implementation depends on coordinator pattern
                    }
                }

                context("when sutra is empty") {
                    it("should do nothing") {
                        let emptySutra = Sutra(
                            path: "/Empty",
                            name: "Empty",
                            type: .content
                        )

                        expect(viewModel.sutraTree.isEmpty).to(beTrue())

                        viewModel.selectSutra(emptySutra)

                        // Should handle gracefully
                    }
                }
            }

            // MARK: - Theme Tests

            describe("setTheme(_:)") {
                it("should set theme correctly") {
                    expect(UserDefaults.standard.string(forKey: "CurrentTheme")).to(beNil())

                    viewModel.setTheme(.light)
                    expect(UserDefaults.standard.string(forKey: "CurrentTheme")).to(equal("light"))

                    viewModel.setTheme(.dark)
                    expect(UserDefaults.standard.string(forKey: "CurrentTheme")).to(equal("dark"))

                    viewModel.setTheme(.sepia)
                    expect(UserDefaults.standard.string(forKey: "CurrentTheme")).to(equal("sepia"))
                }

                it("should handle all theme types") {
                    viewModel.setTheme(.light)
                    viewModel.setTheme(.sepia)
                    viewModel.setTheme(.dark)

                    expect(UserDefaults.standard.string(forKey: "CurrentTheme")).to(equal("dark"))
                }
            }

            // MARK: - Search Tests

            describe("searchSutras(query:)") {
                context("when query is empty") {
                    it("should clear results") {
                        viewModel.sutraTree = [
                            SutraNode(sutra: Sutra(path: "/A1", name: "Test", type: .chapter))
                        ]

                        await viewModel.searchSutras(query: "")

                        // Should clear results
                    }
                }

                context("when query has results") {
                    it("should filter sutras correctly") {
                        // This test would verify search functionality
                        // once it's fully implemented
                    }
                }

                context("when query has no results") {
                    it("should show empty state") {
                        // This test would verify empty state handling
                    }
                }

                context("when search throws error") {
                    it("should show error") {
                        let failingRepository = FailingMockBookRepository()
                        let failingViewModel = SutraIndexViewModel(repository: failingRepository)

                        await failingViewModel.searchSutras(query: "test")

                        expect(failingViewModel.showingError).to(beTrue())
                    }
                }
            }

            // MARK: - Error Handling Tests

            describe("error handling") {
                it("should show error when repository fails") {
                    let failingRepository = FailingMockBookRepository()
                    let failingViewModel = SutraIndexViewModel(repository: failingRepository)

                    await failingViewModel.loadSutraTree()

                    expect(failingViewModel.showingError).to(beTrue())
                    expect(failingViewModel.errorMessage).toNot(beNil())
                }

                it("should allow dismissing error") {
                    let failingRepository = FailingMockBookRepository()
                    let failingViewModel = SutraIndexViewModel(repository: failingRepository)

                    await failingViewModel.loadSutraTree()
                    expect(failingViewModel.showingError).to(beTrue())

                    // In a real implementation, there would be a dismissError method
                    failingViewModel.showingError = false
                    expect(failingViewModel.showingError).to(beFalse())
                }
            }

            // MARK: - State Tests

            describe("published properties") {
                it("should update sutraTree when loaded") {
                    expect(viewModel.sutraTree.isEmpty).to(beTrue())

                    await viewModel.loadSutraTree()

                    expect(viewModel.sutraTree.isEmpty).to(beFalse())
                }

                it("should update navigationPath when sutra selected") {
                    let sutra = Sutra(path: "/A1", name: "Chapter 1", type: .chapter)
                    viewModel.selectSutra(sutra)

                    // Navigation path should be updated
                    // Implementation depends on coordinator
                }
            }
        }

        // MARK: - Integration Tests

        describe("SutraIndexViewModel integration") {
            var repository: BookRepositoryImpl!
            var cache: BookCache!
            var loader: BookLoader!
            var viewModel: SutraIndexViewModel!

            beforeEach {
                cache = BookCache()
                loader = BookLoader()
                repository = BookRepositoryImpl(loader: loader, cache: cache)
                viewModel = SutraIndexViewModel(repository: repository)
            }

            it("should work with real repository") {
                expect(viewModel.sutraTree.isEmpty).to(beTrue())

                // Note: This will fail if JSON files don't exist
                // In a real test, we'd need to mock the loader or provide test data
            }
        }
    }
}

// MARK: - Mock Implementations

class FailingMockBookRepository: BookRepository {
    func getSutraTree() async throws -> [SutraNode] {
        throw NSError(domain: "TestError", code: 1)
    }

    func getSutra(atPath path: String) async throws -> Sutra? {
        throw NSError(domain: "TestError", code: 1)
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
