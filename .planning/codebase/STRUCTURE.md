# Codebase Structure

**Analysis Date:** 2026-04-06

## Directory Layout

```
lengyan/
├── App/                          # Modern SwiftUI app entry point
│   ├── LengyanApp.swift         # @main SwiftUI App struct
│   └── Coordinator/              # Navigation coordinators (new architecture)
│       └── AppCoordinator.swift  # App, Sutra, Audio coordinators
│
├── lengyan/                      # Main iOS app bundle
│   ├── AppDelegate.swift        # UIKit app delegate (main entry point)
│   ├── Info.plist               # App configuration
│   ├── Assets.xcassets/         # Images, colors, icons
│   ├── Fonts/                   # Custom font files
│   ├── Base.lproj/              # Base localization strings
│   ├── zh-Hans.lproj/           # Simplified Chinese strings
│   ├── zh-Hant.lproj/           # Traditional Chinese strings
│   │
│   ├── Domain/                  # Business logic layer
│   │   ├── Book.swift           # Core content manager (singleton)
│   │   ├── AudioManager.swift   # Audio playback manager
│   │   ├── AudioPlayerObserver.swift  # AVPlayer wrapper
│   │   ├── MediaModels.swift    # Audio data models
│   │   ├── Prefers.swift        # User preferences (singleton)
│   │   ├── ReminderManager.swift # Notification scheduler
│   │   └── Constants.swift      # KEY_PATHS, DEFAULT_STARTS
│   │
│   ├── Design/                  # Design system layer
│   │   ├── DesignSystem+Tokens.swift      # Color/shape/motion tokens
│   │   ├── DesignSystem+Typography.swift  # Font system
│   │   ├── DesignSystem+Spacing.swift     # Spacing constants
│   │   ├── DesignSystem+Layout.swift      # Layout utilities
│   │   └── DesignSystem+Accessibility.swift # Accessibility helpers
│   │
│   ├── View/                    # UIKit view controllers
│   │   ├── SutraFrontViewController.swift    # Main reading tree view
│   │   ├── SutraIndexViewController.swift    # Subsection index view
│   │   ├── SutraPageViewController.swift     # Paginated content view
│   │   ├── SutraPageContentViewControllera.swift # Content renderer
│   │   ├── SutraPurePageViewController.swift   # Alternative page view
│   │   └── SutraPurePageContentViewController.swift # Alternative content view
│   │
│   ├── SwiftUI/                # Modern SwiftUI views
│   │   ├── ModernAudioPlayerView.swift    # Audio playback UI
│   │   ├── ModernFavoritesView.swift      # Bookmarks UI
│   │   ├── ModernSettingsView.swift       # Settings UI
│   │   ├── SutraAcknowledgmentsView.swift # Acknowledgments
│   │   └── ZenTabHeaderView.swift         # Tab header component
│   │
│   ├── Util/                   # Utilities and helpers
│   │   ├── Utils.swift                  # General utilities
│   │   ├── String+Common.swift          # String extensions
│   │   ├── UIView+Common.swift          # UIView extensions
│   │   ├── NavigationHelper.swift       # Navigation utilities
│   │   ├── ReaderViewController.swift   # Reader wrapper
│   │   └── RATreeView/                 # Third-party tree view library
│   │       ├── RATreeView.h
│   │       └── RATreeView.m
│   │
│   ├── Core/                   # New architecture layer (in progress)
│   │   ├── Data/              # Data repositories (planned)
│   │   │   ├── Repositories/
│   │   │   └── Models/
│   │   └── Domain/            # Domain services (planned)
│   │       └── Services/
│   │
│   ├── data/                  # Sutra content data (JSON)
│   │   ├── lengyanjing-index-tree.json    # Content hierarchy
│   │   ├── lengyanjing-content.json       # Full text content
│   │   ├── lengyanjing-index.json         # Flat content index
│   │   ├── lengyanjing-media.json         # Audio metadata
│   │   ├── lengyanjing-chapter-map.json  # Chapter to path mapping
│   │   └── simplified/                     # Simplified Chinese versions
│   │
│   ├── source-media/          # Source audio files (ODR tagged)
│   ├── 屏東能淨協會讀誦/       # Audio recordings
│   └── Performance/           # Performance monitoring utilities
│
├── lengyanTests/              # Unit tests
│   ├── BookTests.swift
│   ├── PaginationServiceTests.swift
│   ├── AudioPlayerViewModelTests.swift
│   ├── SutraIndexViewModelTests.swift
│   ├── SutraReadingViewModelTests.swift
│   ├── BookRepositoryTests.swift
│   ├── DIContainerTests.swift
│   ├── SettingsViewModelTests.swift
│   └── FavoritesViewModelTests.swift
│
├── lengyanUITests/            # UI tests
│   ├── SutraAppUITests.swift
│   ├── lengyanUITests.swift
│   └── SutraIndexViewUITests.swift
│
├── Tests/                     # Additional tests
│   ├── AppCoordinatorTests.swift
│   ├── SnapshotTests/
│   ├── DesignSystemTests.swift
│   └── PerformanceTests.swift
│
├── scripts/                   # Build and automation scripts
│   ├── build_and_install.sh
│   ├── start-wda.sh
│   └── stop-wda.sh
│
├── screenshots/               # App screenshots
├── lengyan.xcodeproj/         # Xcode project
└── [Documentation files]      # Various .md files
```

