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
    var page:Int = 0
    
    var path:String?
    var item:[String:String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.edgesForExtendedLayout = [];
        self.automaticallyAdjustsScrollViewInsets = false;
        self.view.backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar) // 翻页控制器底层背景色
        
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 保存阅读进度（仅在有效页面时）
        if let path = self.path, page >= 0 {
            Prefers.shared.lastReadPath = path
            Prefers.shared.lastReadPageIndex = page
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
        // Take a beautiful snapshot of the zen paper page for sharing
        UIGraphicsBeginImageContextWithOptions(self.view.frame.size, false, 0.0)
        self.view.layer.render(in: UIGraphicsGetCurrentContext()!)
        guard let img = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()
        
        let activityViewController = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItems?.last
        }
        self.present(activityViewController, animated: true, completion: nil)
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

        // Apply sutra design system colors for a calm, ink-on-paper feel
        let primaryTextColor = SutraDesignTokens.shared.color(for: .sutraText)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar) // Seamless scroll background

        self.navigationItem.leftBarButtonItem?.tintColor = primaryTextColor
        shareButton.tintColor = secondaryTextColor
        bookmarkButton.tintColor = isLiked ? bookmarkColor : secondaryTextColor

        // Grouping right buttons: [Share on the far right] [Bookmark]
        // Note: rightBarButtonItems renders from right to left (index 0 is rightmost)
        self.navigationItem.rightBarButtonItems = [shareButton, bookmarkButton]
        
        self.navigationController?.navigationBar.backgroundColor = backgroundColor
        self.navigationController?.navigationBar.isTranslucent = false
        // Remove standard hairline boundary to create seamless transition with content based purely on typography weight and whitespace
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
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
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;

        pageContent.view.frame = CGRect(
            origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))

        // Apply Zen Temple Serenity design enhancement
        enhancePageViewController(pageContent)

        return pageContent
    }

    // Apply Zen design enhancements to the page content
    private func enhancePageViewController(_ pageVC: SutraPageContentViewController) {
        // Apply semantic sutra background for page and table
        let backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar) // 无界宣纸沉浸色向下透传
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
    }
    
    func setPageTitle() {
        self.navigationItem.titleView = Book.shared.getTitleView(item!)
    }
}
