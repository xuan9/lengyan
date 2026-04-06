# Coding Conventions

**Analysis Date:** 2026-04-06

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `SutraPageViewController.swift`, `AudioManager.swift`, `DesignSystem+Typography.swift`
- Extension files use `+` notation: `String+Common.swift`, `UIView+Common.swift`, `DesignSystem+Spacing.swift`
- Test files mirror source with `Tests` suffix: `BookRepositoryTests.swift`, `SutraReadingViewModelTests.swift`
- Protocol definitions often in same file as conforming type

**Functions:**
- camelCase for all functions: `loadSutra(at:)`, `goToNextPage()`, `applySutraTypography()`
- Objective-C-style `@objc` methods for UIKit selectors: `@objc func like()`, `@objc func close()`
- Async/await pattern for async operations: `func getSutra(atPath:) async throws -> Sutra?`
- Computed properties use camelCase without get prefix: `var hasNextPage: Bool { ... }`

**Variables:**
- camelCase for all variables: `fontSizeLevel`, `selectedTheme`, `isReminderOn`
- Private properties use leading underscore: `private var _cache: [String: Any]`
- Constants use UPPER_SNAKE_CASE for global constants: `KEY_PATHS`, `DEFAULT_STARTS`
- Local constants use camelCase: `let backgroundColor = ...`

**Types:**
- PascalCase for all types: `SutraViewModel`, `BookRepository`, `ColorToken`
- Protocols use PascalCase, often ending with `Protocol`: `PrefersProtocol`, `SutraThemeProtocol`, `Coordinator`
- Enums use PascalCase for cases: `case light`, `case sepia`, `case dark`
- Generic placeholders: `T`, `U`, `Content: View`

## Code Style

**Formatting:**
- No explicit formatter configured (no .swiftformat, no SwiftLint config found)
- 4-space indentation (project-wide)
- Opening braces on same line: `func example() {`
- Trailing closures preferred: `sutras.filter { $0.path == path }`
- Blank lines between logical sections

**Linting:**
- No SwiftLint or similar tool detected
- Code follows standard Swift conventions manually

**File Organization:**
- MARK comments used extensively: `// MARK: - Loading Tests`, `// MARK: - Public API`
- Extensions grouped by functionality: `// MARK: - SwiftUI View Extensions`
- Protocol-oriented design: protocols defined before implementations

## Import Organization

**Order:**
1. Framework imports (UIKit, SwiftUI, Foundation)
2. Third-party imports (AVFoundation, SnapshotTesting, Quick, Nimble)
3. Test imports (`@testable import`)
4. Empty line before code

**Path Aliases:**
- No custom path aliases detected
- Uses standard module imports: `import SwiftUI`, `import XCTest`

**Example from `SutraReadingViewModelTests.swift`:**
```swift
import XCTest
import Quick
import Nimble

@testable import LengyanCore
```

## Error Handling

**Patterns:**
- Swift native error handling: `throws`, `try`, `catch`
- Optional chaining for graceful failure: `Book.shared.media`
- Force unwrapping used sparingly: `self.item = Book.shared.index![page]`
- Async/await with error propagation: `try await repository.getSutraTree()`

**Error Propagation:**
- Repository layer throws errors: `func getSutra(atPath:) async throws -> Sutra?`
- ViewModel catches and exposes state: `@Published var showingError: Bool`
- Test-specific error types: `NSError(domain: "TestError", code: 1)`

**User-Facing Errors:**
- `@Published var errorMessage: String?`
- `@Published var showingError: Bool`
- Alert presentation in view layer

**Example error handling in tests:**
```swift
context("when loader throws error") {
    it("should propagate error") {
        mockLoader.shouldThrowError = true

        await expect {
            try await repository.getSutraTree()
        }.to(throwError())
    }
}
```

## Logging

**Framework:** `print()` statements (console logging)

**Patterns:**
- Emoji prefixes for categorization: `print("📦 ODR already available: ...")`, `print("⏳ ODR not available: ...")`
- Debug timing with custom TICK/TOCK: `TICK()`, `TOCK()` from `Utils.swift`
- Minimal logging in production code
- More extensive logging in test/debug scenarios

