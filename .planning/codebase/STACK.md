# Technology Stack

**Analysis Date:** 2026-04-06

## Languages

**Primary:**
- Swift 4.0 - iOS application development (UIKit + SwiftUI hybrid)

**Secondary:**
- Objective-C - RATreeView third-party library integration (bridged via `lengyan-Bridging-Header.h`)
- Shell Script - Build automation (`scripts/build_and_install.sh`, `scripts/start-wda.sh`, `scripts/stop-wda.sh`)

## Runtime

**Environment:**
- iOS 15.0+ (minimum deployment target)
- iPhone and iPad (universal bundle)

**Package Manager:**
- Xcode native build system (no CocoaPods, no SPM packages detected)
- Lockfile: None (no dependency lock file present)

## Frameworks

**Core:**
- UIKit - Legacy view controllers and navigation
- SwiftUI - Modern UI for audio player, favorites, settings views
- Foundation - Core data types and JSON serialization
- AVFoundation - Audio playback (AVPlayer, AVAudioSession)

**Testing:**
- XCTest - Unit tests and UI tests (built into Xcode)

**Build/Dev:**
- Xcode Build System - Native compilation
- WebDriverAgent - Mobile testing MCP integration (scripts: `start-wda.sh`, `stop-wda.sh`)

## Key Dependencies

**Critical:**
- RATreeView (Objective-C) - Tree structure UI component for sutra index navigation
  - Location: `lengyan/Util/RATreeView/`
  - Bridged via: `lengyan/lengyan-Bridging-Header.h`

**Infrastructure:**
- None detected - Purely native iOS with no external SDKs or frameworks

## Configuration

**Environment:**
- Bundle ID: `org.fuxuan.lengyan`
- Development Team: A37UYHPM4V
- Code Signing: Automatic provisioning
- Languages: Simplified Chinese (zh-Hans), Traditional Chinese (zh-Hant)
  - System locale-based content loading from `data/` or `data/simplified/`

**Build:**
- Project: `lengyan.xcodeproj`
- Info.plist: `lengyan/Info.plist`
- Build configuration: Debug/Release (standard Xcode configurations)
- Asset tags for ODR: ly01, ly02, ly03, ly04, ly05, ly06, ly07, ly08, ly09, ly10, lyz1

## Platform Requirements

**Development:**
- Xcode 7.3.1+ (project created with)
- Xcode 16.4 compatibility (LastUpgradeCheck)
- iOS 15.0+ SDK
- Physical device required for full audio testing (background playback)

**Production:**
- iOS 15.0+ deployment target
- Universal app (iPhone + iPad)
- App Store distribution via automatic code signing
- Background audio mode enabled (for audio playback)

---

*Stack analysis: 2026-04-06*
