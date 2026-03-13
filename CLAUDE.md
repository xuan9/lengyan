# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native iOS application called "LengYan" (楞严) - a Buddhist sutra reading and audio playback app. The app displays the Shurangama Sutra (楞严经) with both text reading and audio playback capabilities. The app supports both Simplified and Traditional Chinese based on system locale.

## Development Commands

### Building & Running
- Open `lengyan.xcodeproj` in Xcode
- Build: Cmd+B 
- Run: Cmd+R
- The app targets iOS and uses Xcode's standard build system

### Testing
- Run tests: Cmd+U
- Test files are in `lengyanTests/` and `lengyanUITests/`

### Mobile MCP Testing Setup
To use Mobile MCP for automated testing and screenshots:

#### Quick Start (Recommended)
```bash
# Start WebDriverAgent (only runs if not already running)
./scripts/start-wda.sh

# When done testing
./scripts/stop-wda.sh
```

#### How It Works
- WebDriverAgent runs as a background server on the iOS Simulator
- Once started, it stays running until you stop it or restart the simulator
- No need to reinstall or restart between test sessions
- The helper scripts check if it's already running to avoid duplicate processes

#### Manual Start (if needed)
```bash
cd ~/github/WebDriverAgent
xcodebuild -project WebDriverAgent.xcodeproj \
           -scheme WebDriverAgentRunner \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           test
```

#### Verify WebDriverAgent Status
- Check if running: `pgrep -f "WebDriverAgentRunner" || echo "Not running"`
- Server endpoint: http://localhost:8100
- Look for "ServerURLHere->http://..." in xcodebuild output

#### Available Mobile MCP Tools
Once WebDriverAgent is running, use these tools:
- `mobile_list_available_devices` - List connected simulators/devices
- `mobile_take_screenshot` - Capture app screenshots
- `mobile_list_elements_on_screen` - Inspect UI hierarchy
- `mobile_click_on_screen_at_coordinates` - Automate taps
- `mobile_swipe_on_screen` - Test scrolling/gestures
- `mobile_type_keys` - Input text
- `mobile_press_button` - Press system buttons (HOME, BACK, etc.)

#### Troubleshooting
- **"Device not found"**: Check simulator is booted with `xcrun simctl list devices | grep Booted`
- **Connection refused**: Restart WebDriverAgent with `./scripts/stop-wda.sh && ./scripts/start-wda.sh`
- **Simulator crashed**: Reset simulator and restart WebDriverAgent

## Architecture & Code Structure

### Core Data Model
- **Book.swift** (`lengyan/Domain/Book.swift`): Central singleton for all sutra content
  - Loads JSON data files from `lengyan/data/` (Traditional) or `lengyan/data/simplified/` (Simplified Chinese)
  - Manages hierarchical sutra structure with tree navigation
  - Provides text formatting and pagination logic
  - Key methods: `itemOfPath()`, `getSutra()`, `getNextPagePath()`, `getPreviousPagePath()`

### Audio System
- **AudioPlayerManager.swift** (`lengyan/Domain/AudioPlayerManager.swift`): Global audio playback manager
  - Singleton pattern with `@Published` properties for SwiftUI binding
  - Handles AVPlayer setup, background playback, and remote control center
  - MediaItem struct defines audio track metadata

### User Interface Architecture
The app follows a hybrid UIKit/SwiftUI approach:

#### Main Navigation
- **AppDelegate.swift**: Entry point, sets up navigation 
#### Reading Interface
- **SutraPageViewController.swift**: UIKit page view controller for reading
- **SutraBookViewController.swift**: Chapter/book navigation

#### Audio Interface
- **MediaTableViewController.swift**: Audio track listing and playback controls

#### Supporting Views
- **SutraIndexViewController.swift**: Hierarchical content navigation with RATreeView
- **StarsTableViewController.swift**: User bookmarks/favorites

### Data Structure
- **JSON Files**: Content stored in JSON format in `lengyan/data/`
  - `lengyanjing-index-tree.json`: Hierarchical content structure
  - `lengyanjing-content.json`: Full text content
  - `lengyanjing-media.json`: Audio track metadata
  - `lengyanjing-index.json`: Content index

### Constants & Configuration
- **Constants.swift**: Defines KEY_PATHS array for content navigation hierarchy
- **Prefers.swift**: User preferences and settings persistence
- **NotificationNames.swift**: Custom notification names for app communication

### Utilities
- **RATreeView/**: Third-party tree view component for hierarchical navigation
- **String+Common.swift**, **UIView+Common.swift**: Swift extensions
- **Utils.swift**: General utility functions

## Key Implementation Patterns

### Data Loading
- Book data loads synchronously on app start via `Book.shared.loadDataSyncWithCompletionHandler()`
- Content supports both Simplified (`isSimplifiedChinese = true`) and Traditional Chinese

### Navigation of the book content
- Path-based navigation using hierarchical strings (e.g., "/A2/B1/C2")
- `Book.shared.itemOfPath(path)` retrieves content by path
- Pagination logic handles both key pages and full content index


### Localization
- Supports multiple languages with `.lproj` folders
- Localizable strings in Base, zh-Hans (Simplified), zh-Hant (Traditional)

## Working with This Codebase

### When Adding Features
- Use the existing `Book.shared` singleton for content access
- Follow the path-based navigation pattern for new content views
- Use SwiftUI for new UI components, UIKit for complex navigation

### When Debugging
- Check `Book.shared.loaded` status for data loading issues
- Audio issues often relate to AVAudioSession configuration in AudioPlayerManager
- Path resolution problems should check `KEY_PATHS` in Constants.swift

### Testing Considerations
- App requires JSON data files to be present in bundle
- Audio functionality needs physical device for full testing
- Different behavior between Simplified/Traditional Chinese modes

## Architecture Lessons Learned

**Simple apps need simple solutions** - Question whether "best practices" actually apply to your specific context before implementing them blindly.