**Example from `AudioManager.swift`:**
```swift
print("📦 ODR already available: \(file).\(fileExtension)")
print("⏳ ODR not available: \(file).\(fileExtension) - needs download")
print("📝 Resumed playback UI: \(name)")
```

**Performance logging:**
```swift
func TICK(){ startTime = Date() }

func TOCK(_ function: String = #function, file: String = #file, line: Int = #line){
    print("\(function) Time: \(-startTime.timeIntervalSinceNow)\nLine:\(line) File: \(file)")
}
```

## Comments

**When to Comment:**
- MARK comments for code organization: `// MARK: - Private Methods`
- Section separators with visual emphasis: `// ── 修行 ──`
- Chinese comments for domain-specific context (佛经阅读 app)
- Design rationale in comments: `// 禅意字体系统`

**JSDoc/TSDoc:**
- Not standard JSDoc/TSDoc format
- Uses inline comments for documentation
- Protocol methods have brief descriptions: `/// Cycle to the next theme with animation`

**Example documentation style:**
```swift
/// Traditional Chinese character spacing based on printing standards
public enum TraditionalSpacing {
    case tight        // 紧密 - Classical texts
    case standard     // 标准 - Modern reading
    case comfortable  // 舒适 - Extended reading
    case contemplative // 冥想 - Meditation mode
}
```

**Design Philosophy Comments:**
```swift
// Settings — words are the interface.
// 禅意字体系统 - Light weight at larger sizes: the quieter the font, the louder the content
```

## Function Design

**Size:** Functions generally kept under 50 lines
- Small, focused functions: `func like(_ path: String)`, `func unlike(_ path: String)`
- View body properties can be longer but use helper functions

**Parameters:**
- Argument labels for clarity: `func getSutra(atPath path: String)`
- Default values for common cases: `weight: Font.Weight = .regular`
- Closure parameters for callbacks: `var onDismiss: (() -> Void)?`

**Return Values:**
- Async functions throw errors: `async throws -> Sutra?`
- Optional returns for not-found cases: `func getNextPage(from:) async throws -> String?`
- Published properties for state: `@Published var isLoading = true`

**Example function signature:**
```swift
func font(for style: SutraTypographyStyle, weight: Font.Weight = .regular) -> Font {
    let uiFontWeight = UIFont.Weight.from(fontWeight: weight)
    let uiFont = uiFont(for: style, weight: uiFontWeight)
    return Font(uiFont)
}
```

## Module Design

**Exports:**
- Public API marked with `public` or `open` access control
- Internal implementation uses `private` or `fileprivate`
- Test-specific types marked with `@testable import`

**Barrel Files:**
- No explicit barrel files detected
- Each file exports its own public types
- Design system split across multiple `DesignSystem+*.swift` files

**Access Control Pattern:**
```swift
public final class SutraTypographyManager {
    public static let shared = SutraTypographyManager()
    private init() {}  // Singleton

    public func font(for style: SutraTypographyStyle) -> Font { ... }
}
```

**Dependency Injection:**
- Protocol-based injection: `BookRepository`, `AudioRepository`
- DI container pattern: `DIContainer.shared.resolve(type:)`
- Test doubles via protocols: `MockBookRepository`, `FailingMockBookRepository`

## Architecture Patterns

**Design System:**
- Protocol-oriented: `SutraThemeProtocol`, `SutraTypography`
- Type-safe enums: `ColorToken`, `ShapeToken`, `MotionToken`
- Centralized tokens: `SutraDesignTokens.shared`
- SwiftUI + UIKit bridge: extensions on both frameworks

**Coordinator Pattern:**
- `AppCoordinator` manages top-level navigation
- Child coordinators: `SutraCoordinator`, `AudioCoordinator`
- Protocol-based: `public protocol Coordinator { func start() }`

**Repository Pattern:**
- Abstraction layer: `BookRepository` protocol
- Implementation: `BookRepositoryImpl`
- Caching: `BookCache`, separation of loader/cache

**ViewModel Pattern:**
- Observable view models: `@ObservableObject class SutraReadingViewModel`
- Published state: `@Published var currentSutra: Sutra?`
- Business logic in view models, not views

**Singleton Pattern:**
- Shared instances: `Book.shared`, `AudioManager.shared`, `Prefers.shared`
- Used for global state management
- Privately initialized: `private init() {}`

---

*Convention analysis: 2026-04-06*