## Directory Purposes

**App/:**
- Purpose: Modern SwiftUI app entry point and coordination layer
- Contains: Main app struct, coordinator pattern implementation
- Key files: `LengyanApp.swift`, `AppCoordinator.swift`

**lengyan/Domain/:**
- Purpose: Core business logic and data management
- Contains: Singleton services for content, audio, preferences
- Key files: `Book.swift`, `AudioManager.swift`, `Prefers.swift`
- Note: Central to app functionality, accessed from all views

**lengyan/Design/:**
- Purpose: Centralized design system for consistent styling
- Contains: Type-safe tokens for colors, typography, spacing, layout
- Key files: `DesignSystem+Tokens.swift`, `DesignSystem+Typography.swift`
- Note: Defines the Zen aesthetic with Chinese font support

**lengyan/View/:**
- Purpose: UIKit-based view controllers for reading flow
- Contains: Main reading interface using traditional iOS patterns
- Key files: `SutraFrontViewController.swift`, `SutraPageViewController.swift`
- Note: Legacy but stable reading experience

**lengyan/SwiftUI/:**
- Purpose: Modern SwiftUI views for new features
- Contains: Audio player, favorites, settings interfaces
- Key files: `ModernAudioPlayerView.swift`, `ModernFavoritesView.swift`
- Note: Incremental migration to SwiftUI

**lengyan/Util/:**
- Purpose: Helper utilities and third-party dependencies
- Contains: Extensions, navigation helpers, RATreeView library
- Key files: `String+Common.swift`, `RATreeView/`
- Note: RATreeView is embedded third-party code

**lengyan/data/:
- Purpose: JSON content storage for sutra text and metadata
- Contains: Content tree, full text, index, audio metadata, chapter map
- Key files: `lengyanjing-content.json`, `lengyanjing-index-tree.json`
- Note: Separate `simplified/` subdirectory for Simplified Chinese

**lengyanTests/:
- Purpose: Unit tests for business logic and view models
- Contains: Tests for Book, pagination, audio, settings
- Key files: `BookTests.swift`, `AudioPlayerViewModelTests.swift`
- Note: Test coverage for critical domain logic

**lengyan/Core/ (New Architecture):**
- Purpose: Future architecture with repositories and services
- Contains: Planned data and domain layers
- Note: Currently empty, part of ongoing refactoring

## Key File Locations

**Entry Points:**
- `App/LengyanApp.swift`: SwiftUI @main app entry point
- `lengyan/AppDelegate.swift`: UIKit app delegate (active entry point)

**Configuration:**
- `lengyan/Info.plist`: App configuration (bundle ID, permissions, etc.)
- `lengyan/Domain/Constants.swift`: App constants (KEY_PATHS, DEFAULT_STARTS)

**Core Logic:**
- `lengyan/Domain/Book.swift`: Sutra content manager (singleton)
- `lengyan/Domain/AudioManager.swift`: Audio playback manager (singleton)
- `lengyan/Domain/Prefers.swift`: User preferences (singleton)

**Design System:**
- `lengyan/Design/DesignSystem+Tokens.swift`: Color, shape, motion tokens
- `lengyan/Design/DesignSystem+Typography.swift`: Font system with Chinese support
- `lengyan/Design/DesignSystem+Spacing.swift`: Layout spacing constants

**UI Components:**
- `lengyan/View/SutraFrontViewController.swift`: Main reading interface
- `lengyan/SwiftUI/ModernAudioPlayerView.swift`: Audio player UI
- `lengyan/SwiftUI/ModernFavoritesView.swift`: Bookmarks UI

**Data Files:**
- `lengyan/data/lengyanjing-content.json`: Full sutra text content
- `lengyan/data/lengyanjing-index-tree.json`: Hierarchical content tree
- `lengyan/data/lengyanjing-media.json`: Audio metadata

**Testing:**
- `lengyanTests/`: Unit tests for domain and view models
- `lengyanUITests/`: UI tests for user flows
- `Tests/`: Additional test suites (snapshots, performance, design system)

## Naming Conventions

