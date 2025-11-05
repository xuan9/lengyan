//
//  BookRepositoryTests.swift
//  LengyanTests
//
//  Comprehensive tests for BookRepository
//  Target: 100% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class BookRepositoryTests: QuickSpec {
    override class func spec() {
        describe("BookRepositoryImpl") {
            var mockLoader: MockBookLoader!
            var mockCache: MockBookCache!
            var repository: BookRepositoryImpl!

            beforeEach {
                mockLoader = MockBookLoader()
                mockCache = MockBookCache()
                repository = BookRepositoryImpl(loader: mockLoader, cache: mockCache)
            }

            // MARK: - Get Sutra Tree Tests

            describe("getSutraTree()") {
                context("when tree is cached") {
                    it("should return cached tree") {
                        let mockTree = SutraNode.buildTree(from: [
                            Sutra(path: "/A1", name: "Chapter 1", type: .chapter)
                        ])
                        mockCache.mockTree = mockTree

                        let result = try await repository.getSutraTree()

                        expect(result).to(equal(mockTree))
                        expect(mockLoader.loadAllSutrasCalled).to(beFalse())
                    }
                }

                context("when tree is not cached") {
                    it("should load from loader and cache") {
                        let mockSutras = [
                            Sutra(path: "/A1", name: "Chapter 1", type: .chapter)
                        ]
                        mockLoader.mockSutras = mockSutras

                        let result = try await repository.getSutraTree()

                        expect(mockLoader.loadAllSutrasCalled).to(beTrue())
                        expect(mockCache.setTreeCalled).to(beTrue())
                        expect(result).toNot(beNil())
                    }
                }

                context("when loader throws error") {
                    it("should propagate error") {
                        mockLoader.shouldThrowError = true

                        await expect {
                            try await repository.getSutraTree()
                        }.to(throwError())
                    }
                }
            }

            // MARK: - Get Sutra Tests

            describe("getSutra(atPath:)") {
                context("when sutra is cached") {
                    it("should return cached sutra") {
                        let mockSutra = Sutra(path: "/A1/B1", name: "Test", type: .content)
                        mockCache.mockSutras["/A1/B1"] = mockSutra

                        let result = try await repository.getSutra(atPath: "/A1/B1")

                        expect(result).to(equal(mockSutra))
                        expect(mockLoader.loadAllSutrasCalled).to(beFalse())
                    }
                }

                context("when sutra is not cached") {
                    it("should load from loader and cache") {
                        let mockSutras = [
                            Sutra(path: "/A1/B1", name: "Test", type: .content)
                        ]
                        mockLoader.mockSutras = mockSutras

                        let result = try await repository.getSutra(atPath: "/A1/B1")

                        expect(mockLoader.loadAllSutrasCalled).to(beTrue())
                        expect(mockCache.setSutraCalled).to(beTrue())
                        expect(result?.path).to(equal("/A1/B1"))
                    }
                }

                context("when sutra does not exist") {
                    it("should return nil") {
                        let mockSutras = [
                            Sutra(path: "/A1/B1", name: "Test", type: .content)
                        ]
                        mockLoader.mockSutras = mockSutras

                        let result = try await repository.getSutra(atPath: "/NonExistent")

                        expect(result).to(beNil())
                    }
                }

                context("when loader throws error") {
                    it("should propagate error") {
                        mockLoader.shouldThrowError = true

                        await expect {
                            try await repository.getSutra(atPath: "/A1/B1")
                        }.to(throwError())
                    }
                }
            }

            // MARK: - Get Next Page Tests

            describe("getNextPage(from:)") {
                it("should return next page path") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                        Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                        Sutra(path: "/A1/B1/C3", name: "Third", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getNextPage(from: "/A1/B1/C1")

                    expect(result).to(equal("/A1/B1/C2"))
                }

                it("should return nil for last page") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getNextPage(from: "/A1/B1/C1")

                    expect(result).to(beNil())
                }

                it("should cache next path") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                        Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    _ = try await repository.getNextPage(from: "/A1/B1/C1")

                    expect(mockCache.setNextPathCalled).to(beTrue())
                }
            }

            // MARK: - Get Previous Page Tests

            describe("getPreviousPage(from:)") {
                it("should return previous page path") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                        Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                        Sutra(path: "/A1/B1/C3", name: "Third", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getPreviousPage(from: "/A1/B1/C2")

                    expect(result).to(equal("/A1/B1/C1"))
                }

                it("should return nil for first page") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getPreviousPage(from: "/A1/B1/C1")

                    expect(result).to(beNil())
                }

                it("should cache previous path") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                        Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    _ = try await repository.getPreviousPage(from: "/A1/B1/C2")

                    expect(mockCache.setPreviousPathCalled).to(beTrue())
                }
            }

            // MARK: - Get Key Items Tests

            describe("getKeyItems()") {
                context("when key items are cached") {
                    it("should return cached key items") {
                        let mockKeyItems = [["/A1/B1", "Test"]]
                        mockCache.mockKeyItems = mockKeyItems

                        let result = try await repository.getKeyItems()

                        expect(result).to(equal(mockKeyItems))
                        expect(mockLoader.loadAllSutrasCalled).to(beFalse())
                    }
                }

                context("when key items are not cached") {
                    it("should load from loader and cache") {
                        let mockSutras = [
                            Sutra(path: "/A1/B1", name: "Test", type: .chapter),
                            Sutra(path: "/A2/B1", name: "Test2", type: .section),
                        ]
                        mockLoader.mockSutras = mockSutras

                        let result = try await repository.getKeyItems()

                        expect(mockLoader.loadAllSutrasCalled).to(beTrue())
                        expect(mockCache.setKeyItemsCalled).to(beTrue())
                        expect(result.count).to(equal(2))
                    }
                }

                it("should filter only chapters and sections") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Chapter", type: .chapter),
                        Sutra(path: "/A1/B2", name: "Section", type: .section),
                        Sutra(path: "/A1/B3", name: "Content", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getKeyItems()

                    expect(result.count).to(equal(2))
                }
            }

            // MARK: - Get Chapter Content Tests

            describe("getChapterContent(chapter:)") {
                it("should return chapter content") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1/C1", name: "Content 1", type: .content, chapter: 1, content: "Chapter 1 Content 1"),
                        Sutra(path: "/A1/B1/C2", name: "Content 2", type: .content, chapter: 1, content: "Chapter 1 Content 2"),
                        Sutra(path: "/A2/B1/C1", name: "Content 3", type: .content, chapter: 2, content: "Chapter 2 Content 1"),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getChapterContent(chapter: 1)

                    expect(result).to(contain("Chapter 1 Content 1"))
                    expect(result).to(contain("Chapter 1 Content 2"))
                    expect(result).toNot(contain("Chapter 2 Content 1"))
                }

                it("should handle chapter with no content") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Empty", type: .chapter, chapter: 1),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.getChapterContent(chapter: 1)

                    expect(result).to(equal(""))
                }
            }

            // MARK: - Search Sutras Tests

            describe("searchSutras(query:)") {
                it("should find sutras matching query") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Buddhist Sutra", type: .chapter),
                        Sutra(path: "/A1/B2", name: "Another Text", type: .chapter),
                        Sutra(path: "/A2/B1", name: "Buddhist Teaching", type: .section),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.searchSutras(query: "Buddhist")

                    expect(result.count).to(equal(2))
                    expect(result.map { $0.name }).to(contain("Buddhist Sutra"))
                    expect(result.map { $0.name }).to(contain("Buddhist Teaching"))
                }

                it("should be case insensitive") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Buddhist", type: .chapter),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.searchSutras(query: "buddhist")

                    expect(result.count).to(equal(1))
                }

                it("should return empty array when no matches") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Buddhist", type: .chapter),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.searchSutras(query: "NonExistent")

                    expect(result).to(beEmpty())
                }
            }

            // MARK: - Contains Sutra Tests

            describe("containsSutra(atPath:)") {
                it("should return true when sutra exists") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Test", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.containsSutra(atPath: "/A1/B1")

                    expect(result).to(beTrue())
                }

                it("should return false when sutra does not exist") {
                    let mockSutras = [
                        Sutra(path: "/A1/B1", name: "Test", type: .content),
                    ]
                    mockLoader.mockSutras = mockSutras

                    let result = try await repository.containsSutra(atPath: "/NonExistent")

                    expect(result).to(beFalse())
                }
            }
        }

        // MARK: - MockBookRepository Tests

        describe("MockBookRepository") {
            var mockRepository: MockBookRepository!

            beforeEach {
                let mockSutras = [
                    Sutra(path: "/A1/B1", name: "Test", type: .content)
                ]
                let mockTree = SutraNode.buildTree(from: mockSutras)
                mockRepository = MockBookRepository(mockTree: mockTree, mockSutras: mockSutras)
            }

            it("should return mock sutras") {
                let result = try await mockRepository.getSutra(atPath: "/A1/B1")

                expect(result?.path).to(equal("/A1/B1"))
            }

            it("should return mock tree") {
                let result = try await mockRepository.getSutraTree()

                expect(result.isEmpty).to(beFalse())
            }
        }
    }
}

