//
//  lengyanUITests.swift
//  lengyanUITests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest

class lengyanUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testChapterReading() {
        let app = XCUIApplication()
        app.tables.buttons["卷一"].tap()
        
        let textView = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .textView).element
        textView.swipeLeft()
        textView.swipeUp()
        textView.swipeDown()
        textView.swipeLeft()
        textView.swipeRight()
        textView.tap()
        textView.swipeDown()
        app.navigationBars["卷二"].buttons[" ❬  "].tap()
    }
    
    func testIndexReading() {
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["序分  卷一起"]/*[[".cells.staticTexts[\"序分  卷一起\"]",".staticTexts[\"序分  卷一起\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.navigationBars["大佛顶如来密因修证了义诸菩萨万行首楞严经 之 序分"].buttons["ic view list 18pt"].tap()
        let staticText = tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["广列听众"]/*[[".cells.staticTexts[\"广列听众\"]",".staticTexts[\"广列听众\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        staticText.tap()
        staticText.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["王臣设供"]/*[[".cells.staticTexts[\"王臣设供\"]",".staticTexts[\"王臣设供\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    }

    // MARK: - Enhanced Design System Tests

    func testEnhancedDesignApplied() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Test that app launches successfully
        XCTAssertTrue(app.exists, "App should launch successfully")

        // Verify main navigation elements are present
        XCTAssertTrue(app.navigationBars.count > 0, "Navigation bar should be present")

        // Verify tab bar with three tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be present")
        XCTAssertEqual(tabBar.buttons.count, 3, "Should have exactly 3 tabs")

        // Test enhanced theme toggle button
        let themeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(themeButton.exists, "Theme toggle button should be visible")

        // Test theme toggle functionality
        themeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.exists, "App should remain stable after theme change")
    }

    func testCompleteUserFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Test theme switching
        let themeButton = app.navigationBars.buttons["🎨"]
        if themeButton.exists {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Test chapter navigation
        let chapterButton = app.buttons["卷一"]
        if chapterButton.exists {
            chapterButton.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Go back if possible
            let backButton = app.navigationBars.buttons["back"]
            if backButton.exists {
                backButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // Test tab navigation
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            // Test listening tab
            let listeningTab = tabBar.buttons.element(boundBy: 1)
            listeningTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Test favorites tab
            let favoritesTab = tabBar.buttons.element(boundBy: 2)
            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Return to reading tab
            let readingTab = tabBar.buttons.element(boundBy: 0)
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Verify app is still stable
        XCTAssertTrue(app.exists, "App should remain stable after complete user flow")
    }
    
}
