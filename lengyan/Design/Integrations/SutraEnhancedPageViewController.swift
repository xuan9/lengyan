//
//  SutraEnhancedPageViewController.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Enhanced Page View Controller
class SutraEnhancedPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    // MARK: - Enhanced Components
    private var sacredNavigationController: SutraNavigationController?
    private var chapterNavigator: SutraChapterNavigator?
    private var readingProgressView: SutraReadingProgressView?
    private var gestureManager: SutraGestureManager?

    // MARK: - Properties
    private var sutraStoryBoard: UIStoryboard?
    private var page: Int = 0
    private var path: String?
    private var item: [String: String]?
    private var currentTheme: SutraTheme = .light

    // Enhanced state tracking
    private var isReadingModeActive: Bool = false
    private var bookmarkedPages: Set<Int> = []
    private var readingProgress: [Int: CGFloat] = [:]
    private var totalReadingTime: TimeInterval = 0
    private var sessionStartTime: Date?

    // MARK: - Callbacks
    var onDismiss: (() -> Void)?
    var onThemeChange: ((SutraTheme) -> Void)?
    var onBookmarkChange: ((Int, Bool) -> Void)?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupEnhancedInterface()
        configureInitialPage()
        setupGestureManager()
        setupAccessibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startReadingSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        endReadingSession()
    }

    private func setupEnhancedInterface() {
        // Configure enhanced navigation
        configureSacredNavigation()
        setupEnhancedUI()
        updateAppearance()
    }

    private func configureSacredNavigation() {
        if let navigationController = navigationController as? SutraNavigationController {
            sacredNavigationController = navigationController
            navigationController.applyTheme(currentTheme)
            navigationController.configureSacredBarButtons(
                isBookmarked: bookmarkedPages.contains(page),
                onBookmark: { [weak self] in self?.toggleBookmark() },
                onShare: { [weak self] in self?.shareContent() },
                onThemeToggle: { [weak self] in self?.toggleTheme() }
            )
        }
    }

    private func setupEnhancedUI() {
        // Hide navigation bar automatically when scrolling
        navigationController?.hidesBarsOnSwipe = true
        navigationController?.hidesBarsWhenVerticallyCompact = true

        // Configure extended layout
        edgesForExtendedLayout = []
        extendedLayoutIncludesOpaqueBars = false
        automaticallyAdjustsScrollViewInsets = false

        // Setup page view controller
        dataSource = self
        delegate = self

        // Load storyboard
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)
    }

    private func configureInitialPage() {
        guard page >= 0, let index = Book.shared.index, page < index.count else {
            close()
            return
        }

        item = Book.shared.index![page]
        path = item?["path"]

        setEnhancedPageTitle()
        setInitialViewController()
        updateNavigationButtons()
    }

    private func setInitialViewController() {
        let initialViewController = getViewControllerAtIndex(index: page)
        setViewControllers(
            [initialViewController],
            direction: .forward,
            animated: false
        )
    }

    private func setupGestureManager() {
        gestureManager = SutraGestureManager()
        gestureManager?.delegate = self
        gestureManager?.attach(to: view)
        gestureManager?.updateTheme(currentTheme)
    }

    private func setupAccessibility() {
        SutraAccessibilityManager.shared.configureVoiceOver(for: self)
    }

    // MARK: - Enhanced UI Updates

    private func setEnhancedPageTitle() {
        guard let item = item else { return }

        let titleView = SacredTitleView()
        titleView.configure(
            title: Book.shared.getTitleString(item),
            subtitle: "Chapter \(page + 1)",
            icon: UIImage(systemName: "book.fill"),
            theme: currentTheme
        )

        navigationItem.titleView = titleView
    }

    private func updateNavigationButtons() {
        let isBookmarked = bookmarkedPages.contains(page)
        sacredNavigationController?.updateBookmarkState(isBookmarked)
    }

    private func updateAppearance() {
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        updatePageAppearance()
    }

    private func updatePageAppearance() {
        if let currentVC = viewControllers?.first as? SutraPage {
            currentVC.updateTheme(currentTheme)
        }
    }

    // MARK: - Enhanced Reading Features

    private func startReadingSession() {
        sessionStartTime = Date()
        isReadingModeActive = true
        showReadingProgress()
    }

    private func endReadingSession() {
        if let startTime = sessionStartTime {
            let sessionDuration = Date().timeIntervalSince(startTime)
            totalReadingTime += sessionDuration
        }
        isReadingModeActive = false
        hideReadingProgress()
        saveReadingProgress()
    }

    private func showReadingProgress() {
        guard readingProgressView == nil else { return }

        let progressView = SutraReadingProgressView()
        progressView.delegate = self

        let estimatedTime = estimateReadingTime(for: page)
        let currentProgress = readingProgress[page] ?? 0
        let isBookmarked = bookmarkedPages.contains(page)

        progressView.configure(
            totalContent: 100,
            currentPosition: currentProgress,
            estimatedReadingTime: estimatedTime,
            isBookmarked: isBookmarked,
            theme: currentTheme
        )

        progressView.present(from: view, position: 0)
        readingProgressView = progressView
    }

    private func hideReadingProgress() {
        readingProgressView?.dismiss()
        readingProgressView = nil
    }

    private func estimateReadingTime(for pageIndex: Int) -> TimeInterval {
        // Estimate reading time based on content length and average reading speed
        let averageReadingSpeed: Double = 200.0 // words per minute
        let content = Book.shared.getContent(for: pageIndex)
        let wordCount = content.components(separatedBy: .whitespacesAndNewlines).count
        return TimeInterval(wordCount / averageReadingSpeed * 60) // seconds
    }

    private func saveReadingProgress() {
        // Save reading progress to user preferences
        Prefers.shared.updateReadingProgress(readingProgress)
        Prefres.shared.updateTotalReadingTime(totalReadingTime)
    }

    // MARK: - Enhanced Actions

    private func toggleBookmark() {
        let isBookmarked = bookmarkedPages.contains(page)

        if isBookmarked {
            bookmarkedPages.remove(page)
            Prefers.shared.unlike(path ?? "")
        } else {
            bookmarkedPages.insert(page)
            Prefers.shared.like(path ?? "")
        }

        updateNavigationButtons()
        readingProgressView?.updateBookmarkState(!isBookmarked)

        // Animate bookmark change
        SutraHapticManager.shared.haptic(isBookmarked ? .success : .selection)
        SutraAccessibilityManager.shared.announceBookmarkChange(!isBookmarked)

        onBookmarkChange?(page, !isBookmarked)
    }

    private func shareContent() {
        guard let item = item else { return }

        let title = Book.shared.getTitleString(item)
        let content = Book.shared.getContent(for: page)

        let activityViewController = UIActivityViewController(
            activityItems: [title, content],
            applicationActivities: nil
        )

        present(activityViewController, animated: true)
        SutraHapticManager.shared.haptic(.light)
    }

    private func toggleTheme() {
        let themes: [SutraTheme] = [.light, .sepia, .dark]
        guard let currentIndex = themes.firstIndex(of: currentTheme) else { return }

        let nextIndex = (currentIndex + 1) % themes.count
        let newTheme = themes[nextIndex]

        currentTheme = newTheme
        updateAppearance()
        sacredNavigationController?.applyTheme(newTheme)
        gestureManager?.updateTheme(newTheme)
        readingProgressView?.updateTheme(newTheme)

        SutraHapticManager.shared.haptic(.light)
        SutraAccessibilityManager.shared.announceThemeChange(newTheme)

        onThemeChange?(newTheme)
    }

    private func showChapterNavigator() {
        guard chapterNavigator == nil else { return }

        let chapters = Book.shared.getAllChapterTitles()
        let navigator = SutraChapterNavigator()
        navigator.delegate = self

        navigator.configure(
            chapters: chapters,
            currentChapter: page,
            bookmarkedChapters: bookmarkedPages,
            theme: currentTheme
        )

        navigator.present(from: view)
        chapterNavigator = navigator
    }

    private func close() {
        endReadingSession()
        onDismiss?()
        navigationController?.popViewController(animated: true)
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex

        if index == 0 || index == NSNotFound {
            close()
            return nil
        }

        // Skip index pages if navigation bar is hidden
        if navigationController?.isNavigationBarHidden ?? false {
            repeat {
                index -= 1
            } while (!(Book.shared.isItemLeaf(index) ?? true) && index > 0)
        } else {
            index -= 1
        }

        return getViewControllerAtIndex(index: index)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex

        if index == NSNotFound || index + 1 >= (Book.shared.index?.count ?? 0) {
            close()
            return nil
        }

        // Skip index pages if navigation bar is hidden
        if navigationController?.isNavigationBarHidden ?? false {
            repeat {
                index += 1
            } while (!(Book.shared.isItemLeaf(index) ?? true) && index < (Book.shared.index?.count ?? 0) - 1)
        } else {
            index += 1
        }

        return getViewControllerAtIndex(index: index)
    }

    private func getViewControllerAtIndex(index: Int) -> UIViewController {
        let pageContent: SutraPageContentViewController = sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPageContentViewController") as! SutraPageContentViewController

        pageContent.pageIndex = index
        pageContent.onThemeChange = { [weak self] theme in
            self?.currentTheme = theme
            self?.updateAppearance()
        }

        // Configure frame
        let frame = view.frame
        let navigationBarHeight = navigationController?.navigationBar.frame.size.height ?? 0

        pageContent.view.frame = CGRect(
            x: frame.origin.x,
            y: frame.origin.y + navigationBarHeight,
            width: frame.size.width,
            height: frame.size.height - navigationBarHeight
        )

        return pageContent
    }

    // MARK: - UIPageViewControllerDelegate

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else { return }

        let pageContent = pageViewController.viewControllers![0] as! SutraPage
        let previousPage = page
        page = pageContent.pageIndex

        item = Book.shared.index![page]
        path = item?["path"]

        // Update UI with animation
        updatePageWithAnimation(from: previousPage, to: page)
        setEnhancedPageTitle()
        updateNavigationButtons()

        // Announce chapter change for accessibility
        let chapterName = Book.shared.getTitleString(item ?? [:])
        SutraAccessibilityManager.shared.announceChapterChange(chapterName, chapterNumber: page + 1)

        // Animate page turn
        SutraHapticManager.shared.haptic(.medium)
    }

    private func updatePageWithAnimation(from previousPage: Int, to currentPage: Int) {
        // Update reading progress view
        readingProgressView?.updateProgress(position: 0)

        // Update bookmark state
        let isBookmarked = bookmarkedPages.contains(currentPage)
        readingProgressView?.updateBookmarkState(isBookmarked)

        // Update theme for new page
        updatePageAppearance()
    }

    // MARK: - Status Bar

    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    // MARK: - Memory Management

    deinit {
        gestureManager?.detach()
        endReadingSession()
    }
}

