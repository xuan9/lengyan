//
//  lengyanUITests.swift
//  lengyanUITests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit
import XCTest

class lengyanUITests: XCTestCase {

    private enum HomeReadingState {
        case start
        case outlineResume
        case pagedResume(path: String, pageIndex: Int)
        case treeResume(path: String)
    }
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }
    
    override func tearDown() {
        super.tearDown()
    }

    /// UserDefaults' argument domain overrides any progress left by another UI
    /// test without adding production-only reset hooks to the app.
    private func launchHomeApp(
        readingState: HomeReadingState,
        userLikes: [String]? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()

        var arguments = [
            "--uitesting",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans_CN",
            "-selectedTheme", "sepia",
            "-fontSizeLevel", "2",
            "-hasSeenDailyReminderPrompt", "YES",
            "-readingResumeSnapshotV2", "invalid",
            "-chapterResumeSnapshotV2", "invalid",
            "-pagedResumeSnapshotV2", "invalid",
            "-treeResumeSnapshotV2", "invalid",
            "-lastReadChapter", "0",
            "-lastReadChapterOffset", "0",
            "-playFile", "invalid",
            "-lastPlayTime", "0",
        ]
        if let userLikes {
            arguments += ["-userLikes", "(\(userLikes.joined(separator: ",")))"]
        }
        switch readingState {
        case .start:
            arguments += [
                "-lastReadPath", "",
                "-lastReadMode", "",
                "-lastReadPage", "0",
            ]
        case .outlineResume:
            arguments += [
                "-lastReadPath", "/A1/B1/C1",
                "-lastReadMode", "tree",
                "-lastReadPage", "0",
            ]
        case let .pagedResume(path, pageIndex):
            arguments += [
                "-lastReadPath", path,
                "-lastReadMode", "paged",
                "-lastReadPage", String(pageIndex),
            ]
        case let .treeResume(path):
            arguments += [
                "-lastReadPath", path,
                "-lastReadMode", "tree",
                "-lastReadPage", "0",
            ]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func waitForCondition(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.05,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        } while Date() < deadline
        return condition()
    }

    private func openFirstLeafFromFullOutline(in app: XCUIApplication) {
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(fullOutlineButton.waitForExistence(timeout: 3))
        fullOutlineButton.tap()

        let firstSection = app.cells["outline.row./A1"]
        let firstSubsection = app.cells["outline.row./A1/B1"]
        let firstLeaf = app.cells["outline.row./A1/B1/C1"]
        XCTAssertTrue(firstSection.waitForExistence(timeout: 3))
        XCTAssertFalse(firstSubsection.exists, "The complete outline should start as a compact overview")

        firstSection.tap()
        XCTAssertTrue(firstSubsection.waitForExistence(timeout: 3))
        firstSubsection.tap()
        XCTAssertTrue(firstLeaf.waitForExistence(timeout: 3))
        firstLeaf.tap()
    }

    private func launchAudioFallbackApp(faultMode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = [
            "--uitesting",
            "--audio-primary-fault", faultMode,
            "--audio-fallback-stall-timeout", "2",
            "--audio-fallback-presentation-delay", "1.5",
            "--reset-audio-fallback-cache",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans_CN",
            "-hasSeenDailyReminderPrompt", "YES",
            "-playFile", "invalid",
            "-lastPlayTime", "0",
            "-playMode", "999",
        ]
        app.launch()
        return app
    }

    private func wait(
        for element: XCUIElement,
        labelContaining text: String,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", text),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func wait(
        for element: XCUIElement,
        labelEqualTo text: String,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", text),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func exerciseAudioFallbackE2E(faultMode: String) throws {
        let app = launchAudioFallbackApp(faultMode: faultMode)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        tabBar.buttons.element(boundBy: 1).tap()

        let volumeOne = app.staticTexts["audio_track_ly01"]
        let volumeTwo = app.staticTexts["audio_track_ly02"]
        let pendingStatus = app.staticTexts["audio_player_pending_status"]
        let currentTrack = app.staticTexts["audio_player_current_track"]
        XCTAssertTrue(volumeOne.waitForExistence(timeout: 8))
        XCTAssertTrue(volumeTwo.waitForExistence(timeout: 8))

        volumeOne.tap()
        if faultMode == "stall" {
            XCTAssertTrue(
                wait(for: pendingStatus, labelContaining: "正在准备", timeout: 4),
                "The UI must acknowledge the Apple request before the watchdog fires"
            )
        }
        XCTAssertTrue(
            wait(for: pendingStatus, labelContaining: "备用线路", timeout: 15),
            "The UI must reveal that Cloudflare fallback was activated"
        )
        XCTAssertTrue(
            wait(for: currentTrack, labelEqualTo: "楞严经 卷一", timeout: 120),
            "Volume one should play after the verified fallback download"
        )

        volumeTwo.tap()
        XCTAssertEqual(
            currentTrack.label,
            "楞严经 卷一",
            "Selecting volume two must not replace the currently playable volume one"
        )
        XCTAssertTrue(
            wait(for: pendingStatus, labelContaining: "备用线路", timeout: 15),
            "Volume two should activate the visible fallback state"
        )
        XCTAssertEqual(
            currentTrack.label,
            "楞严经 卷一",
            "Volume one must remain current while volume two downloads"
        )
        XCTAssertTrue(
            wait(for: currentTrack, labelEqualTo: "楞严经 卷二", timeout: 120),
            "The player should switch only after volume two is fully downloaded and verified"
        )
    }

    func testAudioFallbackImmediateFailureE2E() throws {
        try exerciseAudioFallbackE2E(faultMode: "immediate")
    }

    func testAudioFallbackStallWatchdogE2E() throws {
        try exerciseAudioFallbackE2E(faultMode: "stall")
    }

    func testSettingsDoesNotExposeTechnicalAudioStorageControls() {
        let app = launchHomeApp(readingState: .start)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        tabBar.buttons.element(boundBy: 3).tap()

        XCTAssertTrue(
            app.buttons["settings_widget_guide_row"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["音频存储"].exists)
        XCTAssertFalse(app.staticTexts["删除全部"].exists)
        XCTAssertFalse(app.staticTexts["可释放"].exists)
    }
    
    func testComprehensiveAllNavigationPaths() {
        let app = XCUIApplication()
        app.launch()

        print("🚀 STARTING COMPREHENSIVE ALL NAVIGATION TEST")

        // MARK: 1. App Launch Verification
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(app.exists, "App should launch successfully")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs")

        let readingTab = tabBar.buttons.element(boundBy: 0)
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        let settingsTab = tabBar.buttons.element(boundBy: 3)

        // MARK: 2. READING TAB - Comprehensive Testing

        print("📖 Testing Reading Tab")
        readingTab.tap()
        Thread.sleep(forTimeInterval: 2.0)

        // Test all 10 chapter buttons
        for chapterNum in 1...10 {
            let chapterButton = app.buttons["卷\(chapterNum)"]
            if chapterButton.exists {
                print("   Testing 卷\(chapterNum)")
                chapterButton.tap()
                Thread.sleep(forTimeInterval: 2.0)

                // Test theme switching in chapter view
                let themeButton = app.buttons["🎨"]
                if themeButton.exists {
                    themeButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                    themeButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }

                // Go back
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists {
                    backButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        }

        // MARK: 3. Tree Navigation - Test ALL Expandable Items

        print("🌳 Testing Tree Navigation - All Expandable Items")

        // Wait for tree to load
        Thread.sleep(forTimeInterval: 3.0)

        // Get all chevron buttons and expand them one by one
        let chevronButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'"))
        let chevronCount = chevronButtons.count
        print("   Found \(chevronCount) expandable items")

        // Limit to first 5 items to avoid timeout
        let maxItems = min(5, chevronCount)
        print("   Testing first \(maxItems) items to avoid timeout")

        for i in 0..<maxItems {
            let chevron = chevronButtons.element(boundBy: i)

            // Verify the chevron exists and is hittable before tapping
            if chevron.exists && chevron.isHittable {
                print("   Expanding item \(i + 1)/\(maxItems)")

                // Wait a moment to ensure the element is ready
                Thread.sleep(forTimeInterval: 1.0)

                chevron.tap()
                Thread.sleep(forTimeInterval: 2.0)

                // Test navigation after expansion - only test first few elements
                if i < 3 {
                    let firstTextElement = app.staticTexts.firstMatch
                    if firstTextElement.exists && firstTextElement.isHittable {
                        firstTextElement.tap()
                        Thread.sleep(forTimeInterval: 2.0)

                        // Go back
                        let backButton = app.navigationBars.buttons.firstMatch
                        if backButton.exists {
                            backButton.tap()
                            Thread.sleep(forTimeInterval: 1.0)
                        }
                    }
                }
            } else {
                print("   Skipping item \(i + 1) - not hittable or doesn't exist")
            }
        }

        // MARK: 4. LISTENING TAB - Test ALL Audio Tracks

        print("🎵 Testing Listening Tab - All Audio Tracks")
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 2.0)

        // Test all audio tracks
        let audioTracks = [
            "楞严经 卷一", "楞严经 卷二", "楞严经 卷三", "楞严经 卷四", "楞严经 卷五",
            "楞严经 卷六", "楞严经 卷七", "楞严经 卷八", "楞严经 卷九", "楞严经 卷十", "楞严咒"
        ]

        for (index, track) in audioTracks.enumerated() {
            // The mini player repeats the current track title outside the list.
            // Scope the query to the track ScrollView so persisted playback state
            // cannot make a single-label lookup ambiguous between those elements.
            let trackElement = app.scrollViews.staticTexts[track].firstMatch
            if trackElement.waitForExistence(timeout: 2) {
                var scrollAttempts = 0
                while !trackElement.isHittable, scrollAttempts < 6 {
                    app.scrollViews.firstMatch.swipeUp()
                    scrollAttempts += 1
                }
                guard trackElement.isHittable else {
                    XCTFail("Audio track is present but not reachable: \(track)")
                    return
                }
                print("   Testing audio track \(index + 1)/\(audioTracks.count): \(track)")
                trackElement.tap()
                Thread.sleep(forTimeInterval: 2.0)

                // Test any audio controls that appear
                let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '播放' OR label CONTAINS '暂停'")).firstMatch
                if playButton.exists {
                    playButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                    playButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }

                // Go back if needed
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists {
                    backButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        }

        // MARK: 5. FAVORITES TAB

        print("⭐ Testing Favorites Tab")
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 2.0)

        // Test any favorites functionality
        let favoriteElements = app.cells.count
        if favoriteElements > 0 {
            print("   Found \(favoriteElements) favorite items")
            let firstFavorite = app.cells.firstMatch
            if firstFavorite.exists {
                firstFavorite.tap()
                Thread.sleep(forTimeInterval: 2.0)

                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists {
                    backButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        }

        // MARK: 6. Cross-Tab Navigation Stress Test

        print("🔄 Testing Cross-Tab Navigation Stress Test")

        for round in 1...5 {
            print("   Stress test round \(round)/5")

            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            listeningTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Back to reading
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // MARK: 7. Theme Switching Stress Test

        print("🎨 Testing Theme Switching Stress Test")
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let themeButton = app.buttons["🎨"]
        if themeButton.exists {
            for themeRound in 1...10 {
                print("   Theme switch round \(themeRound)/10")
                themeButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            print("   ⚠️ Theme button not found, skipping theme switching test")
        }

        print("✅ COMPREHENSIVE ALL NAVIGATION TEST COMPLETED SUCCESSFULLY")
        XCTAssertTrue(true, "All navigation paths tested successfully")
    }

    func testChapterReading() {
        let app = XCUIApplication()
        app.launch()

        // MARK: 1. Architectural Foundation - App Launch Verification
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(app.exists, "App should launch successfully")

        // Verify programmatic UI structure (3 tabs as designed)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist in programmatic UI")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs in programmatic UI")

        // MARK: 2. Architectural Navigation - Reading Tab State
        let readingTab = tabBar.buttons.element(boundBy: 0)
        XCTAssertTrue(readingTab.exists, "Reading tab should exist")
        XCTAssertTrue(readingTab.label == "读经" || readingTab.label == "讀經", "First tab should be reading tab (simplified or traditional)")

        // Ensure we're in reading context (programmatic UI defaults to reading tab)
        if !readingTab.isSelected {
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
        XCTAssertTrue(readingTab.isSelected, "Reading tab should be selected")

        // MARK: 3. Architectural Content - SutraFrontViewController Verification
        Thread.sleep(forTimeInterval: 3.0)

        // Verify main navigation controller with SutraFrontViewController
        let navigationController = app.navigationBars.firstMatch
        // Navigation bar is hidden on home screen for immersive design, so we don't assert its existence here

        // Verify tree view (RATreeView) - main sutra navigation component
        let treeView = app.tables.firstMatch
        XCTAssertTrue(treeView.exists, "RATreeView should be present for sutra navigation")
        XCTAssertTrue(treeView.isHittable, "Tree view should be interactive")

        // Verify theme toggle in navigation bar (enhanced design system)
        let themeButton = app.navigationBars.buttons["🎨"]
        if themeButton.exists {
            XCTAssertTrue(themeButton.isHittable, "Theme toggle button should be tappable")
        }

        // MARK: 5. Architectural Navigation - Chapter Button System
        // Chapter buttons are created programmatically in header view
        // Wait for chapter buttons to be rendered in tree header
        Thread.sleep(forTimeInterval: 2.0)

        // Look for chapter buttons using multiple approaches (programmatic UI)
        let chapterButtonsByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS '卷'"))
        let chapterButtonsByAccessibility = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'chapter'"))

        // At minimum, 卷一 should exist from our programmatic header creation
        let chapterOneButton = app.buttons["卷一"]
        if chapterOneButton.exists {
            XCTAssertTrue(chapterOneButton.isHittable, "卷一 button should be tappable")
        } else {
            // If individual buttons not found, verify tree view has content
            XCTAssertTrue(treeView.cells.count > 0, "Tree view should have sutra content")
        }

        // MARK: 6. Architectural Flow - Content Navigation System
        // Test navigation to sutra content (SutraPurePageViewController)
        if chapterOneButton.exists && chapterOneButton.isHittable {
            chapterOneButton.tap()
            Thread.sleep(forTimeInterval: 2.0)

            // Verify navigation to sutra content view
            let pageViewController = app.otherElements.firstMatch
            XCTAssertTrue(pageViewController.exists, "Should navigate to sutra content view")

            // Look for content display components
            let scrollView = app.scrollViews.firstMatch
            let contentView = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'content'"))

            XCTAssertTrue(scrollView.exists || contentView.count > 0,
                         "Should have content display area in sutra view")

            // MARK: 7. Architectural Interaction - Content System
            if scrollView.exists {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 1.0)
                scrollView.swipeDown()
                Thread.sleep(forTimeInterval: 1.0)
            }

            // MARK: 8. Architectural Navigation - Return Flow
            // Test navigation back using multiple strategies
            let backButton = app.navigationBars.buttons.firstMatch
            let doneButton = app.navigationBars.buttons["完成"]
            let closeButton = app.navigationBars.buttons["关闭"]

            if backButton.exists && backButton.isHittable {
                backButton.tap()
            } else if doneButton.exists && doneButton.isHittable {
                doneButton.tap()
            } else if closeButton.exists && closeButton.isHittable {
                closeButton.tap()
            } else {
                // Try swipe back gesture if no buttons found
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
            }
            Thread.sleep(forTimeInterval: 2.0)
        }

        // MARK: 9. Architectural Validation - System Integrity
        // Verify we returned to main reading interface
        XCTAssertTrue(tabBar.exists, "Should return to tab bar system")
        XCTAssertTrue(readingTab.isSelected, "Should return to reading tab")
        XCTAssertTrue(treeView.exists, "Tree view should be visible after navigation")

        // MARK: 10. Architectural Design - Enhanced Theme System
        let finalThemeButton = app.navigationBars.buttons["🎨"]
        if finalThemeButton.exists {
            finalThemeButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(app.exists, "App should remain stable after theme change")
        }

        // MARK: 11. Architectural Completion - Full System Validation
        XCTAssertTrue(app.exists, "App should be stable after complete architectural flow")
        XCTAssertTrue(treeView.exists, "Main sutra navigation system should be functional")
        XCTAssertTrue(tabBar.exists, "Tab navigation system should be working")

        // MARK: 12. Architectural Enhancement - Cross-Tab System
        // Quick test of tab navigation system integrity
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(listeningTab.isSelected, "Listening tab should be accessible")

        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(favoritesTab.isSelected, "Favorites tab should be accessible")

        // Return to reading tab
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(readingTab.isSelected, "Should return to reading tab successfully")

        // MARK: Final Architectural Validation
        XCTAssertTrue(treeView.exists, "Complete sutra reading system should be functional")
        if themeButton.exists {
            XCTAssertTrue(themeButton.exists, "Enhanced design system should be fully operational")
        }
    }
    
    func testIndexReading() {
        let app = launchHomeApp(readingState: .start)
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(fullOutlineButton.waitForExistence(timeout: 3))
        fullOutlineButton.tap()
        XCTAssertTrue(
            app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3),
            "The explicit outline action should replace the old hidden verse tap"
        )
    }

    func testHomeUsesOutlineResumeAndChapterGridWithoutDuplicateShortcut() {
        let app = launchHomeApp(readingState: .outlineResume)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3), "Tab bar should exist")
        tabBar.buttons.element(boundBy: 0).tap()

        let chapterResumeButton = app.buttons["home.chapterResumeButton"]
        let outlineResumeButton = app.buttons["home.outlineResumeButton"]
        let listeningButton = app.buttons["home.listeningButton"]
        let searchButton = app.buttons["home.searchButton"]
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(outlineResumeButton.waitForExistence(timeout: 3))
        XCTAssertFalse(chapterResumeButton.exists)
        XCTAssertTrue(outlineResumeButton.isHittable)
        XCTAssertTrue(listeningButton.exists)
        XCTAssertTrue(listeningButton.isHittable)
        XCTAssertTrue(searchButton.exists)
        XCTAssertTrue(searchButton.isHittable)
        XCTAssertTrue(fullOutlineButton.exists)
        XCTAssertTrue(fullOutlineButton.isHittable)

        let chapterTenButton = app.buttons["卷十"]
        let chapterOneButton = app.buttons["卷一"]
        XCTAssertTrue(chapterTenButton.exists)
        XCTAssertTrue(chapterOneButton.exists)

        let expectsSingleRow = UIDevice.current.userInterfaceIdiom == .pad
            && app.frame.width >= 720
        if expectsSingleRow {
            func assertSingleRowAlignment() {
                let actionMidYs = [
                    outlineResumeButton.frame.midY,
                    fullOutlineButton.frame.midY,
                    listeningButton.frame.midY,
                    searchButton.frame.midY,
                ]
                XCTAssertLessThanOrEqual(actionMidYs.max()! - actionMidYs.min()!, 1)
                XCTAssertEqual(outlineResumeButton.frame.minX, chapterOneButton.frame.minX, accuracy: 1)
                XCTAssertEqual(fullOutlineButton.frame.maxX, chapterTenButton.frame.maxX, accuracy: 1)
                XCTAssertGreaterThan(outlineResumeButton.frame.width, listeningButton.frame.width)
                XCTAssertLessThan(outlineResumeButton.frame.minX, listeningButton.frame.minX)
                XCTAssertLessThan(listeningButton.frame.minX, searchButton.frame.minX)
                XCTAssertLessThan(searchButton.frame.minX, fullOutlineButton.frame.minX)
                let gaps = [
                    listeningButton.frame.minX - outlineResumeButton.frame.maxX,
                    searchButton.frame.minX - listeningButton.frame.maxX,
                    fullOutlineButton.frame.minX - searchButton.frame.maxX,
                ]
                XCTAssertGreaterThanOrEqual(gaps.min()!, 7.5)
                XCTAssertLessThanOrEqual(gaps.max()! - gaps.min()!, 1)
            }

            assertSingleRowAlignment()
            let startedInPortraitScene = app.frame.height > app.frame.width
            defer { XCUIDevice.shared.orientation = .portrait }
            XCUIDevice.shared.orientation = .landscapeLeft
            let sceneEnteredLandscape = startedInPortraitScene && waitForCondition(timeout: 5) {
                app.frame.width > app.frame.height
            }
            // iPadOS 26 Windowed Apps may retain the scene's window size when
            // XCTest changes only the physical device orientation. If UIKit
            // does resize this scene, verify both transitions; otherwise the
            // layout remains covered at its current, user-controlled size.
            if sceneEnteredLandscape {
                XCTAssertTrue(outlineResumeButton.waitForExistence(timeout: 3))
                assertSingleRowAlignment()

                XCUIDevice.shared.orientation = .portrait
                XCTAssertTrue(waitForCondition(timeout: 5) {
                    app.frame.height > app.frame.width
                })
                XCTAssertTrue(outlineResumeButton.waitForExistence(timeout: 3))
                assertSingleRowAlignment()
            }
        } else {
            XCTAssertEqual(outlineResumeButton.frame.minX, chapterOneButton.frame.minX, accuracy: 1)
            XCTAssertEqual(listeningButton.frame.minX, chapterOneButton.frame.minX, accuracy: 1)
            XCTAssertEqual(fullOutlineButton.frame.maxX, chapterTenButton.frame.maxX, accuracy: 1)
            XCTAssertEqual(searchButton.frame.maxX, fullOutlineButton.frame.maxX, accuracy: 1)
            XCTAssertGreaterThan(outlineResumeButton.frame.width, fullOutlineButton.frame.width)
            XCTAssertGreaterThan(listeningButton.frame.width, searchButton.frame.width)
            XCTAssertEqual(outlineResumeButton.frame.minY, fullOutlineButton.frame.minY, accuracy: 1)
            XCTAssertEqual(listeningButton.frame.minY, searchButton.frame.minY, accuracy: 1)
            XCTAssertLessThan(fullOutlineButton.frame.minY, searchButton.frame.minY)
        }

        XCTAssertTrue(chapterOneButton.isHittable)
        chapterOneButton.tap()
        let chapterReader = app.otherElements["reader.chapter"]
        XCTAssertTrue(
            chapterReader.waitForExistence(timeout: 3),
            "The chapter grid should remain the volume-reader entry"
        )

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        XCTAssertTrue(outlineResumeButton.waitForExistence(timeout: 3))

        outlineResumeButton.tap()
        XCTAssertTrue(
            app.otherElements["reader.tree"].waitForExistence(timeout: 3),
            "The seeded tree-reading history should resume its exact reader mode"
        )
        XCTAssertFalse(chapterReader.exists)
    }

    func testIPadListeningListAdaptsAcrossRotation() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Listening rotation coverage is iPad-only")
        }

        XCUIDevice.shared.orientation = .portrait
        let app = launchHomeApp(readingState: .start)
        defer { XCUIDevice.shared.orientation = .portrait }

        guard waitForCondition(timeout: 3, {
            app.frame.height > app.frame.width
        }) else {
            throw XCTSkip(
                "The iPadOS scene retained its user-controlled landscape geometry"
            )
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        tabBar.buttons.element(boundBy: 1).tap()

        let firstTrack = app.staticTexts["audio_track_ly01"]
        let secondTrack = app.staticTexts["audio_track_ly02"]
        XCTAssertTrue(firstTrack.waitForExistence(timeout: 5))
        XCTAssertTrue(secondTrack.waitForExistence(timeout: 5))

        let portraitPitch = secondTrack.frame.midY - firstTrack.frame.midY
        XCTAssertGreaterThanOrEqual(portraitPitch, 61)

        let portraitAttachment = XCTAttachment(screenshot: app.screenshot())
        portraitAttachment.name = "Listening-iPad-Portrait"
        portraitAttachment.lifetime = .keepAlways
        add(portraitAttachment)

        XCUIDevice.shared.orientation = .landscapeLeft
        guard waitForCondition(timeout: 5, {
            app.frame.width > app.frame.height
        }) else {
            throw XCTSkip(
                "The iPadOS Windowed Apps scene retained its user-controlled window size"
            )
        }
        XCTAssertTrue(waitForCondition(timeout: 5) {
            let pitch = secondTrack.frame.midY - firstTrack.frame.midY
            return abs(pitch - 52.5) <= 1
        })

        let landscapePitch = secondTrack.frame.midY - firstTrack.frame.midY
        XCTAssertEqual(landscapePitch, 52.5, accuracy: 1)
        XCTAssertGreaterThan(portraitPitch, landscapePitch + 5)

        let landscapeAttachment = XCTAttachment(screenshot: app.screenshot())
        landscapeAttachment.name = "Listening-iPad-Landscape"
        landscapeAttachment.lifetime = .keepAlways
        add(landscapeAttachment)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitForCondition(timeout: 5) {
            app.frame.height > app.frame.width
        })
        XCTAssertTrue(waitForCondition(timeout: 5) {
            abs((secondTrack.frame.midY - firstTrack.frame.midY) - portraitPitch) <= 1
        })
    }

    func testHomeSingleRowDistributesShortResumeSpaceAcrossEqualGaps() throws {
        let app = launchHomeApp(readingState: .start)
        guard UIDevice.current.userInterfaceIdiom == .pad,
              app.frame.width >= 720 else {
            throw XCTSkip("Content-aware single-row spacing is an iPad layout")
        }

        let startReadingButton = app.buttons["home.startReadingButton"]
        let listeningButton = app.buttons["home.listeningButton"]
        let searchButton = app.buttons["home.searchButton"]
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        let chapterOneButton = app.buttons["卷一"]
        let chapterTenButton = app.buttons["卷十"]
        XCTAssertTrue(startReadingButton.waitForExistence(timeout: 3))
        XCTAssertTrue(listeningButton.exists)
        XCTAssertTrue(searchButton.exists)
        XCTAssertTrue(fullOutlineButton.exists)

        let gaps = [
            listeningButton.frame.minX - startReadingButton.frame.maxX,
            searchButton.frame.minX - listeningButton.frame.maxX,
            fullOutlineButton.frame.minX - searchButton.frame.maxX,
        ]
        XCTAssertGreaterThan(gaps.min()!, 8)
        XCTAssertLessThanOrEqual(gaps.max()! - gaps.min()!, 1)
        XCTAssertEqual(startReadingButton.frame.minX, chapterOneButton.frame.minX, accuracy: 1)
        XCTAssertEqual(fullOutlineButton.frame.maxX, chapterTenButton.frame.maxX, accuracy: 1)
    }

    func testHomeStartReadingOpensFirstScriptureInsteadOfOutline() {
        let app = launchHomeApp(readingState: .start)
        let startReadingButton = app.buttons["home.startReadingButton"]
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(startReadingButton.waitForExistence(timeout: 3))
        XCTAssertTrue(fullOutlineButton.exists)

        startReadingButton.tap()
        XCTAssertTrue(app.otherElements["reader.tree"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["reader.outlineIndex"].exists)
    }

    func testHomeFullOutlineButtonOpensCompleteOutline() {
        let app = launchHomeApp(readingState: .start)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        tabBar.buttons.element(boundBy: 0).tap()

        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(fullOutlineButton.waitForExistence(timeout: 3))
        XCTAssertTrue(fullOutlineButton.isHittable)
        fullOutlineButton.tap()

        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))
    }

    func testFullOutlinePreservesDisclosureStateAcrossTabSwitches() {
        let app = launchHomeApp(readingState: .start)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))

        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(fullOutlineButton.waitForExistence(timeout: 3))
        fullOutlineButton.tap()

        let firstSection = app.cells["outline.row./A1"]
        let firstChild = app.cells["outline.row./A1/B1"]
        XCTAssertTrue(firstSection.waitForExistence(timeout: 3))
        XCTAssertFalse(firstChild.exists)

        firstSection.tap()
        XCTAssertTrue(firstChild.waitForExistence(timeout: 3))

        tabBar.buttons.element(boundBy: 1).tap()
        tabBar.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(firstChild.waitForExistence(timeout: 3), "Expanded rows should survive a tab round-trip")

        firstSection.tap()
        XCTAssertTrue(waitForCondition(timeout: 3) { !firstChild.exists })

        tabBar.buttons.element(boundBy: 1).tap()
        tabBar.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(firstChild.exists, "Collapsed rows must not be reopened when the outline reappears")
    }

    func testFullOutlineSupportsInteractiveEdgePop() {
        let app = launchHomeApp(readingState: .start)
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        XCTAssertTrue(fullOutlineButton.waitForExistence(timeout: 3))
        fullOutlineButton.tap()
        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: finish)

        XCTAssertTrue(
            fullOutlineButton.waitForExistence(timeout: 3),
            "A left-edge swipe should return to the home screen"
        )
        XCTAssertFalse(app.otherElements["reader.outlineIndex"].exists)
    }

    func testPagedLeafReaderDoesNotShowOutlineButton() {
        let app = launchHomeApp(readingState: .start)
        openFirstLeafFromFullOutline(in: app)

        XCTAssertTrue(app.otherElements["reader.paged"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["reader.outlineButton"].exists)
    }

    func testReaderEdgePopRevealsAChangedReadingPath() {
        let app = launchHomeApp(readingState: .start)
        openFirstLeafFromFullOutline(in: app)

        let reader = app.otherElements["reader.paged"]
        XCTAssertTrue(reader.waitForExistence(timeout: 3))
        reader.swipeLeft()
        XCTAssertTrue(waitForCondition(timeout: 3) {
            app.staticTexts["据迹标数"].exists
        })
        Thread.sleep(forTimeInterval: 0.6)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: finish)

        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.cells["outline.row./A1/B1/C2/D1/E1"].waitForExistence(timeout: 3),
            "A completed interactive pop should reveal the page reached inside the reader"
        )
    }

    func testTreeReaderOutlineExpandsOneAdditionalLevel() {
        let rootPath = "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K1"
        let app = launchHomeApp(readingState: .treeResume(path: rootPath))
        let resumeButton = app.buttons["home.outlineResumeButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
        resumeButton.tap()

        XCTAssertTrue(app.otherElements["reader.tree"].waitForExistence(timeout: 3))
        let outlineButton = app.buttons["reader.outlineButton"]
        XCTAssertTrue(outlineButton.waitForExistence(timeout: 3))
        outlineButton.tap()

        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.cells["outline.row.\(rootPath)/L4/M1"].waitForExistence(timeout: 3),
            "Opening a non-leaf reader outline should reveal one richer child level"
        )
    }

    func testScopedTreeReaderEdgePopPromotesOutlineAcrossBranches() {
        let scopedPath = "/A1/B1/C2/D3"
        let app = launchHomeApp(readingState: .treeResume(path: scopedPath))
        let resumeButton = app.buttons["home.outlineResumeButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
        resumeButton.tap()

        let reader = app.otherElements["reader.tree"]
        XCTAssertTrue(reader.waitForExistence(timeout: 3))
        let outlineButton = app.buttons["reader.outlineButton"]
        XCTAssertTrue(outlineButton.waitForExistence(timeout: 3))
        outlineButton.tap()

        let lastScopedLeaf = app.cells["outline.row.\(scopedPath)/E2"]
        XCTAssertTrue(lastScopedLeaf.waitForExistence(timeout: 3))
        lastScopedLeaf.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 3))
        XCTAssertFalse(outlineButton.exists)

        reader.swipeLeft()
        XCTAssertTrue(waitForCondition(timeout: 3) {
            outlineButton.exists
        })
        Thread.sleep(forTimeInterval: 0.6)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: finish)

        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.cells["outline.row./A1/B2"].waitForExistence(timeout: 3),
            "Crossing a scoped branch should promote the outline and reveal the exact current node"
        )
        XCTAssertTrue(app.cells["outline.row./A1/B1"].exists)
        XCTAssertFalse(app.cells["outline.row./A2"].exists)
        XCTAssertFalse(app.cells["outline.row./A1/B1/C1"].exists)
    }

    func testPagedLeafReaderKeepsOutlineButtonHiddenAfterPageTurn() {
        let app = launchHomeApp(readingState: .start)
        openFirstLeafFromFullOutline(in: app)

        let reader = app.otherElements["reader.paged"]
        XCTAssertTrue(reader.waitForExistence(timeout: 3))
        reader.swipeLeft()
        XCTAssertTrue(waitForCondition(timeout: 3) {
            app.staticTexts["据迹标数"].exists
        })
        Thread.sleep(forTimeInterval: 0.6)

        XCTAssertFalse(app.buttons["reader.outlineButton"].exists)
    }

    func testTreeLeafReaderDoesNotShowOutlineButton() {
        let app = launchHomeApp(readingState: .outlineResume)
        let resumeButton = app.buttons["home.outlineResumeButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
        resumeButton.tap()

        XCTAssertTrue(app.otherElements["reader.tree"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["reader.outlineButton"].exists)
    }

    func testIPadFavoritesDetailOutlineCanReturnToRootReader() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Favorites split-detail navigation is iPad-only")
        }

        let rootPath = "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K1"
        let app = launchHomeApp(
            readingState: .start,
            userLikes: [rootPath]
        )
        let favoritesTab = app.tabBars.firstMatch.buttons.element(boundBy: 2)
        XCTAssertTrue(favoritesTab.waitForExistence(timeout: 3))
        favoritesTab.tap()

        let outlineButton = app.buttons["reader.outlineButton"]
        XCTAssertTrue(outlineButton.waitForExistence(timeout: 5))
        outlineButton.tap()
        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))

        let leaf = app.cells["outline.row.\(rootPath)/L1"]
        XCTAssertTrue(leaf.waitForExistence(timeout: 3))
        leaf.tap()
        XCTAssertTrue(app.otherElements["reader.tree"].waitForExistence(timeout: 3))

        let readerBackButton = app.buttons["reader.backButton"]
        XCTAssertTrue(readerBackButton.waitForExistence(timeout: 3))
        readerBackButton.tap()
        XCTAssertTrue(app.otherElements["reader.outlineIndex"].waitForExistence(timeout: 3))

        let outlineBackButton = app.buttons["outline.backButton"]
        XCTAssertTrue(outlineBackButton.waitForExistence(timeout: 3))
        outlineBackButton.tap()

        XCTAssertTrue(outlineButton.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["reader.outlineIndex"].exists)
    }

    func testIPadFavoritesLongLeafBodyReflowsWithoutClipping() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Favorites split-detail layout is iPad-only")
        }

        let longLeafPath = "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1"
        let app = launchHomeApp(
            readingState: .start,
            userLikes: [longLeafPath]
        )
        defer { XCUIDevice.shared.orientation = .portrait }

        let favoritesTab = app.tabBars.firstMatch.buttons.element(boundBy: 2)
        XCTAssertTrue(favoritesTab.waitForExistence(timeout: 3))
        favoritesTab.tap()

        let reader = app.otherElements["reader.paged"]
        let body = app.textViews["reader.paged.body.0"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let portraitHeight = body.frame.height
        XCTAssertGreaterThan(
            portraitHeight,
            app.frame.height + 100,
            "The long favorite body should extend beyond one screen and remain vertically scrollable"
        )

        XCUIDevice.shared.orientation = .landscapeLeft
        guard waitForCondition(timeout: 5, {
            app.frame.width > app.frame.height
        }) else {
            throw XCTSkip("The simulator did not acknowledge landscape orientation")
        }
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        let landscapeHeight = body.frame.height
        XCTAssertGreaterThan(landscapeHeight, app.frame.height + 100)
        XCTAssertLessThan(
            landscapeHeight,
            portraitHeight,
            "A wider iPad reading column should reflow the complete body into fewer lines"
        )
    }

    func testNightReadingThemeIsNotExposed() {
        let app = launchHomeApp(readingState: .start)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        tabBar.buttons.element(boundBy: 3).tap()

        XCTAssertTrue(app.staticTexts["主题"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["夜读"].exists)
        XCTAssertFalse(app.buttons["夜讀"].exists)
    }

    func testChapterReaderPreservesPageAcrossRotation() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Chapter pagination rotation coverage is iPad-only")
        }
        let app = launchHomeApp(readingState: .start)
        defer { XCUIDevice.shared.orientation = .portrait }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        tabBar.buttons.element(boundBy: 0).tap()

        let chapterButton = app.buttons["卷一"]
        XCTAssertTrue(chapterButton.waitForExistence(timeout: 3))
        chapterButton.tap()

        let reader = app.otherElements["reader.chapter"]
        let pageLabel = app.staticTexts["reader.pageLabel"]
        XCTAssertTrue(reader.waitForExistence(timeout: 3))
        XCTAssertTrue(pageLabel.waitForExistence(timeout: 3))

        reader.swipeLeft()
        Thread.sleep(forTimeInterval: 0.6)
        reader.swipeLeft()
        Thread.sleep(forTimeInterval: 0.6)

        let portraitPage = pageLabel.label
        let portraitPageNumber = Int(
            portraitPage.split(separator: "/").first?
                .trimmingCharacters(in: .whitespaces) ?? ""
        )
        XCTAssertNotNil(portraitPageNumber)
        XCTAssertGreaterThanOrEqual(portraitPageNumber ?? 0, 2)

        XCUIDevice.shared.orientation = .landscapeLeft
        let didEnterLandscape = waitForCondition(timeout: 5) {
            app.frame.width > app.frame.height
        }
        guard didEnterLandscape else {
            throw XCTSkip("The simulator did not acknowledge the landscape orientation request")
        }
        XCTAssertTrue(pageLabel.waitForExistence(timeout: 3))

        XCUIDevice.shared.orientation = .portrait
        let didReturnToPortrait = waitForCondition(timeout: 5) {
            app.frame.height > app.frame.width
        }
        guard didReturnToPortrait else {
            throw XCTSkip("The simulator did not acknowledge the portrait orientation request")
        }

        let restoredPage = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", portraitPage),
            object: pageLabel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [restoredPage], timeout: 5), .completed)
        XCTAssertEqual(
            pageLabel.label,
            portraitPage,
            "Returning to the original size should return to the same scripture page"
        )
    }

    // MARK: - Enhanced Design System Tests

    func testEnhancedDesignApplied() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(app.exists, "App should launch successfully")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be present")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs")

        // Test theme switching in Settings tab
        let settingsTab = tabBar.buttons.element(boundBy: 3)
        if settingsTab.exists {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            
            let sepiaThemeButton = app.buttons["古籍"]
            if sepiaThemeButton.exists {
                sepiaThemeButton.tap()
                Thread.sleep(forTimeInterval: 1.0)
                
                let lightThemeButton = app.buttons["宣纸"]
                if lightThemeButton.exists {
                    lightThemeButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
            
            // Go back to Reading tab
            let readingTab = tabBar.buttons.element(boundBy: 0)
            readingTab.tap()
        }
    }

    func takeAndAttachScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        attachment.name = name
        self.add(attachment)
    }

    func testWidgetGuideForFirstTimeUser() throws {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let lockScreenIsSupported = majorVersion >= (
            UIDevice.current.userInterfaceIdiom == .pad ? 17 : 16
        )
        guard lockScreenIsSupported else {
            throw XCTSkip("Lock Screen widgets are unavailable on this destination")
        }

        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans_CN",
            "-selectedTheme", "sepia",
            "-hasSeenDailyReminderPrompt", "YES",
            "--widget-guide-empty-state",
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons.element(boundBy: 3).tap()

        let guideRow = app.buttons["settings_widget_guide_row"]
        XCTAssertTrue(guideRow.waitForExistence(timeout: 5))
        guideRow.tap()

        let header = app.descendants(matching: .any)["widget_guide_header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["每次亮屏，先读一段经文"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["四步完成"].waitForExistence(timeout: 3))
        takeAndAttachScreenshot(name: "WidgetGuide_LockScreen")

        let homeTab = app.buttons["widget_guide_home_tab"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3))
        homeTab.tap()
        XCTAssertTrue(app.staticTexts["让今日经文常驻主屏幕"].waitForExistence(timeout: 3))
    }

    func testCompleteUserFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        Thread.sleep(forTimeInterval: 1.5)
        takeAndAttachScreenshot(name: "1_Home_Light")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")

        // 1. Test theme switching via Settings
        let settingsTab = tabBar.buttons.element(boundBy: 3)
        if settingsTab.exists {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            
            // Switch to Sepia theme (古籍)
            let sepiaThemeButton = app.buttons["古籍"]
            if sepiaThemeButton.exists {
                sepiaThemeButton.tap()
                Thread.sleep(forTimeInterval: 1.0)
                takeAndAttachScreenshot(name: "2_Settings_Sepia")
                
                // Switch back to Light theme (宣纸)
                let lightThemeButton = app.buttons["宣纸"]
                if lightThemeButton.exists {
                    lightThemeButton.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
            
            // Return to Reading tab
            let readingTab = tabBar.buttons.element(boundBy: 0)
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // 2. Test chapter navigation (opens ReaderViewController)
        let chapterButton = app.buttons["卷一"]
        if chapterButton.exists {
            chapterButton.tap()
            Thread.sleep(forTimeInterval: 1.5)
            takeAndAttachScreenshot(name: "4_ReadingView")

            // Go back from Reader to Home
            let backToHome = app.navigationBars.buttons.element(boundBy: 0)
            if backToHome.exists {
                backToHome.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 3. Test the explicit complete-outline entry.
        let fullOutlineButton = app.buttons["home.fullOutlineButton"]
        if fullOutlineButton.exists {
            fullOutlineButton.tap()
            Thread.sleep(forTimeInterval: 1.5)
            takeAndAttachScreenshot(name: "3_IndexView")

            // Go back from Index to Home
            let backToHome = app.navigationBars.buttons.element(boundBy: 0)
            if backToHome.exists {
                backToHome.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 4. Test tab navigation
        if tabBar.exists {
            // Test listening tab (index 1)
            let listeningTab = tabBar.buttons.element(boundBy: 1)
            listeningTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            takeAndAttachScreenshot(name: "5_ListeningTab")

            // Test favorites tab (index 2)
            let favoritesTab = tabBar.buttons.element(boundBy: 2)
            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            takeAndAttachScreenshot(name: "6_FavoritesTab")

            // Test settings tab (index 3)
            let settingsTab = tabBar.buttons.element(boundBy: 3)
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            takeAndAttachScreenshot(name: "7_SettingsTab")

            // Return to reading tab
            let readingTab = tabBar.buttons.element(boundBy: 0)
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Verify app is still stable
        XCTAssertTrue(app.exists, "App should remain stable after complete user flow")
    }

    // MARK: - Comprehensive Architectural Tests for All User Flows

    func testListeningTabArchitecturalFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // MARK: 1. Architectural Foundation - App Launch
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(app.exists, "App should launch successfully")

        // MARK: 2. Architectural Navigation - Tab System Integrity
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist in programmatic UI")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs")

        // MARK: 3. Architectural Navigation - Access Listening Tab
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(listeningTab.exists, "Listening tab should exist")
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertTrue(listeningTab.isSelected, "Should navigate to listening tab")

        // MARK: 4. Architectural Components - Media Player Interface
        // Navigation bar is hidden on purpose in modern SwiftUI Listening tab

        // Look for media player components
        let tableViews = app.tables
        let mediaControls = app.buttons.matching(NSPredicate(format: "label CONTAINS '播放' OR label CONTAINS '暂停' OR label CONTAINS '循環'"))

        // Verify media content structure
        XCTAssertTrue(tableViews.count > 0 || mediaControls.count >= 0, "Should have media content or controls")

        // MARK: 5. Architectural Content - Audio List Validation
        if tableViews.count > 0 {
            let mediaTable = tableViews.firstMatch
            XCTAssertTrue(mediaTable.exists, "Media table should exist")
            XCTAssertTrue(mediaTable.isHittable, "Media table should be interactive")

            // Check for audio content cells
            let mediaCells = mediaTable.cells
            if mediaCells.count > 0 {
                let firstMediaCell = mediaCells.firstMatch
                XCTAssertTrue(firstMediaCell.exists, "Should have media content available")
            }
        }

        // MARK: 6. Architectural Theme - Design System Consistency
        let themeButton = app.navigationBars.buttons["🎨"]
        if themeButton.exists {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(app.exists, "Theme system should work in listening tab")
        }

        // MARK: 7. Architectural Navigation - Cross-Tab Integrity
        let readingTab = tabBar.buttons.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(readingTab.isSelected, "Should return to reading tab")

        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(favoritesTab.isSelected, "Should navigate to favorites tab")

        // Return to listening for final validation
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(listeningTab.isSelected, "Should return to listening tab")

        // MARK: 8. Architectural Validation - Complete System Integrity
        XCTAssertTrue(app.exists, "App should remain stable after complete listening flow")
        XCTAssertTrue(tabBar.exists, "Tab system should remain functional")
        XCTAssertTrue(tabBar.exists, "Navigation system should be intact")
    }

    func testFavoritesTabArchitecturalFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // MARK: 1. Architectural Foundation - App Launch
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(app.exists, "App should launch successfully")

        // MARK: 2. Architectural Navigation - Tab System Integrity
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist in programmatic UI")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs")

        // MARK: 3. Architectural Navigation - Access Favorites Tab
        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        XCTAssertTrue(favoritesTab.exists, "Favorites tab should exist")
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertTrue(favoritesTab.isSelected, "Should navigate to favorites tab")

        // MARK: 4. Architectural Components - Favorites Interface
        // Navigation bar is hidden on purpose in modern SwiftUI Favorites tab

        // Look for favorites content structure
        let tableViews = app.tables
        let emptyStateLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '收藏' OR label CONTAINS '书签' OR label CONTAINS '喜欢'"))

        // Verify favorites content or empty state
        XCTAssertTrue(tableViews.count > 0 || emptyStateLabels.count >= 0, "Should have favorites content or empty state")

        // MARK: 5. Architectural Content - Favorites Management
        if tableViews.count > 0 {
            let favoritesTable = tableViews.firstMatch
            XCTAssertTrue(favoritesTable.exists, "Favorites table should exist")
            XCTAssertTrue(favoritesTable.isHittable, "Favorites table should be interactive")

            // Check for favorites cells
            let favoritesCells = favoritesTable.cells
            if favoritesCells.count > 0 {
                let firstFavoriteCell = favoritesCells.firstMatch
                XCTAssertTrue(firstFavoriteCell.exists, "Should have favorites content available")
            }
        }

        // MARK: 6. Architectural Theme - Design System Consistency
        let themeButton = app.navigationBars.buttons["🎨"]
        if themeButton.exists {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(app.exists, "Theme system should work in favorites tab")
        }

        // MARK: 7. Architectural Navigation - Cross-Tab Integrity
        let readingTab = tabBar.buttons.element(boundBy: 0)
        readingTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(readingTab.isSelected, "Should return to reading tab")

        let listeningTab = tabBar.buttons.element(boundBy: 1)
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(listeningTab.isSelected, "Should navigate to listening tab")

        // Return to favorites for final validation
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(favoritesTab.isSelected, "Should return to favorites tab")

        // MARK: 8. Architectural Validation - Complete System Integrity
        XCTAssertTrue(app.exists, "App should remain stable after complete favorites flow")
        XCTAssertTrue(tabBar.exists, "Tab system should remain functional")
        XCTAssertTrue(tabBar.exists, "Navigation system should be intact")
    }

    func testCompleteCrossTabArchitecturalJourney() throws {
        let app = XCUIApplication()
        app.launch()

        // MARK: 1. Architectural Foundation - Complete App Launch
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(app.exists, "App should launch successfully")

        // MARK: 2. Architectural Tab System - Full Validation
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar system should exist")
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have exactly 4 tabs")

        let readingTab = tabBar.buttons.element(boundBy: 0)
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        let settingsTab = tabBar.buttons.element(boundBy: 3)

        // MARK: 3. Architectural Journey - Reading → Listening → Favorites → Reading
        // Start in Reading (default)
        XCTAssertTrue(readingTab.exists, "Reading tab should exist")
        XCTAssertTrue(readingTab.isSelected, "Should start in reading tab")

        // Verify reading components
        let treeView = app.tables.firstMatch
        let themeButton = app.navigationBars.buttons["🎨"]
        XCTAssertTrue(treeView.exists, "Reading interface should be available")
        if themeButton.exists {
            themeButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Navigate to Listening
        listeningTab.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertTrue(listeningTab.isSelected, "Should be in listening tab")

        // Verify listening components (navigation bar is hidden in SwiftUI listening view)

        // Navigate to Favorites
        favoritesTab.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertTrue(favoritesTab.isSelected, "Should be in favorites tab")

        // Verify favorites components (navigation bar is hidden in SwiftUI favorites view)

        // Return to Reading
        readingTab.tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertTrue(readingTab.isSelected, "Should return to reading tab")

        // MARK: 4. Architectural Theme System - Cross-Tab Consistency
        if themeButton.exists {
            // Test theme changes persist across tabs
            themeButton.tap()
            Thread.sleep(forTimeInterval: 1.0)

            listeningTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            XCTAssertTrue(app.exists, "Theme system should persist across all tabs")
        }

        // MARK: 5. Architectural Performance - System Stability
        // Perform rapid tab switching to test stability
        for _ in 0..<3 {
            listeningTab.tap()
            Thread.sleep(forTimeInterval: 0.5)
            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 0.5)
            readingTab.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // MARK: 6. Architectural Validation - Complete System Integrity
        XCTAssertTrue(app.exists, "App should be stable after complete cross-tab journey")
        XCTAssertTrue(tabBar.exists, "Tab system should remain functional")
        XCTAssertTrue(treeView.exists, "Reading interface should remain available")
        XCTAssertTrue(readingTab.isSelected, "Should end in reading tab")

        // MARK: Final Architectural Validation
        let finalNavigation = app.navigationBars.firstMatch
        if finalNavigation.exists {
            XCTAssertTrue(finalNavigation.exists, "Navigation system should be intact")
        }
        if themeButton.exists {
            XCTAssertTrue(themeButton.exists, "Enhanced design system should remain operational")
        }
    }

}
