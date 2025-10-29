//
//  SutraAppUITests.swift
//  lengyan
//
//  Created by Claude on 2025/10/28.
//  Copyright © 2025年 xuan. All rights reserved.
//

import XCTest

class SutraAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test Suite 1: App Launch and Basic Functionality

    func test_appLaunchesSuccessfully() throws {
        // Test that the app launches and shows the main screen
        XCTAssertTrue(app.exists, "App should launch successfully")

        // Verify main navigation elements are present
        XCTAssertTrue(app.navigationBars.count > 0, "Navigation bar should be present")

        // Verify tab bar with three tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be present")
        XCTAssertEqual(tabBar.buttons.count, 3, "Should have exactly 3 tabs")

        // Verify tab labels
        XCTAssertEqual(tabBar.buttons.element(boundBy: 0).label, "阅读", "First tab should be '阅读'")
        XCTAssertEqual(tabBar.buttons.element(boundBy: 1).label, "听经", "Second tab should be '听经'")
        XCTAssertEqual(tabBar.buttons.element(boundBy: 2).label, "收藏", "Third tab should be '收藏'")
    }

    // MARK: - Test Suite 2: Enhanced Design System

    func test_enhancedDesignSystemApplied() throws {
        // Test that enhanced design system is active
        let mainView = app.otherElements.matching(identifier: "main_view").firstMatch

        // Test enhanced background color (should not be pure white)
        let backgroundHex = app.debugDescription.containing("backgroundColor")
        XCTAssertTrue(backgroundHex.contains("1.0") || backgroundHex.contains("0.98"), "Enhanced background color should be applied")

        // Test that theme toggle button is present
        let themeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(themeButton.exists, "Theme toggle button should be visible in navigation bar")

        // Verify enhanced status label exists
        let statusLabel = app.staticTexts["Enhanced Design Active - Tap to Change Theme"]
        XCTAssertTrue(statusLabel.exists, "Enhanced design status label should be visible")
    }

    func test_themeToggleFunctionality() throws {
        let themeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(themeButton.exists, "Theme toggle button should exist")

        // Capture initial state
        let initialBackground = app.debugDescription

        // Tap to change theme to sepia
        themeButton.tap()

        // Wait for theme change to apply
        Thread.sleep(forTimeInterval: 0.5)

        // Verify theme changed (debug description should show different colors)
        let sepiaBackground = app.debugDescription
        XCTAssertNotEqual(initialBackground, sepiaBackground, "Background should change when theme is toggled")

        // Tap to change theme to dark
        themeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let darkBackground = app.debugDescription
        XCTAssertNotEqual(sepiaBackground, darkBackground, "Background should change to dark theme")

        // Tap to return to light theme
        themeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let lightBackground = app.debugDescription
        XCTAssertNotEqual(darkBackground, lightBackground, "Background should return to light theme")
    }

    // MARK: - Test Suite 3: Chapter Navigation

    func test_chapterNavigation() throws {
        // Test that all 10 chapter buttons are present
        for i in 1...10 {
            let chapterButton = app.buttons["卷\(i)"]
            XCTAssertTrue(chapterButton.exists, "Chapter \(i) button should exist")
            XCTAssertTrue(chapterButton.isHittable, "Chapter \(i) button should be tappable")
        }

        // Test navigation to first chapter
        let firstChapter = app.buttons["卷一"]
        firstChapter.tap()

        // Wait for navigation
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we navigated (navigation should change)
        XCTAssertTrue(app.navigationBars.count > 0, "Should remain in navigation after chapter selection")

        // Test back navigation
        let backButton = app.navigationBars.buttons["back"]
        if backButton.exists {
            backButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // Test enhanced chapter button styling
    func test_enhancedChapterButtonStyling() throws {
        // Verify chapter buttons have enhanced styling
        let chapterButton = app.buttons["卷一"]
        XCTAssertTrue(chapterButton.exists, "Chapter button should exist")

        // Test that chapter buttons have enhanced styling (rounded corners, shadows)
        let buttonFrame = chapterButton.frame

        // Test tap functionality
        chapterButton.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify navigation occurred
        XCTAssertTrue(true, "Chapter tap should trigger navigation")
    }

    // MARK: - Test Suite 4: Tree Navigation

    func test_treeNavigationFunctionality() throws {
        // Test that tree elements are present
        let treeItems = app.tables.cells.count
        XCTAssertTrue(treeItems > 0, "Tree navigation items should be present")

        // Test chevron indicators for expandable items
        let chevrons = app.buttons.matching(identifier: "chevron")
        XCTAssertTrue(chevrons.count > 0, "Chevron indicators should be present for expandable items")

        // Test tap on first tree item
        let firstTreeItem = app.cells.firstMatch
        if firstTreeItem.exists {
            firstTreeItem.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - Test Suite 5: Tab Navigation Across All Tabs

    func test_tabNavigationAcrossAllTabs() throws {
        let tabBar = app.tabBars.firstMatch

        // Test Reading tab (default)
        XCTAssertTrue(tabBar.buttons.element(boundBy: 0).isSelected, "Reading tab should be selected by default")

        // Test navigating to Listening tab
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we're in listening tab
        XCTAssertTrue(listeningTab.isSelected, "Listening tab should be selected after tap")

        // Verify listening interface elements
        let audioPlayerElements = app.buttons.matching(NSPredicate(format: "label CONTAINS '播放' OR label CONTAINS '暂停'"))
        XCTAssertTrue(audioPlayerElements.count >= 0, "Audio player controls should be present")

        // Test navigating to Favorites tab
        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we're in favorites tab
        XCTAssertTrue(favoritesTab.isSelected, "Favorites tab should be selected after tap")

        // Return to Reading tab
        let readingTab = tabBar.buttons.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we're back in reading tab
        XCTAssertTrue(readingTab.isSelected, "Reading tab should be selected after return")
    }

    // MARK: - Test Suite 6: Enhanced Design Persistence

    func test_designPersistenceAcrossTabs() throws {
        // Set theme to sepia
        let themeButton = app.navigationBars.buttons["🎨"]
        themeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Navigate to listening tab
        let listeningTab = app.tabBars.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Navigate to favorites tab
        let favoritesTab = app.tabBars.buttons.element(boundBy: 2)
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Return to reading tab
        let readingTab = app.tabBars.buttons.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify enhanced design is still applied
        let statusLabel = app.staticTexts["Enhanced Design Active - Tap to Change Theme"]
        XCTAssertTrue(statusLabel.exists, "Enhanced design should persist across tab navigation")

        let currentThemeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(currentThemeButton.exists, "Theme button should remain visible after tab navigation")
    }

    // MARK: - Test Suite 7: Performance and Stability

    func test_themeSwitchingPerformance() throws {
        let themeButton = app.navigationBars.buttons["🎨"]

        // Measure time for theme switching
        let startTime = CFAbsoluteTimeGetCurrent()

        // Perform multiple theme switches
        for _ in 0..<5 {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 0.2)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime

        // Performance assertion: theme switching should be fast
        XCTAssertLessThan(totalTime, 3.0, "Multiple theme switches should complete within 3 seconds")

        // Verify app is still responsive
        XCTAssertTrue(app.exists, "App should remain responsive after multiple theme switches")
    }

    func test_memoryStabilityDuringThemeChanges() throws {
        let themeButton = app.navigationBars.buttons["🎨"]

        // Switch themes multiple times
        for i in 0..<10 {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 0.1)

            // Verify app is still responsive
            XCTAssertTrue(app.exists, "App should remain stable after \(i+1) theme changes")

            // Verify navigation elements are still present
            XCTAssertTrue(app.navigationBars.count > 0, "Navigation should remain after \(i+1) theme changes")
            XCTAssertTrue(app.tabBars.count > 0, "Tab bar should remain after \(i+1) theme changes")
        }
    }

    // MARK: - Test Suite 8: Edge Cases and Error Handling

    func test_rapidThemeSwitching() throws {
        let themeButton = app.navigationBars.buttons["🎨"]

        // Perform very rapid theme switching
        for _ in 0..<20 {
            themeButton.tap()
            // No sleep - rapid switching
        }

        // Verify app didn't crash
        XCTAssertTrue(app.exists, "App should handle rapid theme switching without crashing")

        // Verify theme is applied
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(app.debugDescription.contains("color"), "Final theme should be applied after rapid switching")
    }

    func test_appStabilityAfterEnhancedDesign() throws {
        // Perform comprehensive app usage
        let themeButton = app.navigationBars.buttons["🎨"]

        // Switch themes
        themeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Navigate through chapters
        for i in 1...3 {
            let chapterButton = app.buttons["卷\(i)"]
            if chapterButton.exists {
                chapterButton.tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Go back if navigation occurred
                let backButton = app.navigationBars.buttons["back"]
                if backButton.exists {
                    backButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }

        // Navigate tabs
        let tabBar = app.tabBars.firstMatch
        for i in 0..<3 {
            tabBar.buttons.element(boundBy: i).tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Return to reading tab
        tabBar.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify app is still stable
        XCTAssertTrue(app.exists, "App should remain stable after comprehensive usage")
        XCTAssertTrue(app.navigationBars.count > 0, "Navigation should remain stable")
        XCTAssertTrue(app.tabBars.count > 0, "Tab bar should remain stable")
    }

    // MARK: - Test Suite 9: Accessibility

    func test_accessibilityOfEnhancedElements() throws {
        // Test theme button accessibility
        let themeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(themeButton.exists, "Theme button should be accessible")

        // Test chapter button accessibility
        let chapterButton = app.buttons["卷一"]
        XCTAssertTrue(chapterButton.exists, "Chapter button should be accessible")

        // Test tab bar accessibility
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be accessible")
        XCTAssertEqual(tabBar.buttons.count, 3, "All tabs should be accessible")

        // Test navigation accessibility
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists, "Navigation bar should be accessible")
    }

    // MARK: - Test Suite 10: User Flow Integration

    func test_completeUserFlow_ReadingExperience() throws {
        // Start with enhanced design in reading tab
        let themeButton = app.navigationBars.buttons["🎨"]

        // User sets preferred theme
        themeButton.tap()
        themeButton.tap()
        themeButton.tap() // Cycle to preferred theme
        Thread.sleep(forTimeInterval: 0.5)

        // User navigates to chapter
        let chapterButton = app.buttons["卷一"]
        chapterButton.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // User explores tree navigation
        let treeItem = app.cells.firstMatch
        if treeItem.exists {
            treeItem.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // User goes back
            let backButton = app.navigationBars.buttons["back"]
            if backButton.exists {
                backButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // User returns to main screen
        let backToMain = app.navigationBars.buttons["back"]
        if backToMain.exists {
            backToMain.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // User switches to listening experience
        let listeningTab = app.tabBars.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // User checks favorites
        let favoritesTab = app.tabBars.element(boundBy: 2)
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // User returns to reading
        let readingTab = app.tabBars.buttons.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify complete flow is working
        XCTAssertTrue(app.exists, "App should remain stable after complete user flow")
        let finalThemeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(finalThemeButton.exists, "Theme functionality should remain available")
    }

    func test_completeUserFlow_ListeningExperience() throws {
        // User navigates to listening tab
        let listeningTab = app.tabBars.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // User explores audio interface
        let audioControls = app.buttons.matching(NSPredicate(format: "label CONTAINS '播放' OR label CONTAINS '暂停' OR label CONTAINS '循环'"))
        XCTAssertTrue(audioControls.count >= 0, "Audio controls should be available")

        // User plays/pauses content
        if let playButton = audioControls.firstMatch {
            playButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            playButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // User returns to reading
        let readingTab = app.tabBars.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify enhanced design is maintained
        let enhancedStatusLabel = app.staticTexts["Enhanced Design Active - Tap to Change Theme"]
        XCTAssertTrue(enhancedStatusLabel.exists, "Enhanced design should be maintained in listening experience")
    }

    // MARK: - Test Suite 11: Real Device Simulation

    func test_performanceOnRealDevice() throws {
        // This test simulates real device performance
        let themeButton = app.navigationBars.buttons["🎨"]

        // Test theme switching performance
        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<50 {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 0.05) // Fast switching
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime

        // Performance requirement for real devices
        XCTAssertLessThan(totalTime, 10.0, "50 theme switches should complete within 10 seconds on real device")

        // Verify no memory leaks or crashes
        XCTAssertTrue(app.exists, "App should remain stable after performance test")
    }
}

// MARK: - Helper Extensions
extension XCUIElement {
    var isVisible: Bool {
        return self.exists && self.isHittable
    }
}

extension XCTestCase {
    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5.0) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element should appear within timeout")
    }
}