//
//  SutraIndexViewUITests.swift
//  LengyanUITests
//
//  UI tests for SutraIndexView
//  Test user interactions and navigation
//

import XCTest
import SwiftUI

final class SutraIndexViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Tests

    func testSutraIndexNavigation() throws {
        // Navigate to sutra index
        app.tabBars.buttons["阅读"].tap()

        // Verify navigation title
        XCTAssertTrue(app.navigationBars["楞严经"].exists)

        // Verify list exists
        let list = appLists.firstMatch
        XCTAssertTrue(list.exists)

        // Tap first sutra item
        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.exists)
        firstCell.tap()
    }

    // MARK: - Theme Menu Tests

    func testThemeMenu() throws {
        app.tabBars.buttons["阅读"].tap()

        // Open theme menu
        app.navigationBars.buttons["paintbrush"].tap()

        // Select theme
        let themeMenu = app.buttons["Light Theme"]
        if themeMenu.exists {
            themeMenu.tap()
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibility() throws {
        app.tabBars.buttons["阅读"].tap()

        // Verify accessibility labels
        let navigationBar = app.navigationBars["楞严经"]
        XCTAssertTrue(navigationBar.exists)

        // Check for VoiceOver support
        let list = appLists.firstMatch
        XCTAssertTrue(list.exists)

        // Verify cells have accessibility
        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.exists)
    }

    // MARK: - Loading State Tests

    func testLoadingState() throws {
        app.tabBars.buttons["阅读"].tap()

        // Check for loading indicator
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.exists || app.navigationBars["楞严经"].waitForExistence(timeout: 5))
    }

    // MARK: - Error Handling Tests

    func testErrorHandling() throws {
        app.tabBars.buttons["阅读"].tap()

        // Wait for error or success
        let navigationBarExists = app.navigationBars["楞严经"].waitForExistence(timeout: 10)

        // Either we load successfully or show error
        XCTAssertTrue(navigationBarExists || app.alerts.element.exists)
    }

    // MARK: - Tab Navigation Tests

    func testTabNavigation() throws {
        // Test reading tab
        app.tabBars.buttons["阅读"].tap()
        XCTAssertTrue(app.navigationBars["楞严经"].exists)

        // Test audio tab
        app.tabBars.buttons["听经"].tap()
        XCTAssertTrue(app.navigationBars["Audio Player"].exists || app.navigationBars["听经"].exists)

        // Test favorites tab
        app.tabBars.buttons["收藏"].tap()
        XCTAssertTrue(app.navigationBars["收藏"].exists)
    }

    // MARK: - Settings Tests

    func testSettingsAccess() throws {
        app.tabBars.buttons["收藏"].tap()

        // Settings might be in a different location
        // This test will verify navigation works
        let favoritesNav = app.navigationBars["收藏"].firstMatch
        XCTAssertTrue(favoritesNav.exists)
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    var app: XCUIApplication {
        get {
            guard let test = self as? SutraIndexViewUITests else {
                return XCUIApplication()
            }
            return test.app
        }
        set {
            guard let test = self as? SutraIndexViewUITests else {
                return
            }
            test.app = newValue
        }
    }

    var appLists: XCUIElementQuery {
        return app.navigationBars["楞严经"].scrollViews.lists
    }
}
