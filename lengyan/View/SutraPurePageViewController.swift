//
//  SutraPurePageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/20.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit
import Combine

class SutraPurePageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, NavigationPopAware{
    // STORYBOARD REMOVED: Using programmatic UI now
    var onDismiss: (() -> Void)?
    var path:String?
    var _paths:[String] = [];
    var isShowIndexButton = true;
    private let readingCheckpoint = ReadingCheckpointGate()
    private var isReaderVisible = false
    var isEmbedded = false


    
    private var backButton: UIBarButtonItem?
    private var indexButton: UIBarButtonItem?
    private var shareButton: UIBarButtonItem?
    private var bookmarkButton: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "reader.tree"
        setupApplicationLifecycleObservers()
        self.navigationController?.hidesBarsOnSwipe = false;
        self.navigationController?.hidesBarsOnTap = false;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 底层背景与阅读内容同色，防止翻页时闪白

        self.dataSource = self;
        self.delegate = self;

        self.setViewControllers([getViewControllerAtPath(self.path!)] as [UIViewController], direction: UIPageViewController.NavigationDirection.forward, animated: false, completion: nil)

        setupNavigationItems()
        updateNavigationBarState()
        setupThemeObserver()
    }

    func updatePath(to newPath: String) {
        guard !newPath.isEmpty else { return }
        self.path = newPath
        self.setViewControllers([getViewControllerAtPath(newPath)] as [UIViewController], direction: .forward, animated: false, completion: nil)
        updateNavigationBarState()
        
        // Programmatic target changes are explicit navigation requests.
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

        // 恢复并统一导航栏外观
        applyNavigationBarAppearance()
        updateNavigationBarState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prioritizeInteractivePopGesture()
        isReaderVisible = true
        resumeReadingCheckpointIfNeeded()
    }

    private func prioritizeInteractivePopGesture() {
        guard let popGesture = navigationController?.interactivePopGestureRecognizer else { return }
        view.subviews
            .compactMap { $0 as? UIScrollView }
            .forEach { $0.panGestureRecognizer.require(toFail: popGesture) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Prepare the destination only when navigation is actually starting,
        // keeping ordinary page turns as light as before.
        synchronizeExistingOutline()
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
        guard let path = self.path, !path.isEmpty else { return }
        Prefers.shared.recordTreeReading(path: path)
    }

    private func synchronizeExistingOutline() {
        guard let path,
              let index = navigationController?.viewControllers.last(where: {
                  $0 is SutraIndexViewController
              }) as? SutraIndexViewController else { return }
        index.prepareToRevealPath(path)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func close() {
        print("DEBUG: SutraPurePageViewController close() - Stack before pop: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
        let popped = self.navigationController?.popViewController(animated: true);
        print("DEBUG: SutraPurePageViewController close() - Popped VC: \(String(describing: popped)), Stack after pop: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
    }

    func navigationControllerDidPop() {
        onDismiss?()
    }

    private func setupNavigationItems() {
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)

        // 1. 返回按钮
        let backBtn = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        backBtn.tintColor = secondaryColor
        backBtn.accessibilityIdentifier = "reader.backButton"
        if #available(iOS 26.0, *) {
            backBtn.hidesSharedBackground = true
        }
        self.backButton = backBtn

        // 2. 目录按钮（是否显示由当前节点是否还有子科判动态决定）
        if self.isShowIndexButton {
            let indexBtn = UIBarButtonItem(
                image: UIImage(systemName: "list.bullet"),
                style: .plain,
                target: self,
                action: #selector(openIndex)
            )
            indexBtn.tintColor = secondaryColor
            indexBtn.accessibilityIdentifier = "reader.outlineButton"
            indexBtn.accessibilityLabel = L10n.str("home_outline_button")
            if #available(iOS 26.0, *) {
                indexBtn.hidesSharedBackground = true
            }
            self.indexButton = indexBtn
        }

        // 3. 分享按钮
        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
        shareBtn.tintColor = secondaryColor
        if #available(iOS 26.0, *) {
            shareBtn.hidesSharedBackground = true
        }
        self.shareButton = shareBtn

        // 4. 收藏按钮 (初始状态)
        let bookmarkBtn = UIBarButtonItem(
            image: UIImage(systemName: "bookmark"),
            style: .plain,
            target: self,
            action: #selector(like)
        )
        bookmarkBtn.tintColor = secondaryColor
        if #available(iOS 26.0, *) {
            bookmarkBtn.hidesSharedBackground = true
        }
        self.bookmarkButton = bookmarkBtn

        // 仅装配右侧按钮，左侧返回/目录装配移至 updateNavigationBarState() 进行动态显隐管理
        self.navigationItem.rightBarButtonItems = [shareBtn, bookmarkBtn]

        applyNavigationBarAppearance()
    }

    private func applyNavigationBarAppearance() {
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let navBarColor = SutraDesignTokens.shared.color(for: .background)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = navBarColor
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

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
            navBar.barTintColor = navBarColor
            navBar.backgroundColor = navBarColor
        }
    }

    func updateNavigationBarState() {
        guard let path = self.path else { return }
        // 🌿 记录当前真实的隐藏状态，避免更新 items 触发重新布局而意外显示导航条
        let isHidden = self.navigationController?.isNavigationBarHidden ?? false
        
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        // 🌿 更新经文标题
        let item = Book.shared.itemOfPath(path)
        self.navigationItem.titleView = Book.shared.getTitleView(item)

        // 叶子正文已是科判尽头，只保留返回，避免出现无意义的重复入口。
        let isLeaf = item["children"] == nil
        var leftButtons = (isEmbedded ? [] : [backButton]).compactMap { $0 }
        if self.isShowIndexButton && !isLeaf {
            if let indexBtn = self.indexButton {
                leftButtons.append(indexBtn)
            }
        }
        self.navigationItem.leftBarButtonItems = leftButtons

        // 🌿 更新收藏状态 (直接修改同一按钮，杜绝闪烁)
        let isLiked = Prefers.shared.isLike(path)
        bookmarkButton?.image = UIImage(systemName: isLiked ? "bookmark.fill" : "bookmark")
        bookmarkButton?.tintColor = isLiked ? bookmarkColor : secondaryColor
        bookmarkButton?.target = self
        bookmarkButton?.action = isLiked ? #selector(unlike) : #selector(like)
        
        // 🌿 强制恢复隐藏状态，防止 layout 被系统强制刷回显示
        if isHidden {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
        }
    }

    // MARK: - 主题即时刷新支持
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            self.applyNavigationBarAppearance()
            self.updateNavigationBarState()
        }, completion: nil)
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

    @objc func openIndex(){
        if let viewControllers = self.navigationController?.viewControllers {
            if let existingIndexVC = viewControllers.last(where: { $0 is SutraIndexViewController }) as? SutraIndexViewController {
                existingIndexVC.prepareToRevealPath(
                    self.path ?? "",
                    expandingOneAdditionalLevel: true
                )
                self.navigationController?.popToViewController(existingIndexVC, animated: true)
                return
            }
        }
        
        let indexVC = SutraIndexViewController();
        indexVC.tree = Book.shared.itemOfPath(path!);
        indexVC.path = self.path
        indexVC.defaultExpandLevel = 2;
        indexVC.expandsOneAdditionalLevelOnLoad = true
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    @objc func like() {
        HapticManager.shared.bookmarkToggle()
        Prefers.shared.like(self.path!)
        self.updateNavigationBarState()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
    
    @objc func unlike() {
        HapticManager.shared.bookmarkToggle()
        Prefers.shared.unlike(self.path!)
        self.updateNavigationBarState()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        
        if pageContent.path == nil { return nil}
        var previousPath:String?
        let index = _paths.firstIndex(of: pageContent.path!)
        if index != nil && index! > 0 {
            previousPath = _paths[index! - 1]//found from cache
        } else {
            previousPath = Book.shared.getPreviousPagePath(pageContent.path)
            if index == nil {
                _paths.append(pageContent.path!)
            }
            if previousPath != nil {//cache it
                _paths.insert(previousPath!, at: 0);
            }
        }
        if (previousPath == nil)
        {
            return nil;
        }
        return getViewControllerAtPath(previousPath!)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        if pageContent.path == nil { return nil}
        let index = _paths.firstIndex(of: pageContent.path!)
        var nextPath:String?;
        if index != nil && index! < _paths.count - 1 {
            nextPath = _paths[index! + 1]//found from cache
        } else {
            nextPath = Book.shared.getNextPagePath(pageContent.path)
            if index == nil {
                _paths.append(pageContent.path!)
            }
            if nextPath != nil {//cache it
                _paths.append(nextPath!)
            }
        }
        if (nextPath == nil)
        {
            return nil;
        }
        return getViewControllerAtPath(nextPath!)
    }
    
    func getViewControllerAtPath(_ path: String) -> UIViewController
    {
        let pageContent:SutraPurePageContentViewController = SutraPurePageContentViewController();
        pageContent.path = path
        pageContent.parentReader = self // 🌿 绑定父控制器引用，实现精确的导航栏状态同步
        pageContent.view.frame = self.view.bounds
        return pageContent
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
            let pageContent = pageViewController.viewControllers![0] as! SutraPurePageContentViewController
            self.path = pageContent.path;
            self.updateNavigationBarState()

            // 每次翻页完成即保存进度
            recordCurrentReading()
        }
    }
}
