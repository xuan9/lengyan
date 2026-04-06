# Codebase Concerns

**Analysis Date:** 2026-04-06

## Tech Debt

**Force Unwrapping in Critical Data Loading:**
- Issue: `Book.swift` uses force unwrapping (`!`) on optional Data objects after `try?` which silently fails
- Files: `lengyan/Domain/Book.swift` lines 48-51, 57-60, 67-69, 86-89
- Impact: If JSON files are missing or corrupted, app crashes with force unwrap on nil data. Silent failure with `try?` then force unwrap defeats error handling
- Fix approach: Replace `try?` with proper `do-catch` blocks, provide graceful fallback or user-facing error messages

**Polling Loop with Thread.sleep:**
- Issue: `AppDelegate.swift` uses `Thread.sleep()` in a 100-iteration polling loop to wait for `Book.shared.loaded`
- Files: `lengyan/AppDelegate.swift` lines 42-48
- Impact: Blocks thread for up to 10 seconds on app launch if data loading is slow. Wastes CPU cycles. Not a modern async pattern
- Fix approach: Use Combine, async/await, or completion handlers instead of polling. Consider showing loading state

**Mixed UIKit/SwiftUI Architecture:**
- Issue: App uses both UIKit (`SutraFrontViewController`, `SutraPageViewController`) and SwiftUI (`ModernAudioPlayerView`, `ModernFavoritesView`) without clear separation
- Files: `lengyan/View/`, `lengyan/SwiftUI/`
- Impact: Navigation complexity, duplicated logic, inconsistent state management. UIHostingController wrappers add overhead
- Fix approach: Complete SwiftUI migration or establish clear protocol boundaries between UIKit and SwiftUI layers

**Empty Core Layer Directories:**
- Issue: `Core/Data/Models`, `Core/Data/Repositories`, `Core/Domain/Services` directories exist but contain no Swift files
- Files: `lengyan/Core/Data/Models/`, `lengyan/Core/Data/Repositories/`, `lengyan/Core/Domain/Services/`
- Impact: Suggested architecture not implemented. Domain logic remains in `Domain/` singletons. Code organization doesn't match directory structure
- Fix approach: Either implement the layered architecture or remove empty directories to avoid confusion

**Hardcoded Path Constants:**
- Issue: 200-line `KEY_PATHS` array manually defines navigation hierarchy
- Files: `lengyan/Domain/Constants.swift` lines 12-214
- Impact: Brittle to content changes. Requires code updates when sutra structure changes. Not data-driven
- Fix approach: Derive navigation paths from `lengyanjing-index-tree.json` structure dynamically

## Known Bugs

**TODO Comments in Production Code:**
- Symptoms: Two unresolved TODO comments indicate incomplete migration
- Files: `lengyan/View/SutraFrontViewController.swift` lines 156, 943
- Trigger: Code review grep for "TODO"
- Workaround: None known. Theme migration may be incomplete
- Impact: Unknown. Theme observer may not be properly connected

**No Known Critical Bugs** - Additional bug tracking not evident in code comments or issues

## Security Considerations

**No External API Secrets:**
- Risk: Minimal. No hardcoded API keys, secrets, or credentials detected
- Files: None found
- Current mitigation: App uses only bundled JSON data, no external API calls
- Recommendations: Continue avoiding hardcoded secrets. Use entitlements/provisioning properly for App Store

**UserDefaults Without Encryption:**
- Risk: User preferences stored in plain text in UserDefaults
- Files: `lengyan/Domain/Prefers.swift`
- Current mitigation: Data stored is non-sensitive (reading progress, favorites, font size)
- Recommendations: No action needed for current data types. If adding sensitive user data, use Keychain

**No Certificate Pinning:**
- Risk: Not applicable - app doesn't make external network requests
- Files: N/A
- Current mitigation: N/A
- Recommendations: If adding remote content or features, implement certificate pinning

## Performance Bottlenecks

**Force JSON Parsing on Main Thread:**
- Problem: `Book.loadDataSyncWithCompletionHandler()` parses large JSON files (306KB content, 139KB tree) synchronously
- Files: `lengyan/Domain/Book.swift` lines 41-103
- Cause: JSON parsing uses `JSONSerialization.jsonObject()` which is CPU-intensive
- Impact: App launch blocked for 100-500ms depending on device. Thread.sleep polling makes this worse
- Improvement path: Move parsing to background queue, use `Codable` for better performance, consider lazy loading

**Large View Controllers:**
- Problem: `SutraFrontViewController.swift` (962 lines), `SutraPageContentViewControllera.swift` (702 lines) violate single responsibility
- Files: `lengyan/View/SutraFrontViewController.swift`, `lengyan/View/SutraPageContentViewControllera.swift`
- Cause: UI, navigation, theming, data processing all mixed in view controllers
- Impact: Difficult to maintain, test, and optimize. Potential memory leaks from complex view hierarchies
- Improvement path: Extract view models, separate concerns, use composition over massive view controllers

**No Database for Reading Progress:**
- Problem: Reading progress stored in UserDefaults as flat dictionary
- Files: `lengyan/Domain/Prefers.swift` line 71
- Cause: Simple persistence without considering scale
- Impact: As user reads more content, UserDefaults lookup slows. No query capability for progress analytics
- Improvement path: Consider SQLite/Core Data for structured progress tracking if adding progress analytics

**Favorites Cache Invalidation:**
- Problem: `FavoritesCache` uses 5-minute timeout but may show stale data
- Files: `lengyan/SwiftUI/ModernFavoritesView.swift` lines 26-83
- Cause: Time-based invalidation doesn't account for actual data changes
- Impact: Users may see outdated favorites list until cache expires or manually invalidated
- Improvement path: Use `Combine` publishers or `@Published` properties for reactive cache invalidation

