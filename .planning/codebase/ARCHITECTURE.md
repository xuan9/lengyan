# Architecture

**Analysis Date:** 2026-04-06

## Pattern Overview

**Overall:** Hybrid UIKit/SwiftUI with Legacy Domain Layer

The codebase follows a hybrid architecture pattern combining:
- **Traditional iOS MVC** for main reading flow (UIKit view controllers)
- **SwiftUI** for modern features (audio player, favorites, settings)
- **Singleton Domain Layer** for business logic and data management
- **Design System** for centralized styling and theming

**Key Characteristics:**
- Path-based navigation system using hierarchical paths (e.g., `/A2/B1/C2`)
- JSON-driven content loading with separate files for tree, content, index, and media
- Unified design system with type-safe tokens for colors, typography, and spacing
- Audio playback with On-Demand Resources (ODR) for efficient asset delivery
- Tab-based main navigation with 4 primary sections

## Layers

**View Layer (UIKit + SwiftUI):**
- Purpose: Display content and handle user interaction
- Location: `lengyan/View/`, `lengyan/SwiftUI/`, `App/`
- Contains: View controllers for reading, SwiftUI views for modern features
- Depends on: Domain layer (Book, AudioManager), Design system
- Used by: AppDelegate, Tab bar controller

**Domain Layer:**
- Purpose: Business logic, data management, state management
- Location: `lengyan/Domain/`
- Contains: Book (singleton), AudioManager, Prefers, ReminderManager, Constants
- Depends on: Foundation, UIKit, AVFoundation, SwiftUI
- Used by: All view controllers and SwiftUI views

**Design System Layer:**
- Purpose: Centralized styling, theming, typography, and layout tokens
- Location: `lengyan/Design/`
- Contains: DesignSystem+Tokens, DesignSystem+Typography, DesignSystem+Spacing, DesignSystem+Layout, DesignSystem+Accessibility
- Depends on: UIKit, SwiftUI
- Used by: All views and view controllers

**Utility Layer:**
- Purpose: Helper functions and extensions
- Location: `lengyan/Util/`
- Contains: String extensions, UIView extensions, navigation helpers, third-party libraries (RATreeView)
- Depends on: UIKit, Foundation
- Used by: View controllers

**Data Layer:**
- Purpose: JSON data storage and loading
- Location: `lengyan/data/`, `lengyan/data/simplified/`
- Contains: JSON files for content tree, index, media metadata, chapter map
- Depends on: Bundle resources
- Used by: Book singleton

## Data Flow

**App Launch Flow:**

1. `AppDelegate.application(_:didFinishLaunchingWithOptions:)` is called
2. `Book.shared.loadDataSyncWithCompletionHandler()` loads JSON data
3. `SutraDesignTokens.shared.loadSavedTheme()` loads and applies theme
4. `setupMainUI()` creates tab bar controller with 4 tabs
5. `setupTabs(for:)` configures Reading, Listening, Favorites, Settings tabs

**Reading Flow:**

1. User taps Reading tab → `SutraFrontViewController` displays hierarchical tree
2. User taps item → `SutraIndexViewController` shows subsections or navigates to content
3. User taps leaf node → `SutraPageViewController` displays paginated content
4. `SutraPageContentViewControllera` renders actual sutra text with typography

**Audio Playback Flow:**

1. User taps Listening tab → `ModernAudioPlayerView` (SwiftUI) displays audio list
2. `AudioManager.loadMediaData()` parses media JSON from `Book.shared.media`
3. User taps track → `AudioManager.handleMediaItemTap()` checks download status
4. If not downloaded → ODR download begins with progress tracking
5. Once downloaded → `AudioPlayerObserver` manages AVPlayer playback

**State Management:**
- `Book.shared` - Singleton managing all sutra content (tree, contents, index, media)
- `AudioManager.shared` - ObservableObject managing audio playback state
- `Prefers.shared` - Singleton managing user preferences (likes, font size, reminders)
- `SutraDesignTokens.shared` - Singleton managing current theme and design tokens

