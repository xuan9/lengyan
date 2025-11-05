//
//  SutraPageViewController+Enhanced.swift
//  lengyan
//
//  Enhanced version with new design system integration
//  Maintains all existing functionality while adding modern reading experience
//

import UIKit

class EnhancedSutraPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    // MARK: - Properties
    var sutraStoryBoard: UIStoryboard?
    var onDismiss: (() -> Void)?
    var page: Int = 0
    var path: String?
    var item: [String: String]?

    // MARK: - UI Components
    private var progressView: SutraReadingProgressView!
    private var chapterNavigator: SutraChapterNavigator!
    private var gestureManager: SutraGestureManager!
    private var accessibilityManager: SutraAccessibilityManager!

    // Design System
    private let themeManager = SutraThemeManager.shared
    private var currentTheme: SutraTheme = .light

    // Navigation Enhancement
    private var isNavigationBarHidden = false
    private var tapGesture: UITapGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!

    // Animation
    private var hasAppeared = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesignSystem()
        setupEnhancedNavigation()
        setupGestures()
        setupEnhancedUI()
        setupAccessibility()
        loadInitialPage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTheme()
        setupNavigationBar()
        hideNavigationBarAfterDelay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppeared {
            animateEntrance()
            hasAppeared = true
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isNavigationBarHidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }

    // MARK: - Setup Methods
    private func setupDesignSystem() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
    }

    private func setupEnhancedNavigation() {
        navigationController?.hidesBarsOnSwipe = true
        navigationController?.hidesBarsWhenVerticallyCompact = true
        navigationController?.navigationBar.prefersLargeTitles = false

        edgesForExtendedLayout = []
        extendedLayoutIncludesOpaqueBars = false
        automaticallyAdjustsScrollViewInsets = false

        // Custom navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.titleTextAttributes = [
            .foregroundColor: SutraColors.Semantic.primary(theme: currentTheme),
            .font: SutraTypography.Typography.title3
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
    }

    private func setupGestures() {
        gestureManager = SutraGestureManager()

        // Tap gesture for navigation bar toggle
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)

        // Pan gesture for enhanced navigation
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        view.addGestureRecognizer(panGesture)
    }

    private func setupEnhancedUI() {
        setupProgressView()
        setupChapterNavigator()
        dataSource = self
        delegate = self
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)
    }

    private func setupProgressView() {
        progressView = SutraReadingProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.configure(
            currentPage: page,
            totalPages: Book.shared.index?.count ?? 0,
            theme: currentTheme
        )
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])

        progressView.alpha = 0
    }

    private func setupChapterNavigator() {
        chapterNavigator = SutraChapterNavigator()
        chapterNavigator.translatesAutoresizingMaskIntoConstraints = false
        chapterNavigator.configure(
            currentItem: item,
            theme: currentTheme,
            delegate: self
        )
        view.addSubview(chapterNavigator)

        NSLayoutConstraint.activate([
            chapterNavigator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chapterNavigator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chapterNavigator.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -12),
            chapterNavigator.heightAnchor.constraint(equalToConstant: 44)
        ])

        chapterNavigator.alpha = 0
    }

    private func setupAccessibility() {
        accessibilityManager = SutraAccessibilityManager()
        accessibilityManager.configurePageViewController(self)

        isAccessibilityElement = false
        accessibilityLabel = NSLocalizedString("sutra_reading_page", comment: "Sutra reading page")
        accessibilityHint = NSLocalizedString("swipe_to_navigate_pages", comment: "Swipe left or right to navigate between pages")
    }

    private func loadInitialPage() {
        if page < 0 {
            close()
            return
        }

        item = Book.shared.index![page]
        path = item!["path"]

        setPageTitle()
        setViewControllers(
            [getViewControllerAtIndex(index: page)],
            direction: .forward,
            animated: false,
            completion: nil
        )
        setTitle()
        updateProgressView()
        updateChapterNavigator()
    }

    private func setupNavigationBar() {
        let leftButton = createBackButton()
        let rightButton = createBookmarkButton()

        navigationItem.leftBarButtonItem = leftButton
        navigationItem.rightBarButtonItem = rightButton

        // Enhanced title view
        setTitle()
    }

    private func createBackButton() -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.setTitle("  " + NSLocalizedString("back", comment: "Back"), for: .normal)
        button.titleLabel?.font = SutraTypography.Typography.body
        button.setTitleColor(SutraColors.Semantic.primary(theme: currentTheme), for: .normal)
        button.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        button.accessibilityLabel = NSLocalizedString("back", comment: "Back")
        button.accessibilityHint = NSLocalizedString("go_back_to_previous_screen", comment: "Go back to the previous screen")

        return UIBarButtonItem(customView: button)
    }

    private func createBookmarkButton() -> UIBarButtonItem {
        let isBookmarked = Prefers.shared.likes.contains(path ?? "")
        let imageName = isBookmarked ? "heart.fill" : "heart"

        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = isBookmarked ? SutraColors.Light.favorite : SutraColors.Semantic.textSecondary(theme: currentTheme)
        button.addTarget(self, action: isBookmarked ? #selector(unlike) : #selector(like), for: .touchUpInside)
        button.accessibilityLabel = isBookmarked ?
            NSLocalizedString("remove_bookmark", comment: "Remove bookmark") :
            NSLocalizedString("add_bookmark", comment: "Add bookmark")
        button.accessibilityHint = isBookmarked ?
            NSLocalizedString("remove_this_page_from_bookmarks", comment: "Remove this page from bookmarks") :
            NSLocalizedString("add_this_page_to_bookmarks", comment: "Add this page to bookmarks")

        return UIBarButtonItem(customView: button)
    }

    private func hideNavigationBarAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.isNavigationBarHidden {
                self.toggleNavigationBar(hide: true)
            }
        }
    }

    // MARK: - Theme Updates
    private func updateTheme() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        progressView?.updateTheme(currentTheme)
        chapterNavigator?.updateTheme(currentTheme)
        setupNavigationBar()
    }

    private func updateProgressView() {
        guard let progressView = progressView,
              let totalCount = Book.shared.index?.count else { return }

        progressView.updateProgress(
            currentPage: page,
            totalPages: totalCount,
            animated: hasAppeared
        )
    }

    private func updateChapterNavigator() {
        chapterNavigator?.updateCurrentItem(item)
    }

    // MARK: - Navigation Bar Management
    private func toggleNavigationBar(hide: Bool) {
        isNavigationBarHidden = hide

        UIView.animate(withDuration: 0.3, animations: {
            self.navigationController?.setNavigationBarHidden(hide, animated: false)
            self.setNeedsStatusBarAppearanceUpdate()

            // Show/hide navigation elements
            self.progressView.alpha = hide ? 1.0 : 0.0
            self.chapterNavigator.alpha = hide ? 1.0 : 0.0
        })
    }

    // MARK: - Button Actions
    @objc private func like() {
        guard let path = path else { return }
        HapticFeedback.lightImpact()
        Prefers.shared.like(path)
        animateBookmarkChange()
        setTitle()
    }

    @objc private func unlike() {
        guard let path = path else { return }
        HapticFeedback.lightImpact()
        Prefers.shared.unlike(path)
        animateBookmarkChange()
        setTitle()
    }

    @objc private func close() {
        HapticFeedback.lightImpact()
        onDismiss?()
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)

        // Check if tap is in navigation area (top 20% of screen)
        if location.y < view.bounds.height * 0.2 {
            toggleNavigationBar(hide: !isNavigationBarHidden)
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        gestureManager.handlePanGesture(gesture, in: self) { [weak self] direction in
            self?.handlePanNavigation(direction)
        }
    }

    private func handlePanNavigation(_ direction: SutraGestureDirection) {
        switch direction {
        case .left:
            navigateToNextPage()
        case .right:
            navigateToPreviousPage()
        case .up, .down:
            // Handle vertical navigation if needed
            break
        }
    }

    private func animateBookmarkChange() {
        guard let rightButton = navigationItem.rightBarButtonItem,
              let button = rightButton.customView as? UIButton else { return }

        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                button.transform = .identity
            })
        }
    }

    // MARK: - Navigation Methods
    private func navigateToNextPage() {
        guard let currentVC = viewControllers?.first else { return }

        if let nextVC = pageViewController(self, viewControllerAfter: currentVC) {
            setViewControllers([nextVC], direction: .forward, animated: true) { _ in
                self.updatePageAfterNavigation(to: nextVC)
            }
        }
    }

    private func navigateToPreviousPage() {
        guard let currentVC = viewControllers?.first else { return }

        if let prevVC = pageViewController(self, viewControllerBefore: currentVC) {
            setViewControllers([prevVC], direction: .reverse, animated: true) { _ in
                self.updatePageAfterNavigation(to: prevVC)
            }
        }
    }

    private func updatePageAfterNavigation(to viewController: UIViewController) {
        if let pageContent = viewController as? SutraPage {
            page = pageContent.pageIndex
            item = Book.shared.index![page]
            path = item?["path"]
            setPageTitle()
            setTitle()
            updateProgressView()
            updateChapterNavigator()
        }
    }

    private func setTitle() {
        let leftButton = createBackButton()
        let rightButton = createBookmarkButton()

        navigationItem.leftBarButtonItem = leftButton
        navigationItem.rightBarButtonItem = rightButton

        // Enhanced title view
        if let item = item {
            if navigationItem.titleView is UILabel {
                (navigationItem.titleView as! UILabel).attributedText = Book.shared.getTitle(item)
            } else {
                navigationItem.titleView = Book.shared.getTitleView(item)
            }
        }
    }

    private func setPageTitle() {
        guard let item = item else { return }

        if let titleLabel = navigationItem.titleView as? UILabel {
            titleLabel.attributedText = Book.shared.getTitle(item)
        } else {
            navigationItem.titleView = Book.shared.getTitleView(item)
        }
    }

    // MARK: - Animations
    private func animateEntrance() {
        // Fade in progress view and chapter navigator
        UIView.animate(withDuration: 0.5, delay: 0.5, options: [.curveEaseOut]) {
            self.progressView.alpha = 1.0
            self.chapterNavigator.alpha = 1.0
        }
    }

    // MARK: - UIPageViewController DataSource
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex

        if index == 0 || index == NSNotFound {
            close()
            return nil
        }

        if isNavigationBarHidden {
            // Skip index pages if nav hidden
            repeat {
                index -= 1
            } while (!(Book.shared.isItemLeaf(index) ?? true))
        } else {
            index -= 1
        }

        return getViewControllerAtIndex(index: index)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex

        if index == NSNotFound || index + 1 == Book.shared.index?.count {
            close()
            return nil
        }

        if isNavigationBarHidden {
            // Skip index pages if nav hidden
            repeat {
                index += 1
            } while (!(Book.shared.isItemLeaf(index) ?? true))
        } else {
            index += 1
        }

        return getViewControllerAtIndex(index: index)
    }

    private func getViewControllerAtIndex(index: Int) -> UIViewController {
        let pageContent: SutraPageContentViewController = sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPageContentViewController") as! SutraPageContentViewController

        pageContent.pageIndex = index

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

    // MARK: - UIPageViewController Delegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

        guard completed, let pageContent = pageViewController.viewControllers?.first as? SutraPage else { return }

        page = pageContent.pageIndex
        item = Book.shared.index![page]
        path = item?["path"]
        setPageTitle()
        setTitle()
        updateProgressView()
        updateChapterNavigator()
    }
}

// MARK: - SutraChapterNavigatorDelegate
extension EnhancedSutraPageViewController: SutraChapterNavigatorDelegate {
    func chapterNavigator(_ navigator: SutraChapterNavigator, didSelectChapter chapter: Int) {
        HapticFeedback.lightImpact()
        openChapter(chapter: chapter)
    }

    func chapterNavigator(_ navigator: SutraChapterNavigator, didSelectSection section: String) {
        HapticFeedback.lightImpact()
        // Handle section navigation
    }

    private func openChapter(chapter: Int) {
        let content = Book.shared.getSutraAttributeString(text: Book.shared.getChapterSutra(chapter: chapter))
        let title = NSLocalizedString("chapter_\(chapter + 1)", comment: "chapter_name")
        let pageVC = ReaderViewController(title: title, content: content)
        navigationController?.pushViewController(pageVC, animated: true)
    }
}

// MARK: - Enhanced Page Content Support
protocol SutraPage {
    var pageIndex: Int { get }
    func updateTheme(_ theme: SutraTheme)
}