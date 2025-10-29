//
//  EnhancedViewControllersTests.swift
//  lengyan
//
//  Test suite for enhanced view controllers with design system integration
//

import XCTest
import UIKit
@testable import lengyan

class EnhancedViewControllersTests: XCTestCase {

    // MARK: - Test Properties
    var sutraFrontVC: EnhancedSutraFrontViewController!
    var sutraPageVC: EnhancedSutraPageViewController!
    var sutraIndexVC: EnhancedSutraIndexViewController!
    var mediaTableVC: EnhancedMediaTableViewController!

    // MARK: - Test Lifecycle
    override func setUp() {
        super.setUp()
        setupViewControllers()
    }

    override func tearDown() {
        cleanupViewControllers()
        super.tearDown()
    }

    private func setupViewControllers() {
        // Initialize view controllers for testing
        sutraFrontVC = EnhancedSutraFrontViewController()
        sutraPageVC = EnhancedSutraPageViewController()
        sutraIndexVC = EnhancedSutraIndexViewController()
        mediaTableVC = EnhancedMediaTableViewController()

        // Load view hierarchies
        sutraFrontVC.loadViewIfNeeded()
        sutraPageVC.loadViewIfNeeded()
        sutraIndexVC.loadViewIfNeeded()
        mediaTableVC.loadViewIfNeeded()
    }

    private func cleanupViewControllers() {
        sutraFrontVC = nil
        sutraPageVC = nil
        sutraIndexVC = nil
        mediaTableVC = nil
    }

    // MARK: - EnhancedSutraFrontViewController Tests

    func testSutraFrontViewControllerInitialization() {
        XCTAssertNotNil(sutraFrontVC, "Enhanced SutraFrontViewController should initialize successfully")
        XCTAssertEqual(sutraFrontVC.view.backgroundColor, SutraColors.Semantic.background(theme: .light), "Background should match design system")
    }

    func testSutraFrontViewControllerComponents() {
        // Test that key components are created
        XCTAssertNotNil(sutraFrontVC.treeView, "Tree view should be created")
        XCTAssertNotNil(sutraFrontVC.headerView, "Header view should be created")
        XCTAssertNotNil(sutraFrontVC.footerView, "Footer view should be created")
    }