## Fragile Areas

**Book Singleton State:**
- Files: `lengyan/Domain/Book.swift`
- Why fragile: Global mutable state accessed throughout app. `loaded` flag must be checked before every access. No dependency injection
- Safe modification: Wrap `Book.shared` access in a repository layer with proper error handling. Consider making loaded state a publisher
- Test coverage: Limited. Tests exist (`BookTests.swift`) but don't cover edge cases like missing data files

**Tight View Controller Coupling:**
- Files: `lengyan/View/SutraIndexViewController.swift` lines 258-294, `lengyan/View/SutraPageViewController.swift`
- Why fragile: View controllers create each other directly, pass closures for callbacks. Hard to unit test
- Safe modification: Introduce coordinator pattern or use navigation protocols. View controllers should be routeable, not create each other
- Test coverage: Minimal. No tests for view controller navigation or lifecycle

**NotificationCenter Dependencies:**
- Files: `lengyan/View/SutraPageContentViewControllera.swift`, `lengyan/View/SutraFrontViewController.swift`
- Why fragile: Theme changes via NotificationCenter. Observers not always removed in deinit (some views missing cleanup)
- Safe modification: Use Combine publishers or a theme manager protocol. Ensure observers removed in deinit
- Test coverage: None. Theme changes not tested

**Audio Session Management:**
- Files: `lengyan/Domain/AudioManager.swift`, `lengyan/Domain/AudioPlayerObserver.swift`
- Why fragile: Global `AVAudioSession` configuration can conflict with other audio apps or system sounds
- Safe modification: Make audio session configuration lazy, handle interruptions properly, test with phone calls/alarm interruptions
- Test coverage: None. Audio playback requires physical device, no unit tests

## Scaling Limits

**JSON Bundle Size:**
- Current capacity: ~575KB total JSON data (306KB content + 139KB tree + 132KB index)
- Limit: Bundle size increases app download size. Memory usage scales linearly with content
- Scaling path: Consider On-Demand Resources (ODR) for audio is already implemented. Could use ODR for rarely-read sutra sections

**UserDefaults Storage:**
- Current capacity: Favorites list ~50 items typical, reading progress for all sections
- Limit: UserDefaults has no strict limit but performance degrades with large data
- Scaling path: Migrate to Core Data if exceeding ~1000 favorites or want progress analytics

**Audio ODR Downloads:**
- Current capacity: Individual audio files downloaded on demand via NSBundleResourceRequest
- Limit: User storage space, network speed
- Scaling path: Already implemented well. Consider download quality options for slow networks

**No Backend/Cloud Sync:**
- Current capacity: Local-only app with no user accounts
- Limit: Reading progress, favorites don't sync across devices
- Scaling path: If adding sync, consider CloudKit for privacy-friendly approach without building backend

## Dependencies at Risk

**Deprecated AVAudioSession APIs:**
- Risk: `AVAudioSessionCategoryPlayback` and `AVAudioSessionModeDefault` are older APIs
- Impact: Audio playback may break in future iOS versions
- Migration plan: Use `AVAudioSession.Category.playback` and `AVAudioSession.Mode.default` (Swift-style enums)

**RATreeView Third-Party:**
- Risk: Custom RATreeView implementation in `Util/RATreeView/` not maintained
- Impact: May have compatibility issues with future iOS versions
- Migration plan: Consider migrating to `UITableView` with standard APIs or SwiftUI `OutlineGroup`

**No Package Manager:**
- Risk: No CocoaPods, Swift Package Manager, or Carthage dependencies listed
- Impact: All dependencies are vendored or custom. Hard to update
- Migration plan: If adding dependencies, use SPM for native iOS package management

## Missing Critical Features

**No Crash Reporting:**
- Problem: No Firebase Crashlytics, Sentry, or similar crash reporting
- Blocks: Cannot diagnose production crashes
- Impact: Silent failures, poor user experience for crashes
- Recommendations: Add crash reporting SDK before next App Store release

**No Analytics:**
- Problem: No usage tracking, feature adoption metrics, or reading progress analytics
- Blocks: Data-driven decisions for feature prioritization
- Impact: Development based on assumptions rather than user behavior
- Recommendations: Consider privacy-focused analytics (no user tracking, just feature usage)

**No Search Functionality:**
- Problem: Sutra content is not searchable despite being text-based
- Blocks: Users cannot find specific passages or topics
- Impact: Limited utility for study and reference
- Recommendations: Add full-text search using CoreData or SQLite FTS5

**No Reading Progress Sync:**
- Problem: Reading progress stored locally only
- Blocks: Multi-device usage
- Impact: Users lose progress when switching devices
- Recommendations: Implement CloudKit sync for reading progress and favorites

## Test Coverage Gaps

**What's not tested:**
- View controller lifecycle and navigation
- Audio playback and interruption handling
- Theme switching and color application
- Favorites cache invalidation
- Notification scheduling
- ODR download failures
- File I/O error handling (missing/corrupt JSON)

**Files:**
- `lengyan/View/*.swift` (no UI tests)
- `lengyan/Domain/AudioManager.swift` (no tests)
- `lengyan/Domain/AudioPlayerObserver.swift` (no tests)
- `lengyan/Domain/ReminderManager.swift` (no tests)
- `lengyan/Design/` (no tests)

**Risk:**
- UI bugs could reach production undetected
- Audio playback failures not caught in CI
- Theme inconsistencies across iOS versions
- Data loss if file reading fails silently

**Priority:**
- High: Add UI tests for critical navigation flows
- High: Add error handling tests for data loading
- Medium: Add unit tests for audio managers
- Low: Design system visual regression tests

---

*Concerns audit: 2026-04-06*
