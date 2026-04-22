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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.edgesForExtendedLayout = UIRectEdge();
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        

        self.dataSource = self;
        self.delegate = self;
        // STORYBOARD REMOVED: Using programmatic UI now
        
        self.setViewControllers([getViewControllerAtPath(self.path!)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)

        self.setTitle()

        // 打开即保存初始页面进度
        Prefers.shared.lastReadPath = self.path
        Prefers.shared.lastReadMode = "tree"
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        if let path = self.path {
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
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        self.navigationItem.leftBarButtonItem?.tintColor = secondaryColor
        self.navigationItem.leftBarButtonItem?.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)

        // 导航栏背景统一
        let navBarColor = SutraDesignTokens.shared.color(for: .background)
        self.navigationController?.navigationBar.barTintColor = navBarColor
        self.navigationController?.navigationBar.backgroundColor = navBarColor
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)

        // 设置 UINavigationBarAppearance — 透明背景，按钮无色块
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = navBarColor
        appearance.shadowColor = .clear
        self.navigationController?.navigationBar.standardAppearance = appearance
        self.navigationController?.navigationBar.compactAppearance = appearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appearance

        self.setPageTitle()
        self.updateStarButton()
    }

    func updateStarButton(){
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)

        // 收藏按钮
        let isLiked = Prefers.shared.likes.contains(path!)
        let likeButton = UIBarButtonItem(
            image: UIImage(systemName: isLiked ? "bookmark.fill" : "bookmark"),
            style: .plain,
            target: self,
            action: isLiked ? #selector(unlike) : #selector(like)
        )
        likeButton.tintColor = isLiked ? bookmarkColor : secondaryColor
        likeButton.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)

        // 分享按钮
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
        shareButton.tintColor = secondaryColor
        shareButton.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)

        if self.isShowIndexButton {
            let item = Book.shared.itemOfPath(self.path!)
            if item["children"] != nil {
                let indexButton = UIBarButtonItem(
                    image: UIImage(systemName: "list.bullet"),
                    style: .plain,
                    target: self,
                    action: #selector(openIndex)
                )
                indexButton.tintColor = secondaryColor
                indexButton.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
                self.navigationItem.setRightBarButtonItems([indexButton, shareButton, likeButton], animated: false)
            } else {
                self.navigationItem.setRightBarButtonItems([shareButton, likeButton], animated: false)
            }
        } else {
            self.navigationItem.setRightBarButtonItems([shareButton, likeButton], animated: false)
        }
    }

    @objc func share() {
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
        
        let frame = self.view.frame;
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;
        
        pageContent.view.frame = CGRect(
            origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))
        
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