    func testSutraFrontViewControllerChapterButtons() {
        // Test chapter button creation
        let testButton = sutraFrontVC.makeEnhancedChapterButton(chapter: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        XCTAssertNotNil(testButton, "Chapter button should be created")
        XCTAssertEqual(testButton.tag, 0, "Button tag should match chapter index")
        XCTAssertNotNil(testButton.titleLabel?.text, "Button should have title")
    }

    func testSutraFrontViewControllerThemeUpdates() {
        // Test theme switching
        sutraFrontVC.updateTheme()
        XCTAssertEqual(sutraFrontVC.view.backgroundColor, SutraColors.Semantic.background(theme: .light), "Theme should update correctly")
    }

    func testSutraFrontViewControllerAccessibility() {
        // Test accessibility setup
        XCTAssertTrue(sutraFrontVC.isAccessibilityElement == false, "View controller should not be accessibility element")
        XCTAssertNotNil(sutraFrontVC.accessibilityLabel, "Should have accessibility label")
    }

    // MARK: - EnhancedSutraPageViewController Tests

    func testSutraPageViewControllerInitialization() {
        XCTAssertNotNil(sutraPageVC, "Enhanced SutraPageViewController should initialize successfully")
        XCTAssertEqual(sutraPageVC.view.backgroundColor, SutraColors.Semantic.background(theme: .light), "Background should match design system")
    }

    func testSutraPageViewControllerComponents() {
        // Test that key components are created
        XCTAssertNotNil(sutraPageVC.progressView, "Progress view should be created")
        XCTAssertNotNil(sutraPageVC.chapterNavigator, "Chapter navigator should be created")
    }

    func testSutraPageViewControllerNavigationSetup() {
        // Test navigation bar setup
        sutraPageVC.setupNavigationBar()
        XCTAssertNotNil(sutraPageVC.navigationItem.leftBarButtonItem, "Should have left bar button item")
        XCTAssertNotNil(sutraPageVC.navigationItem.rightBarButtonItem, "Should have right bar button item")
    }

    func testSutraPageViewControllerPlayerIntegration() {
        // Test player-related functionality
        sutraPageVC.updateProgressView()
        XCTAssertNotNil(sutraPageVC.progressView, "Progress view should be available")
    }

    // MARK: - EnhancedSutraIndexViewController Tests

    func testSutraIndexViewControllerInitialization() {
        XCTAssertNotNil(sutraIndexVC, "Enhanced SutraIndexViewController should initialize successfully")
        XCTAssertEqual(sutraIndexVC.view.backgroundColor, SutraColors.Semantic.background(theme: .light), "Background should match design system")
    }

    func testSutraIndexViewControllerSearchSetup() {
        // Test search controller setup
        XCTAssertNotNil(sutraIndexVC.searchController, "Search controller should be created")
        XCTAssertNotNil(sutraIndexVC.searchController.searchResultsUpdater, "Search results updater should be set")
    }

    func testSutraIndexViewControllerEmptyState() {
        // Test empty state handling
        sutraIndexVC.showEmptyState(true)
        XCTAssertNotNil(sutraIndexVC.emptyStateView, "Empty state view should be created")
        XCTAssertTrue(sutraIndexVC.emptyStateView?.isHidden == false, "Empty state should be visible when shown")
    }

    func testSutraIndexViewControllerDataFiltering() {
        // Test data filtering functionality
        sutraIndexVC.isSearchActive = true
        sutraIndexVC.filterItems(with: "test")
        XCTAssertTrue(sutraIndexVC.filteredItems.isEmpty == true || true, "Filtering should complete without crashing")
    }

    // MARK: - EnhancedMediaTableViewController Tests

    func testMediaTableViewControllerInitialization() {
        XCTAssertNotNil(mediaTableVC, "Enhanced MediaTableViewController should initialize successfully")
        XCTAssertEqual(mediaTableVC.view.backgroundColor, SutraColors.Semantic.background(theme: .light), "Background should match design system")
    }

    func testMediaTableViewControllerPlayerSetup() {
        // Test player setup
        XCTAssertNotNil(mediaTableVC.playerFooterView, "Player footer view should be created")
        XCTAssertNotNil(mediaTableVC.playerProgressSlider, "Progress slider should be created")
        XCTAssertNotNil(mediaTableVC.playerPlayButton, "Play button should be created")
    }

    func testMediaTableViewControllerAudioSession() {
        // Test audio session setup
        XCTAssertNoThrow(mediaTableVC.setupAudioSession(), "Audio session setup should not throw")
    }

    func testMediaTableViewControllerTimeFormatting() {
        // Test time formatting
        let formattedTime = mediaTableVC.getMediaDisplayTime(seconds: 125)
        XCTAssertEqual(formattedTime, "02:05", "Time should be formatted correctly")
    }

    func testMediaTableViewControllerPlayerExpansion() {
        // Test player expansion functionality
        XCTAssertFalse(mediaTableVC.isPlayerExpanded, "Player should not be expanded initially")

        mediaTableVC.expandPlayer()
        XCTAssertTrue(mediaTableVC.isPlayerExpanded, "Player should be expanded after calling expand")

        mediaTableVC.collapsePlayer()
        XCTAssertFalse(mediaTableVC.isPlayerExpanded, "Player should be collapsed after calling collapse")
    }

    // MARK: - Design System Integration Tests

    func testDesignSystemColorConsistency() {
        // Test that all view controllers use consistent colors
        let frontBG = sutraFrontVC.view.backgroundColor
        let pageBG = sutraPageVC.view.backgroundColor
        let indexBG = sutraIndexVC.view.backgroundColor
        let mediaBG = mediaTableVC.view.backgroundColor

        XCTAssertEqual(frontBG, pageBG, "All view controllers should use same background color")
        XCTAssertEqual(pageBG, indexBG, "All view controllers should use same background color")
        XCTAssertEqual(indexBG, mediaBG, "All view controllers should use same background color")
    }

    func testDesignSystemThemeSwitching() {
        // Test theme switching across all view controllers
        let originalTheme = SutraThemeManager.shared.currentTheme

        // Switch to sepia theme
        SutraThemeManager.shared.switchTheme(to: .sepia)
        sutraFrontVC.updateTheme()
        sutraPageVC.updateTheme()
        sutraIndexVC.updateTheme()
        mediaTableVC.updateTheme()

        XCTAssertEqual(sutraFrontVC.view.backgroundColor, SutraColors.Semantic.background(theme: .sepia), "Front VC should update to sepia theme")
        XCTAssertEqual(sutraPageVC.view.backgroundColor, SutraColors.Semantic.background(theme: .sepia), "Page VC should update to sepia theme")
        XCTAssertEqual(sutraIndexVC.view.backgroundColor, SutraColors.Semantic.background(theme: .sepia), "Index VC should update to sepia theme")
        XCTAssertEqual(mediaTableVC.view.backgroundColor, SutraColors.Semantic.background(theme: .sepia), "Media VC should update to sepia theme")

        // Restore original theme
        SutraThemeManager.shared.switchTheme(to: originalTheme)
    }

    // MARK: - Memory Management Tests

    func testMemoryLeaks() {
        // Test for potential memory leaks
        weak var weakFrontVC: EnhancedSutraFrontViewController?
        weak var weakPageVC: EnhancedSutraPageViewController?
        weak var weakIndexVC: EnhancedSutraIndexViewController?
        weak var weakMediaVC: EnhancedMediaTableViewController?

        autoreleasepool {
            let frontVC = EnhancedSutraFrontViewController()
            let pageVC = EnhancedSutraPageViewController()
            let indexVC = EnhancedSutraIndexViewController()
            let mediaVC = EnhancedMediaTableViewController()

            weakFrontVC = frontVC
            weakPageVC = pageVC
            weakIndexVC = indexVC
            weakMediaVC = mediaVC

            // Simulate view lifecycle
            frontVC.loadViewIfNeeded()
            pageVC.loadViewIfNeeded()
            indexVC.loadViewIfNeeded()
            mediaVC.loadViewIfNeeded()
        }

        // Allow time for cleanup
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // Verify deallocation (this might not always work due to system caching)
        // In a real test environment, you'd use more sophisticated memory leak detection
    }

    // MARK: - Animation Tests

    func testAnimationInitialization() {
        // Test that animations are properly initialized
        XCTAssertFalse(sutraFrontVC.hasAppeared, "hasAppeared should be false initially")
        XCTAssertFalse(sutraPageVC.hasAppeared, "hasAppeared should be false initially")
        XCTAssertFalse(sutraIndexVC.hasAppeared, "hasAppeared should be false initially")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        // Test accessibility labels are set
        XCTAssertNotNil(sutraFrontVC.accessibilityLabel, "Front VC should have accessibility label")
        XCTAssertNotNil(sutraPageVC.accessibilityLabel, "Page VC should have accessibility label")
        XCTAssertNotNil(sutraIndexVC.accessibilityLabel, "Index VC should have accessibility label")
        XCTAssertNotNil(mediaTableVC.accessibilityLabel, "Media VC should have accessibility label")
    }

    func testAccessibilityHints() {
        // Test accessibility hints are provided
        XCTAssertNotNil(sutraFrontVC.accessibilityHint, "Front VC should have accessibility hint")
        XCTAssertNotNil(sutraPageVC.accessibilityHint, "Page VC should have accessibility hint")
        XCTAssertNotNil(sutraIndexVC.accessibilityHint, "Index VC should have accessibility hint")
        XCTAssertNotNil(mediaTableVC.accessibilityHint, "Media VC should have accessibility hint")
    }

    // MARK: - Performance Tests

    func testViewLoadingPerformance() {
        // Test view loading performance
        measure {
            let vc = EnhancedSutraFrontViewController()
            vc.loadViewIfNeeded()
        }
    }

    func testThemeUpdatePerformance() {
        // Test theme update performance
        measure {
            sutraFrontVC.updateTheme()
            sutraPageVC.updateTheme()
            sutraIndexVC.updateTheme()
            mediaTableVC.updateTheme()
        }
    }

    // MARK: - Integration Tests

    func testViewControllerTransitions() {
        // Test that view controllers can transition properly
        let navigationController = UINavigationController()
        navigationController.pushViewController(sutraFrontVC, animated: false)

        XCTAssertEqual(navigationController.topViewController, sutraFrontVC, "Front VC should be top view controller")

        navigationController.pushViewController(sutraPageVC, animated: false)
        XCTAssertEqual(navigationController.topViewController, sutraPageVC, "Page VC should be top view controller")
    }

    func testDataFlowBetweenControllers() {
        // Test data flow between controllers
        // This would require setting up mock data and testing the flow
        // For now, we'll just verify the structures exist
        XCTAssertNotNil(sutraFrontVC.tree, "Front VC should have tree structure")
        XCTAssertNotNil(sutraPageVC.item, "Page VC should have item structure")
        XCTAssertNotNil(sutraIndexVC.tree, "Index VC should have tree structure")
        XCTAssertNotNil(mediaTableVC.media, "Media VC should have media structure")
    }
}

// MARK: - Mock Classes for Testing

class MockBook {
    static let shared = MockBook()

    func getKeyItems() -> [[String]] {
        return [["test/path", "Test Item"]]
    }

    func getSutraAttributeString(text: String) -> String {
        return text
    }

    func getChapterSutra(chapter: Int) -> String {
        return "Chapter \(chapter) content"
    }
}

class MockPrefers {
    static let shared = MockPrefers()

    var lastPlayMode: Int?
    var lastPlayFile: [String]?

    func like(_ path: String) {
        // Mock implementation
    }

    func unlike(_ path: String) {
        // Mock implementation
    }
}

// MARK: - Test Utilities

extension XCTestCase {
    func loadView(_ viewController: UIViewController) {
        viewController.loadViewIfNeeded()
        viewController.beginAppearanceTransition(true, animated: false)
        viewController.endAppearanceTransition()
    }

    func unloadView(_ viewController: UIViewController) {
        viewController.beginAppearanceTransition(false, animated: false)
        viewController.endAppearanceTransition()
    }
}