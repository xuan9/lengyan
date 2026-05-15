//
//  SutraPageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    // STORYBOARD REMOVED: Using programmatic UI now
    var onDismiss: (() -> Void)?
    private var stayTimer = ReadingStayTimer()
    var page:Int = 0

    var path:String?
    var item:[String:String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsOnTap = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.automaticallyAdjustsScrollViewInsets = false;
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
        }
        
        item = Book.shared.index![page]
        self.path = item!["path"]
        
        self.setPageTitle()
        self.dataSource = self;
        self.delegate = self;

        // STORYBOARD REMOVED: Using programmatic UI now
        self.setViewControllers([getViewControllerAtIndex(index: page)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)

        self.setTitle()
    }

    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        stayTimer.start()
        self.tabBarController?.tabBar.isHidden = true
        // 每次出现时重新启用滑动隐藏，因为首页 viewWillAppear 会将其重置为 false
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = true
        self.navigationController?.hidesBarsOnTap = true
        self.navigationController?.hidesBarsWhenVerticallyCompact = true
        // 显式重新启用手势识别器（防止被其他页面禁用）
        self.navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = true
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = true
        self.navigationController?.barHideOnTapGestureRecognizer.cancelsTouchesInView = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        self.navigationController?.hidesBarsOnTap = false
        // 保存阅读进度（停留超过10秒才视为有效阅读）
        if let path = self.path, page >= 0, stayTimer.isValidReading {
            Prefers.shared.lastReadPath = path
            Prefers.shared.lastReadPageIndex = page
            Prefers.shared.lastReadMode = "paged"
        }
    }
    
    @objc func like() {
        Prefers.shared.like(self.path!)
        self.setTitle()
    }
    
    @objc func unlike() {
        Prefers.shared.unlike(self.path!)
        self.setTitle()
    }
    
    @objc func close() {
        self.onDismiss?()
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func share() {
        guard let path = self.path else { return }
        let item = Book.shared.itemOfPath(path)
        let bookTitle = NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》")

        // 获取经文和来源
        let sutraText = Book.shared.getSutra(item, maxLength: 40)
        let name = item["name"] as? String ?? ""
        let source = name.isEmpty ? bookTitle : "\(bookTitle) · \(name)"

        // 零摩擦分享：默认竖版美图卡片
        SutraCardRenderer.shareCard(
            text: sutraText,
            source: source,
            from: self,
            barButtonItem: self.navigationItem.rightBarButtonItems?.first
        )
    }
    
    func setTitle() {
        // Use modern SF Symbols for better accessibility and consistency
        let backIcon = UIImage(systemName: "chevron.left")
        let backBarButton = UIBarButtonItem(image: backIcon, style: .plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem = backBarButton

        // Right side: Bookmark + Share (禅意极简排列)
        let shareIcon = UIImage(systemName: "square.and.arrow.up")
        let shareButton = UIBarButtonItem(image: shareIcon, style: .plain, target: self, action: #selector(share))

        let isLiked = Prefers.shared.likes.contains(path!)
        let bookmarkIcon = UIImage(systemName: isLiked ? "bookmark.fill" : "bookmark")
        let bookmarkButton = UIBarButtonItem(image: bookmarkIcon, style: .plain, target: self, action: isLiked ? #selector(unlike) : #selector(like))

        // 按钮颜色
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        self.navigationItem.leftBarButtonItem?.tintColor = secondaryTextColor
        shareButton.tintColor = secondaryTextColor
        bookmarkButton.tintColor = isLiked ? bookmarkColor : secondaryTextColor

        // 移除 iOS 26 Liquid Glass 按钮背景，与导航栏完全融合
        if #available(iOS 26.0, *) {
            backBarButton.hidesSharedBackground = true
            shareButton.hidesSharedBackground = true
            bookmarkButton.hidesSharedBackground = true
        }

        // Grouping right buttons: [Share on the far right] [Bookmark]
        self.navigationItem.rightBarButtonItems = [shareButton, bookmarkButton]
    }
        
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent:  SutraPage = viewController as!  SutraPage
        var index = pageContent.pageIndex
        if ((index == 0) || (index == NSNotFound))
        {
            self.close();
            return nil;
        }
        // 始终跳过非叶子节点（目录页），只翻到有经文的页面
        repeat {
            index -= 1;
            guard index >= 0 else { self.close(); return nil }
        } while !(Book.shared.isItemLeaf(index) ?? true)
        return getViewControllerAtIndex(index: index)
    }
    
    func getViewControllerAtIndex(index: Int) -> UIViewController
    {
        // Create the standard page content controller and enhance it
        let pageContent = SutraPageContentViewController()

        pageContent.pageIndex = index

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
            self.close();
            return nil;
        }

        // 始终跳过非叶子节点（目录页），只翻到有经文的页面
        let totalCount = Book.shared.index?.count ?? 0
        repeat {
            index += 1;
            guard index < totalCount else { self.close(); return nil }
        } while !(Book.shared.isItemLeaf(index) ?? true)
        return getViewControllerAtIndex(index: index)
    }
    
    // MARK - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){

        let pageContent = pageViewController.viewControllers![0] as! SutraPage
        self.page = pageContent.pageIndex;
        self.item = Book.shared.index![page];
        self.path = item!["path"]
        self.setPageTitle()
        self.setTitle()

        // 每次翻页完成即保存进度
        if let path = self.path, page >= 0 {
            Prefers.shared.lastReadPath = path
            Prefers.shared.lastReadPageIndex = page
            Prefers.shared.lastReadMode = "paged"
        }
    }
    
    func setPageTitle() {
        self.navigationItem.titleView = Book.shared.getTitleView(item!)
    }
}
