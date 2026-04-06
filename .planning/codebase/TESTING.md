# Testing Patterns

**Analysis Date:** 2026-04-06

## Test Framework

**Runner:**
- XCTest (native iOS testing framework)
- Quick/Nimble (BDD-style testing wrapper)
- Config: No explicit config file detected (uses Xcode default schemes)

**Assertion Library:**
- Nimble: `expect(result).to(equal("/A1/B1/C3"))`, `expect(isFirst).to(beTrue())`
- XCTest assertions: `XCTAssertNotNil`, `XCTAssertEqual` (in legacy tests)

**Run Commands:**
```bash
# Run all tests (Xcode)
Cmd+U

# Run specific test
# Via Xcode test navigator

# Run tests from command line
xcodebuild test -scheme lengyan -destination 'platform=iOS Simulator,name=iPhone 15'

# Watch mode (not configured - no Mentat or similar detected)
```

## Test File Organization

**Location:**
- Co-located: Tests in separate `lengyanTests/` and `lengyanUITests/` directories
- Additional unit tests in `Tests/` directory
- Test support in `lengyanTests/TestSupport/` (directory exists but contents not directly examined)

**Naming:**
- Mirror source with `Tests` suffix: `BookRepositoryTests.swift`, `PaginationServiceTests.swift`
- UI tests add `UI` prefix: `SutraIndexViewUITests.swift`
- Organized by feature: `AudioPlayerViewModelTests.swift`, `SettingsViewModelTests.swift`

**Structure:**
```
lengyanTests/
├── BookTests.swift                    # Legacy XCTest tests
├── BookRepositoryTests.swift          # Repository layer tests
├── PaginationServiceTests.swift      # Service layer tests
├── SutraReadingViewModelTests.swift  # ViewModel tests
├── SutraIndexViewModelTests.swift    # Index view model tests
├── AudioPlayerViewModelTests.swift   # Audio player tests
├── SettingsViewModelTests.swift      # Settings tests
├── FavoritesViewModelTests.swift     # Favorites tests
└── DIContainerTests.swift            # Dependency injection tests

Tests/
├── AppCoordinatorTests.swift         # Coordinator tests
├── SnapshotTests/
│   └── SwiftUISnapshotTests.swift   # Visual regression tests
├── DesignSystemTests.swift           # Design token tests
└── PerformanceTests.swift            # Performance tests

lengyanUITests/
├── SutraAppUITests.swift             # App-level UI tests
├── SutraIndexViewUITests.swift       # Index view UI tests
└── lengyanUITests.swift              # Legacy UI tests
```

## Test Structure

**Suite Organization:**
```swift
final class PaginationServiceTests: QuickSpec {
    override class func spec() {
        describe("PaginationService") {
            var sutras: [Sutra]!
            var service: PaginationService!

            beforeEach {
                // Setup test state
                sutras = [...]
                service = PaginationService(sutras: sutras)
            }

            // MARK: - Next Page Tests
            describe("nextPage(from:)") {
                it("should return next page for middle item") {
                    // Arrange, Act, Assert pattern
                    let next = service.nextPage(from: "/A1/B1/C2")
                    expect(next).to(equal("/A1/B1/C3"))
                }
            }
        }
    }
}
```

**Patterns:**
- BDD style with Quick: `describe`, `context`, `it`
- Setup in `beforeEach` blocks
- No explicit teardown (relies on Swift ARC)
- Grouped by feature with MARK comments
- Context-based test organization: `context("when next page exists")`

## Mocking

**Framework:** Hand-rolled test doubles (no mocking library detected)

**Patterns:**
```swift
// Protocol-based mock
class MockBookRepository: BookRepository {
    var mockTree: [SutraNode] = []
    var mockSutras: [Sutra] = []

    func getSutraTree() async throws -> [SutraNode] {
        return mockTree
    }

    func getSutra(atPath path: String) async throws -> Sutra? {
        return mockSutras.first { $0.path == path }
    }
}

// Failing mock for error scenarios
class FailingMockBookRepository: BookRepository {
    func getSutraTree() async throws -> [SutraNode] {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load"])
    }
}
```

