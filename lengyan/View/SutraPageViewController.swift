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
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        
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
    
    func setTitle() {
        // Use modern SF Symbols for better accessibility and consistency
        let backIcon = UIImage(systemName: "chevron.left")
        let backBarButton = UIBarButtonItem(image: backIcon, style: .plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem = backBarButton

        if(Prefers.shared.likes.contains(path!)){
            let bookmarkIcon = UIImage(systemName: "bookmark.fill")
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: bookmarkIcon, style: .plain, target: self, action: #selector(unlike))
        } else {
            let bookmarkIcon = UIImage(systemName: "bookmark")
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: bookmarkIcon, style: .plain, target: self, action: #selector(like))
        }

        // Apply sutra design system colors for a calm, ink-on-paper feel
        let primaryTextColor = SutraDesignTokens.shared.color(for: .sutraText)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)

        self.navigationItem.leftBarButtonItem?.tintColor = primaryTextColor
        self.navigationItem.rightBarButtonItem?.tintColor = Prefers.shared.likes.contains(path!) ? bookmarkColor : secondaryTextColor
        self.navigationController?.navigationBar.backgroundColor = backgroundColor
        self.navigationController?.navigationBar.isTranslucent = false;
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
        if (self.navigationController?.isNavigationBarHidden ?? false){
            //skip the index pages if nav hiden
            repeat{
                index -= 1;
            } while (!(Book.shared.isItemLeaf(index) ?? true))
        } else {
            index -= 1;
        }
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
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
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
        
        if (self.navigationController?.isNavigationBarHidden ?? false){
            //skip the index pages if nav hiden
            repeat{
                index += 1;
            } while (!(Book.shared.isItemLeaf(index) ?? true))
        } else {
            index += 1;
        }
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
        if  self.navigationItem.titleView is UILabel {
                (self.navigationItem.titleView as! UILabel).attributedText = Book.shared.getTitle(item!)
        } else {
                self.navigationItem.titleView = Book.shared.getTitleView(item!);
        }
    }
}