// MARK: - SutraGestureManagerDelegate
extension SutraEnhancedPageViewController: SutraGestureManagerDelegate {
    func gestureManager(_ manager: SutraGestureManager, didTapLeftEdge location: CGPoint) {
        // Navigate to previous page
        if let previousVC = dataSource?.pageViewController(self, viewControllerBefore: viewControllers?.first ?? UIViewController()) {
            setViewControllers([previousVC], direction: .reverse, animated: true)
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didTapRightEdge location: CGPoint) {
        // Navigate to next page
        if let nextVC = dataSource?.pageViewController(self, viewControllerAfter: viewControllers?.first ?? UIViewController()) {
            setViewControllers([nextVC], direction: .forward, animated: true)
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didTapCenter location: CGPoint) {
        // Toggle navigation bar visibility
        let shouldHide = !(navigationController?.isNavigationBarHidden ?? false)
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)

        if shouldHide {
            hideReadingProgress()
        } else if isReadingModeActive {
            showReadingProgress()
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didSwipeLeft direction: UISwipeGestureRecognizer.Direction) {
        // Navigate to next page
        if let nextVC = dataSource?.pageViewController(self, viewControllerAfter: viewControllers?.first ?? UIViewController()) {
            setViewControllers([nextVC], direction: .forward, animated: true)
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didSwipeRight direction: UISwipeGestureRecognizer.Direction) {
        // Navigate to previous page
        if let previousVC = dataSource?.pageViewController(self, viewControllerBefore: viewControllers?.first ?? UIViewController()) {
            setViewControllers([previousVC], direction: .reverse, animated: true)
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didSwipeUp direction: UISwipeGestureRecognizer.Direction) {
        // Show chapter navigator
        showChapterNavigator()
    }

    func gestureManager(_ manager: SutraGestureManager, didSwipeDown direction: UISwipeGestureRecognizer.Direction) {
        // Toggle theme
        toggleTheme()
    }

    func gestureManager(_ manager: SutraGestureManager, didPinch scale: CGFloat) {
        // Handle pinch for font size adjustment
        if let currentVC = viewControllers?.first as? SutraPageContentViewController {
            currentVC.adjustFontSize(scale)
        }
    }

    func gestureManager(_ manager: SutraGestureManager, didLongPress location: CGPoint) {
        // Toggle bookmark
        toggleBookmark()
    }

    func gestureManager(_ manager: SutraGestureManager, didDoubleTap location: CGPoint) {
        // Toggle reading mode
        isReadingModeActive.toggle()
        if isReadingModeActive {
            showReadingProgress()
        } else {
            hideReadingProgress()
        }
    }

    func gestureManagerDidRequestBookmark(_ manager: SutraGestureManager) {
        toggleBookmark()
    }

    func gestureManagerDidRequestThemeToggle(_ manager: SutraGestureManager) {
        toggleTheme()
    }

    func gestureManagerDidRequestChapterNavigator(_ manager: SutraGestureManager) {
        showChapterNavigator()
    }

    func gestureManagerDidRequestSettings(_ manager: SutraGestureManager) {
        // Show settings (placeholder)
        showSettings()
    }

    private func showSettings() {
        // Placeholder for settings implementation
        SutraHapticManager.shared.haptic(.light)
    }
}

// MARK: - SutraChapterNavigatorDelegate
extension SutraEnhancedPageViewController: SutraChapterNavigatorDelegate {
    func chapterNavigator(_ navigator: SutraChapterNavigator, didSelectChapter chapter: Int) {
        guard chapter != page else { return }

        let targetVC = getViewControllerAtIndex(index: chapter)
        let direction: UIPageViewControllerNavigationDirection = chapter > page ? .forward : .reverse

        setViewControllers([targetVC], direction: direction, animated: true)
        chapterNavigator = nil
    }

    func chapterNavigator(_ navigator: SutraChapterNavigator, didRequestBookmarkForChapter chapter: Int) {
        if chapter == page {
            toggleBookmark()
        }
    }

    func chapterNavigatorDidRequestThemeToggle(_ navigator: SutraChapterNavigator) {
        toggleTheme()
    }
}

// MARK: - SutraReadingProgressDelegate
extension SutraEnhancedPageViewController: SutraReadingProgressDelegate {
    func readingProgressView(_ progressView: SutraReadingProgressView, didRequestJumpTo position: CGFloat) {
        // Update reading progress
        readingProgress[page] = position

        // Announce progress for accessibility
        SutraAccessibilityManager.shared.announceReadingProgress(Float(position / 100), for: view)
    }

    func readingProgressViewDidRequestBookmark(_ progressView: SutraReadingProgressView) {
        toggleBookmark()
    }
}

// MARK: - Accessibility Extensions
extension SutraEnhancedPageViewController {
    @objc override func accessibilityPreviousPage() {
        gestureManager?.gestureManager(SutraGestureManager(), didSwipeRight: .right)
    }

    @objc override func accessibilityNextPage() {
        gestureManager?.gestureManager(SutraGestureManager(), didSwipeLeft: .left)
    }

    @objc override func accessibilityToggleBookmark() {
        toggleBookmark()
    }

    @objc override func accessibilityShare() {
        shareContent()
    }

    @objc override func accessibilityChangeTheme() {
        toggleTheme()
    }

    @objc override func accessibilityChapterNavigator() {
        showChapterNavigator()
    }
}