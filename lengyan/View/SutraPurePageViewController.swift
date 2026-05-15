//
//  SutraPurePageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/20.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    // STORYBOARD REMOVED: Using programmatic UI now
    var onDismiss: (() -> Void)?
    var path:String?
    var _paths:[String] = [];
    var isShowIndexButton = true;
    private var stayTimer = ReadingStayTimer()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = false;
        self.navigationController?.hidesBarsOnTap = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.edgesForExtendedLayout = UIRectEdge();
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 底层背景与阅读内容同色，防止翻页时闪白

        self.dataSource = self;
        self.delegate = self;

        // STORYBOARD REMOVED: Using programmatic UI now
        
        self.setViewControllers([getViewControllerAtPath(self.path!)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)

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
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = true
        self.navigationController?.hidesBarsWhenVerticallyCompact = true
        // 显式重新启用手势识别器（防止被其他页面禁用）
        self.navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = false
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = true
        self.navigationController?.barHideOnTapGestureRecognizer.cancelsTouchesInView = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        self.navigationController?.hidesBarsOnTap = false
        if let path = self.path, stayTimer.isValidReading {
            Prefers.shared.lastReadPath = path
            Prefers.shared.lastReadMode = "tree"
        }
    }

    @objc func close() {
        onDismiss?();
        self.navigationController?.popViewController(animated: true);
    }
    
    func setTitle() {
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        // 返回按钮
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        backButton.tintColor = secondaryColor
        if #available(iOS 26.0, *) {
            backButton.hidesSharedBackground = true
        }

        // 目录按钮移到左边
        var leftButtons: [UIBarButtonItem] = [backButton]
        if self.isShowIndexButton {
            let item = Book.shared.itemOfPath(path ?? "")
            if item["children"] != nil {
                let indexButton = UIBarButtonItem(
                    image: UIImage(systemName: "list.bullet"),
                    style: .plain,
                    target: self,
                    action: #selector(openIndex)
                )
                indexButton.tintColor = secondaryColor
                if #available(iOS 26.0, *) {
                    indexButton.hidesSharedBackground = true
                }
                leftButtons.append(indexButton)
            }
        }
        self.navigationItem.leftBarButtonItems = leftButtons

        // 导航栏背景统一 — 与阅读内容同色，按钮完全无背景色块
        let navBarColor = SutraDesignTokens.shared.color(for: .background)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = navBarColor
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
        // 隐藏默认返回按钮指示器
        appearance.setBackIndicatorImage(UIImage(), transitionMaskImage: UIImage())
        
        if let navBar = self.navigationController?.navigationBar {
            navBar.standardAppearance = appearance
            navBar.compactAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.isTranslucent = false
            navBar.tintColor = secondaryColor
            // 清除导航栏的背景视图层级中的模糊效果
            navBar.setBackgroundImage(UIImage(), for: .default)
            navBar.shadowImage = UIImage()
            navBar.barTintColor = navBarColor
            navBar.backgroundColor = navBarColor
        }

        self.setPageTitle()
        self.updateStarButton()
    }

    func updateStarButton(){
        guard let path = self.path else { return }
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        // 收藏按钮
        let isLiked = Prefers.shared.likes.contains(path)
        let likeButton = UIBarButtonItem(
            image: UIImage(systemName: isLiked ? "bookmark.fill" : "bookmark"),
            style: .plain,
            target: self,
            action: isLiked ? #selector(unlike) : #selector(like)
        )
        likeButton.tintColor = isLiked ? bookmarkColor : secondaryColor

        if #available(iOS 26.0, *) {
            likeButton.hidesSharedBackground = true
        }

        // 右边统一：[分享] [收藏]
        let rightButtons: [UIBarButtonItem] = [makeShareButton(color: secondaryColor), likeButton]

        self.navigationItem.setRightBarButtonItems(rightButtons, animated: false)
    }

    private func makeShareButton(color: UIColor) -> UIBarButtonItem {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
        button.tintColor = color
        if #available(iOS 26.0, *) {
            button.hidesSharedBackground = true
        }
        return button
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

    @objc func openIndex(){
        let indexVC = SutraIndexViewController();
        indexVC.tree = Book.shared.itemOfPath(path!);
        indexVC.defaultExpandLevel = 2;
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    @objc func like() {
        Prefers.shared.like(self.path!)
        self.updateStarButton()
    }
    
    @objc func unlike() {
        Prefers.shared.unlike(self.path!)
        self.updateStarButton()
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        
        if pageContent.path == nil { return nil}
        var previousPath:String?
        let index = _paths.index(of: pageContent.path!)
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
        let index = _paths.index(of: pageContent.path!)
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
        
        pageContent.view.frame = self.view.bounds
        
        return pageContent
    }
    
    // MARK - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){

        let pageContent = pageViewController.viewControllers![0] as! SutraPurePageContentViewController
        self.path = pageContent.path;
        self.setTitle()

        // 每次翻页完成即保存进度
        if let path = self.path {
            Prefers.shared.lastReadPath = path
            Prefers.shared.lastReadMode = "tree"
        }
    }
    
    func setPageTitle() {
        if path == nil { return }
        let item = Book.shared.itemOfPath(path!);
        self.navigationItem.titleView = Book.shared.getTitleView(item);
    }

}