## Key Abstractions

**Path-Based Navigation:**
- Purpose: Hierarchical content addressing system
- Examples: `/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K2/L2/M2`
- Pattern: Tree traversal with component IDs separated by `/`
- Key constants: `KEY_PATHS` array defines major navigation points
- Implementation: `Book.itemOfPath()`, `Book.getNextPagePath()`, `Book.getPreviousPagePath()`

**Content Hierarchy:**
- Purpose: Tree-structured sutra content organization
- Examples: `lengyan/data/lengyanjing-index-tree.json`
- Pattern: Nested dictionaries with `id`, `name`, `path`, `children` keys
- Implementation: Recursive tree loading in `Book.loadDataSyncWithCompletionHandler()`

**Design Token System:**
- Purpose: Type-safe, centralized styling with theme support
- Examples: `ColorToken.background`, `ShapeToken.cornerRadiusMedium`, `SutraTypographyManager.shared.uiFont(for: .sutraBody)`
- Pattern: Enum-based tokens with protocol-based theme implementations
- Implementation: `SutraDesignTokens.shared.color(for: token)`, theme switching via `currentTheme` property

**Typography System:**
- Purpose: Unified Chinese font rendering with proper sizing and weights
- Examples: `SutraTypography.TextStyle.sutraBody`, `SutraTypography.TextStyle.navigationTitle`
- Pattern: Type-safe enum for text styles with fallback fonts
- Implementation: `SutraTypographyManager.shared.uiFont(for: weight:)`

## Entry Points

**App Entry Point:**
- Location: `App/LengyanApp.swift` (SwiftUI App protocol)
- Triggers: iOS app launch
- Responsibilities: Creates main SwiftUI App structure, configures DI container, loads theme

**AppDelegate Entry Point:**
- Location: `lengyan/AppDelegate.swift`
- Triggers: iOS app lifecycle events
- Responsibilities: Loads book data, sets up tab bar UI, configures appearance, handles notifications, manages audio session

**Tab Bar Entry Points:**
- **Reading Tab:** `SutraFrontViewController` (UIKit)
- **Listening Tab:** `ModernAudioPlayerView` (SwiftUI)
- **Favorites Tab:** `ModernFavoritesView` (SwiftUI)
- **Settings Tab:** `ModernSettingsView` (SwiftUI)

**Coordinator Entry Point (Future/New Architecture):**
- Location: `App/Coordinator/AppCoordinator.swift`
- Triggers: Programmatic navigation
- Responsibilities: Manages navigation flow, creates child coordinators, configures DI container
- Note: Present but not actively used in current tab-based architecture

## Error Handling

**Strategy:** Minimal explicit error handling with graceful degradation

**Patterns:**
- JSON parsing failures return empty dictionaries/arrays (e.g., `self.tree = [:]`)
- ODR download errors show console logs but don't crash
- Missing paths return `nil` or empty strings
- Audio playback failures log errors but maintain UI state
- No centralized error reporting system

**Gaps:**
- No user-facing error messages for data loading failures
- No retry mechanisms for failed downloads
- No error tracking/analytics integration

## Cross-Cutting Concerns

**Logging:** Console print statements throughout (no structured logging)
**Validation:** Minimal input validation throughout the codebase
**Authentication:** None (local app with no user accounts)
**Persistence:** UserDefaults for preferences, no database
**Theming:** Centralized via `SutraDesignTokens.shared` with notification-based updates
**Accessibility:** Basic accessibility support via `DesignSystem+Accessibility.swift`
**Localization:** Chinese (Simplified and Traditional) via `.lproj` directories
**Background Audio:** AVAudioSession configuration in `AudioManager.setupAudioSession()`
**Notifications:** UNUserNotification for daily reading reminders

---

*Architecture analysis: 2026-04-06*
