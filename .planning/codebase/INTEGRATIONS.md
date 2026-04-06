# External Integrations

**Analysis Date:** 2026-04-06

## APIs & External Services

**None detected**
- No external API calls or web service integrations
- No network-based functionality
- All content is bundled with the app

## Data Storage

**Databases:**
- None (no database used)

**File Storage:**
- Local bundle resources only
- JSON data files in `lengyan/data/` and `lengyan/data/simplified/`
  - `lengyanjing-index-tree.json` - Content hierarchy
  - `lengyanjing-content.json` - Full sutra text content
  - `lengyanjing-index.json` - Content index
  - `lengyanjing-media.json` - Audio metadata
  - `lengyanjing-chapter-map.json` - Chapter navigation mapping
- Audio files: M4A format in `lengyan/屏東能淨協會讀誦/` (bundled)
- Custom fonts: LXG WenKai (Simplified/Traditional variants) in `lengyan/Fonts/`

**Caching:**
- In-memory only (Book.shared singleton)
- NSUserDefaults via Prefers.shared for user preferences
- No persistent cache layer

## Authentication & Identity

**Auth Provider:**
- None - No user accounts or authentication
- Local app preferences only

## Monitoring & Observability

**Error Tracking:**
- None - No crash reporting or analytics integrated
- Console logging only (print statements for debugging)

**Logs:**
- Console output via `print()` statements
- No structured logging framework

## CI/CD & Deployment

**Hosting:**
- Apple App Store (inferred from iOS app structure)

**CI Pipeline:**
- None detected in project
- Build scripts present: `scripts/build_and_install.sh` (local development only)

## Environment Configuration

**Required env vars:**
- None - App uses embedded resources only
- No API keys or external service credentials

**Secrets location:**
- N/A - No secrets required for operation

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Apple System Integrations

**UserNotifications.framework**
- Location: `lengyan/Domain/ReminderManager.swift`
- Purpose: Daily reading reminder notifications
- Auth: User permission requested at runtime via `UNUserNotificationCenter.requestAuthorization()`
- Triggers: Time-based daily reminders (hour/minute from Prefers.shared)

**AVFoundation.framework**
- Location: `lengyan/Domain/AudioManager.swift`, `lengyan/Domain/AudioPlayerObserver.swift`
- Purpose: Audio playback with background support
- Features:
  - AVQueuePlayer for audio queue management
  - AVAudioSession configuration for background playback
  - Remote control events (play/pause/skip)

**On-Demand Resources (ODR)**
- Location: `lengyan/Domain/AudioManager.swift`
- Purpose: Lazy loading of audio files to reduce initial app size
- Implementation: `NSBundleResourceRequest` with tags (ly01-ly10, lyz1)
- Status tracking: Download progress and error handling

---

*Integration audit: 2026-04-06*
