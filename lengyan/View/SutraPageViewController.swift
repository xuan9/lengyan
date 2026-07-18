//
//  SutraPageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate{
    // STORYBOARD REMOVED: Using programmatic UI now
    var onDismiss: (() -> Void)?
    private let readingCheckpoint = ReadingCheckpointGate()
    private var isReaderVisible = false
    var page:Int = 0
    var isEmbedded = false

    var path:String?
    var item:[String:String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "reader.paged"
        setupApplicationLifecycleObservers()
        self.navigationController?.hidesBarsOnSwipe = false;
        self.navigationController?.hidesBarsOnTap = false;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleNavigationBar))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGesture)
        self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 翻页控制器底层背景色

        // 导航栏 — 与内容同色，无边界，按钮完全无背景色块
        let bgColor = SutraDesignTokens.shared.color(for: .background)
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = bgColor
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        // 按钮外观：显式清除所有状态的背景
        let btnAppearance = UIBarButtonItemAppearance(style: .plain)
        btnAppearance.normal.backgroundImage = UIImage()
        btnAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
        btnAppearance.highlighted.backgroundImage = UIImage()
        btnAppearance.highlighted.titleTextAttributes = [.foregroundColor: secondaryColor.withAlphaComponent(0.5)]
        btnAppearance.disabled.backgroundImage = UIImage()
        btnAppearance.focused.backgroundImage = UIImage()
        appearance.buttonAppearance = btnAppearance
        appearance.doneButtonAppearance = btnAppearance
        appearance.setBackIndicatorImage(UIImage(), transitionMaskImage: UIImage())
        
        if let navBar = self.navigationController?.navigationBar {
            navBar.standardAppearance = appearance
            navBar.compactAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.isTranslucent = false
            navBar.tintColor = secondaryColor
            navBar.setBackgroundImage(UIImage(), for: .default)
            navBar.shadowImage = UIImage()
            navBar.barTintColor = bgColor
            navBar.backgroundColor = bgColor
        }
        
        if page < 0 {
            self.close()
            return
        }
        // 边界守卫：防止深链/状态恢复传入越界 page 导致崩溃
        guard let indexArr = Book.shared.index, page < indexArr.count else {
            self.close()
            return
        }
        item = indexArr[page]
        self.path = item?["path"]
        
        self.setPageTitle()
        self.dataSource = self;
        self.delegate = self;

        // STORYBOARD REMOVED: Using programmatic UI now
        self.setViewControllers([getViewControllerAtIndex(index: page)] as [UIViewController], direction: UIPageViewController.NavigationDirection.forward, animated: false, completion: nil)

        self.setTitle()
    }

    func updatePage(to index: Int) {
        guard index >= 0, let indexArr = Book.shared.index, index < indexArr.count else { return }
        self.page = index
        self.item = indexArr[index]
        self.path = item?["path"]
        self.setPageTitle()
        self.setTitle()
        self.setViewControllers([getViewControllerAtIndex(index: index)] as [UIViewController], direction: .forward, animated: false, completion: nil)
        
        // Save progress
        recordCurrentReading()
    }

    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isEmbedded {
            self.tabBarController?.tabBar.isHidden = true
            if #available(iOS 18.0, *) {
                self.tabBarController?.setTabBarHidden(true, animated: false)
            }
        }
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = false
        self.navigationController?.hidesBarsWhenVerticallyCompact = true
        self.navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = false
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isReaderVisible = true
        resumeReadingCheckpointIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !isEmbedded {
            self.tabBarController?.tabBar.isHidden = false
            if #available(iOS 18.0, *) {
                self.tabBarController?.setTabBarHidden(false, animated: false)
            }
        }
        self.navigationController?.hidesBarsOnTap = false
        pauseReadingCheckpointIfNeeded()
        isReaderVisible = false
    }

    private func setupApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationWillResignActive() {
        guard isReaderVisible else { return }
        pauseReadingCheckpointIfNeeded()
    }

    @objc private func applicationDidEnterBackground() {
        guard isReaderVisible else { return }
        pauseReadingCheckpointIfNeeded()
    }

    @objc private func applicationDidBecomeActive() {
        resumeReadingCheckpointIfNeeded()
    }

    private func resumeReadingCheckpointIfNeeded() {
        guard
            isReaderVisible,
            UIApplication.shared.applicationState == .active
        else { return }
        // Background time must not satisfy the passive-reading threshold.
        readingCheckpoint.resume { [weak self] in
            guard let self, self.isReaderVisible else { return }
            self.persistCurrentReading()
        }
    }

    private func pauseReadingCheckpointIfNeeded() {
        readingCheckpoint.pause { [weak self] in
            self?.persistCurrentReading()
        }
    }

    private func recordCurrentReading() {
        readingCheckpoint.commit { [weak self] in
            self?.persistCurrentReading()
        }
    }

    /// Called by the visible content page when the user deliberately scrolls
    /// inside a long outline node. This intent should bypass mis-tap filtering.
    func confirmReadingInteraction() {
        recordCurrentReading()
    }

    private func persistCurrentReading() {
        guard let path = self.path, page >= 0 else { return }
        Prefers.shared.recordPagedReading(path: path, pageIndex: page)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func like() {
        HapticManager.shared.bookmarkToggle()
        Prefers.shared.like(self.path!)
        self.setTitle()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
    
    @objc func unlike() {
        HapticManager.shared.bookmarkToggle()
        Prefers.shared.unlike(self.path!)
        self.setTitle()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
    
    @objc func close() {
        print("DEBUG: SutraPageViewController close() - Stack before pop: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
        self.onDismiss?()
        let popped = self.navigationController?.popViewController(animated: true)
        print("DEBUG: SutraPageViewController close() - Popped VC: \(String(describing: popped)), Stack after pop: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
    }
    
    @objc func share() {
        guard let path = self.path else { return }
        let item = Book.shared.itemOfPath(path)
        let bookTitle = NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》")

        // 完整经文（不截断），来源只留《楞嚴經》（去掉科判后缀）
        let sutraText = Book.shared.getSutra(item)

        // 走预览页：用户可选「分享美图（自动长图）/ 分享文字 / 拷贝」
        SutraCardRenderer.presentPreview(
            text: sutraText,
            source: bookTitle,
            from: self,
            barButtonItem: self.navigationItem.rightBarButtonItems?.first
        )
    }
    
    func setTitle() {
        let isHidden = self.navigationController?.isNavigationBarHidden ?? false

        // Right side: Bookmark + Share (禅意极简排列)
        let shareIcon = UIImage(systemName: "square.and.arrow.up")
        let shareButton = UIBarButtonItem(image: shareIcon, style: .plain, target: self, action: #selector(share))

        let isLiked = Prefers.shared.isLike(path!)
        let bookmarkIcon = UIImage(systemName: isLiked ? "bookmark.fill" : "bookmark")
        let bookmarkButton = UIBarButtonItem(image: bookmarkIcon, style: .plain, target: self, action: isLiked ? #selector(unlike) : #selector(like))

        // 按钮颜色
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        if isEmbedded {
            self.navigationItem.leftBarButtonItem = nil
        } else {
            let backIcon = UIImage(systemName: "chevron.left")
            let backBarButton = UIBarButtonItem(image: backIcon, style: .plain, target: self, action: #selector(close))
            self.navigationItem.leftBarButtonItem = backBarButton
            self.navigationItem.leftBarButtonItem?.tintColor = secondaryTextColor
            if #available(iOS 26.0, *) {
                backBarButton.hidesSharedBackground = true
            }
        }

        shareButton.tintColor = secondaryTextColor
        bookmarkButton.tintColor = isLiked ? bookmarkColor : secondaryTextColor

        // 移除 iOS 26 Liquid Glass 按钮背景，与导航栏完全融合
        if #available(iOS 26.0, *) {
            shareButton.hidesSharedBackground = true
            bookmarkButton.hidesSharedBackground = true
        }

        // Grouping right buttons: [Share on the far right] [Bookmark]
        self.navigationItem.rightBarButtonItems = [shareButton, bookmarkButton]

        if isHidden {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
        }
    }
        
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent:  SutraPage = viewController as!  SutraPage
        var index = pageContent.pageIndex
        if ((index == 0) || (index == NSNotFound))
        {
            return nil;
        }
        // 始终跳过非叶子节点（目录页），只翻到有经文的页面
        repeat {
            index -= 1;
            guard index >= 0 else { return nil }
        } while !(Book.shared.isItemLeaf(index) ?? true)
        return getViewControllerAtIndex(index: index)
    }
    
    func getViewControllerAtIndex(index: Int) -> UIViewController
    {
        // Create the standard page content controller and enhance it
        let pageContent = SutraPageContentViewController()
 
        pageContent.pageIndex = index
        pageContent.parentReader = self
 
        let frame = self.view.frame;
        // 使用 safeAreaInsets 而非 navigationBar 高度，
        // 这样无论导航栏是否隐藏（hidesBarsOnSwipe），内容都不会被灵动岛遮挡
        let topInset = self.view.safeAreaInsets.top
 
        pageContent.view.frame = CGRect(
            origin: CGPoint(x: frame.origin.x, y: frame.origin.y + topInset),
            size: CGSize(width: frame.size.width, height: frame.size.height - topInset))
 
        // Apply Zen Temple Serenity design enhancement
        enhancePageViewController(pageContent)
 
        return pageContent
    }
 
    // Apply Zen design enhancements to the page content
    private func enhancePageViewController(_ pageVC: SutraPageContentViewController) {
        // Apply semantic sutra background for page and table
        let backgroundColor = SutraDesignTokens.shared.color(for: .background) // 沉浸无缝，与内容同色
        pageVC.view.backgroundColor = backgroundColor
        pageVC.tableView.backgroundColor = backgroundColor
 
        // Update fonts with unified SutraTypography design system
        // Uses golden ratio scaling, Chinese font optimization, and proper line heights
        pageVC.sutraFont = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        pageVC.comentFont = SutraTypographyManager.shared.uiFont(for: .commentary, weight: .regular)
        pageVC.indexFont = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex
        if (index == NSNotFound || index + 1 == Book.shared.index?.count)
        {
            return nil;
        }
 
        // 始终跳过非叶子节点（目录页），只翻到有经文的页面
        let totalCount = Book.shared.index?.count ?? 0
        repeat {
            index += 1;
            guard index < totalCount else { return nil }
        } while !(Book.shared.isItemLeaf(index) ?? true)
        return getViewControllerAtIndex(index: index)
    }
    
    // MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        // 🌿 在开始翻页过渡手势的瞬间，立刻检查并锁定导航栏隐藏状态，防止划动过程中系统自动拉起导航栏
        let isHidden = self.navigationController?.isNavigationBarHidden ?? false
        if isHidden {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){
        // 🌿 无论翻页成功还是取消，只要之前处于隐藏状态，就必须在翻页结束时强制重新隐藏，彻底堵死各种手势中断/边界回弹带来的跳出问题
        let isHidden = self.navigationController?.isNavigationBarHidden ?? false
        if isHidden {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
        }

        if completed {
            guard let pageContent = pageViewController.viewControllers?.first as? SutraPageContentViewController else { return }
            self.page = pageContent.pageIndex;
            // 边界守卫：防止 page 越界
            guard let indexArr = Book.shared.index, page >= 0, page < indexArr.count else { return }
            self.item = indexArr[page];
            self.path = item?["path"]
            self.setPageTitle()
            self.setTitle()

            // 🌿 再次强制恢复隐藏状态，防止 layout 被系统强制刷回显示
            if isHidden {
                self.navigationController?.setNavigationBarHidden(true, animated: false)
            }

            // 每次翻页完成即保存进度
            recordCurrentReading()
        }
    }
    
    func setPageTitle() {
        self.navigationItem.titleView = Book.shared.getTitleView(item!)
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc func toggleNavigationBar() {
        if isEmbedded { return } // 🌿 嵌套状态下由 SwiftUI 接管头部，不响应轻点切换导航栏
        guard let navController = self.navigationController else { return }
        let isHidden = navController.isNavigationBarHidden
        navController.setNavigationBarHidden(!isHidden, animated: true)
        
        UIView.animate(withDuration: 0.2) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
}