// MARK: - Mock Implementations

class MockBookLoader: BookLoader {
    var mockSutras: [Sutra] = []
    var shouldThrowError = false
    var loadAllSutrasCalled = false

    override func loadAllSutras() async throws -> [Sutra] {
        loadAllSutrasCalled = true

        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }

        return mockSutras
    }
}

class MockBookCache: BookCache {
    var mockSutras: [String: Sutra] = [:]
    var mockTree: [SutraNode]?
    var mockKeyItems: [[String]]?

    var setSutraCalled = false
    var setTreeCalled = false
    var setKeyItemsCalled = false
    var setNextPathCalled = false
    var setPreviousPathCalled = false

    override func getSutra(atPath path: String) async -> Sutra? {
        return mockSutras[path]
    }

    override func setSutra(_ sutra: Sutra, forPath path: String) async {
        setSutraCalled = true
        mockSutras[path] = sutra
    }

    override func getTree() async -> [SutraNode]? {
        return mockTree
    }

    override func setTree(_ tree: [SutraNode]) async {
        setTreeCalled = true
        mockTree = tree
    }

    override func getKeyItems() async -> [[String]]? {
        return mockKeyItems
    }

    override func setKeyItems(_ keyItems: [[String]]) async {
        setKeyItemsCalled = true
        mockKeyItems = keyItems
    }

    override func setNextPath(_ currentPath: String, nextPath: String) async {
        setNextPathCalled = true
    }

    override func setPreviousPath(_ currentPath: String, previousPath: String) async {
        setPreviousPathCalled = true
    }
}