**What to Mock:**
- Repository layer: `BookRepository`, `AudioRepository`
- External dependencies: `BookLoader`, `BookCache`
- User preferences: `PreferencesRepository`, `ThemeRepository`
- Network/services (if any): Not detected in codebase

**What NOT to Mock:**
- Value types: `Sutra`, `SutraNode`, `MediaItem`
- Simple services: `PaginationService` (tested directly)
- Design system: `SutraDesignTokens` (tested in isolation)

## Fixtures and Factories

**Test Data:**
```swift
private func createMockSutraTree() -> [SutraNode] {
    return [
        SutraNode(
            sutra: Sutra(path: "/A1", name: "Chapter 1", type: .directory),
            children: [
                SutraNode(
                    sutra: Sutra(path: "/A1/B1", name: "Section 1", type: .content),
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
```

**Location:**
- Test data factories as private methods in test classes
- No shared fixtures directory detected
- Each test file creates its own mock data

**Snapshot Testing:**
```swift
func testSutraIndexView_withData() {
    let sutraTree = createMockSutraTree()
    let mockRepository = MockBookRepository(mockTree: sutraTree, mockSutras: [])
    let viewModel = SutraIndexViewModel(repository: mockRepository)
    let view = SutraIndexView(viewModel: viewModel)

    assertSnapshot(of: view, as: .image)
}
```

## Coverage

**Requirements:** Target coverage specified in test headers:
- PaginationService: "Target: 95% test coverage"
- BookRepository: "Target: 100% test coverage"
- SutraReadingViewModel: "Target: 95% test coverage"

**View Coverage:**
```bash
# No explicit coverage command found
# Use Xcode's built-in coverage:
# Editor → Test Behavior → Gather Coverage for Test Sessions
# Then: Report → Coverage (Cmd+Option+U in Xcode)
```

**Current Coverage Status:**
- Comprehensive test coverage for ViewModels
- Repository layer tests
- Service layer tests (pagination)
- Snapshot tests for SwiftUI views
- Legacy XCTest tests for Book singleton

## Test Types

**Unit Tests:**
- ViewModel tests: State management, navigation, error handling
- Repository tests: Caching, loading, error propagation
- Service tests: Pagination logic, edge cases
- Design system tests: Color tokens, typography

**Integration Tests:**
```swift
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
    }
}
```

**E2E Tests:**
- `lengyanUITests/` directory contains UI tests
- `SutraAppUITests.swift` for app-level flows
- No explicit E2E framework (XCUITest used)

## Common Patterns

**Async Testing:**
```swift
it("should load sutra successfully") {
    await viewModel.loadSutra(at: "/A1/B1/C1")

    expect(viewModel.currentSutra).toNot(beNil())
    expect(viewModel.currentSutra?.path).to(equal("/A1/B1/C1"))
    expect(viewModel.currentContent).to(equal("Content 1"))
}
```

**Error Testing:**
```swift
context("when loader throws error") {
    it("should propagate error") {
        mockLoader.shouldThrowError = true

        await expect {
            try await repository.getSutraTree()
        }.to(throwError())
    }
}

it("should show error when sutra not found") {
    await viewModel.loadSutra(at: "/NonExistent")

    expect(viewModel.showingError).to(beTrue())
    expect(viewModel.errorMessage).toNot(beNil())
}
```

**Edge Case Testing:**
```swift
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
}
```

**State Testing:**
```swift
describe("navigation state") {
    it("should correctly identify first page") {
        viewModel.paginationService = PaginationService(sutras: [...])

        await viewModel.loadSutra(at: "/A1/B1/C1")

        expect(viewModel.hasPreviousPage).to(beFalse())
        expect(viewModel.hasNextPage).to(beTrue())
    }
}
```

## Test Data Management

**Mock Repositories:**
- Protocol-based: `MockBookRepository`, `MockAudioRepository`
- State tracking: `var loadAllSutrasCalled = false`
- Error injection: `var shouldThrowError = false`

**Test Organization:**
- Feature-based test suites
- Context-based test grouping
- Descriptive test names: "should return next page for middle item"

**Snapshot Testing:**
- Uses SwiftSnapshotTesting library
- Tests for light/dark themes
- Tests for different content states
- Visual regression prevention

---

*Testing analysis: 2026-04-06*