**Files:**
- UIKit View Controllers: `Sutra[Name]ViewController.swift` (e.g., `SutraFrontViewController.swift`)
- SwiftUI Views: `Modern[Name]View.swift` or `[Name]View.swift` (e.g., `ModernAudioPlayerView.swift`)
- Domain Models: `[Name]Models.swift` or just `[Name].swift` (e.g., `MediaModels.swift`)
- Managers/Services: `[Name]Manager.swift` (e.g., `AudioManager.swift`)
- Extensions: `[Type]+[Category].swift` (e.g., `String+Common.swift`, `UIView+Common.swift`)
- Design System: `DesignSystem+[Category].swift` (e.g., `DesignSystem+Tokens.swift`)

**Directories:**
- Singular names for layers: `Domain/`, `Design/`, `View/`, `Util/`
- Descriptive names for features: `SwiftUI/`, `Core/`, `data/`
- Localization: `[lang].lproj/` (e.g., `zh-Hans.lproj/`)

**Classes/Structs:**
- UIKit classes: PascalCase (e.g., `SutraFrontViewController`)
- SwiftUI views: PascalCase (e.g., `ModernAudioPlayerView`)
- Singletons: Shared instance via `.shared` static property
- Design tokens: Enum-based with PascalCase cases (e.g., `ColorToken.background`)

**Functions:**
- camelCase for methods (e.g., `itemOfPath()`, `getNextPagePath()`)
- Private methods prefixed with `private` or have `_` prefix in some cases

**Variables:**
- camelCase for properties (e.g., `mediaGroups`, `isLoading`)
- Constants: UPPER_SNAKE_CASE (e.g., `KEY_PATHS`, `DEFAULT_STARTS`)

## Where to Add New Code

**New Feature (Reading-related):**
- Primary code: `lengyan/View/` (if UIKit) or `lengyan/SwiftUI/` (if SwiftUI)
- Tests: `lengyanTests/` (unit tests) or `lengyanUITests/` (UI tests)

**New Feature (Audio-related):**
- Primary code: `lengyan/SwiftUI/` (e.g., `ModernAudioPlayerView.swift`)
- Domain logic: `lengyan/Domain/AudioManager.swift` or new `*Manager.swift`
- Tests: `lengyanTests/AudioPlayerViewModelTests.swift`

**New Feature (Settings/Preferences):**
- Primary code: `lengyan/SwiftUI/ModernSettingsView.swift`
- Preferences storage: `lengyan/Domain/Prefers.swift`
- Tests: `lengyanTests/SettingsViewModelTests.swift`

**New Domain Logic:**
- Implementation: `lengyan/Domain/[Name].swift` or `lengyan/Domain/[Name]Manager.swift`
- Tests: `lengyanTests/[Name]Tests.swift`

**New Design Tokens:**
- Implementation: `lengyan/Design/DesignSystem+Tokens.swift` (add to enums)
- Typography: `lengyan/Design/DesignSystem+Typography.swift` (add text styles)
- Spacing: `lengyan/Design/DesignSystem+Spacing.swift` (add spacing tokens)

**New View Models:**
- Implementation: Create new file in appropriate directory
- For SwiftUI views: Co-locate with view or place in `lengyan/SwiftUI/`
- For UIKit: Consider placing in `lengyan/Domain/` or create `ViewModels/` directory

**New Utilities:**
- Shared helpers: `lengyan/Util/Utils.swift` or create new `[Name]+Common.swift`
- Tests: `lengyanTests/` or `Tests/`

**New Data Sources:**
- JSON files: `lengyan/data/` (traditional) or `lengyan/data/simplified/` (simplified Chinese)
- Access logic: Add methods to `lengyan/Domain/Book.swift`

## Special Directories

**lengyan/Assets.xcassets/:**
- Purpose: Asset catalog for images, colors, icons
- Generated: No
- Committed: Yes
- Contains: App icons, UI images, color sets

**lengyan/Fonts/:**
- Purpose: Custom font files for Chinese typography
- Generated: No
- Committed: Yes
- Contains: .ttf/.otf font files

**lengyan/data/simplified/:**
- Purpose: Simplified Chinese versions of JSON data
- Generated: No
- Committed: Yes
- Contains: Same structure as parent `data/` directory

**lengyan/source-media/:**
- Purpose: Source audio files for On-Demand Resources
- Generated: No
- Committed: Yes (but large files may be in LFS)
- Contains: Audio file references

**lengyan/Util/RATreeView/:**
- Purpose: Third-party tree view component library
- Generated: No
- Committed: Yes
- Contains: Embedded Objective-C library

**lengyan/Performance/:**
- Purpose: Performance monitoring and optimization utilities
- Generated: No
- Committed: Yes
- Contains: Performance tracking code

**screenshots/:**
- Purpose: App screenshots for App Store and documentation
- Generated: Yes (by screenshot tools)
- Committed: Yes
- Contains: PNG files of app screens

**scripts/:**
- Purpose: Build automation and development tools
- Generated: No
- Committed: Yes
- Contains: Shell scripts for building, testing, and automation

---

*Structure analysis: 2026-04-06*
