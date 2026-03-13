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
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    
    @objc func close() {
        onDismiss?();
        self.navigationController?.popViewController(animated: true);
    }
    
    func setTitle() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        self.navigationItem.leftBarButtonItem?.tintColor = SutraDesignTokens.shared.color(for: .textPrimary)
        self.navigationController?.navigationBar.isTranslucent = false;
        self.setPageTitle()
        self.updateStarButton();
    }
    
    func updateStarButton(){
        var likeButton: UIBarButtonItem
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)

        if Prefers.shared.likes.contains(path!) {
            likeButton = UIBarButtonItem(
                image: UIImage(systemName: "bookmark.fill"),
                style: .plain,
                target: self,
                action: #selector(unlike)
            )
            likeButton.tintColor = bookmarkColor  // 鎏金色
        } else {
            likeButton = UIBarButtonItem(
                image: UIImage(systemName: "bookmark"),
                style: .plain,
                target: self,
                action: #selector(like)
            )
            likeButton.tintColor = secondaryColor
        }
        
        if self.isShowIndexButton  {
            let item = Book.shared.itemOfPath(self.path!)
            if(item["children"] != nil ){
                let indexButton = UIBarButtonItem(
                    image: UIImage(systemName: "list.bullet.rectangle"),
                    style: .plain,
                    target: self,
                    action: #selector(openIndex)
                )
                indexButton.tintColor = SutraDesignTokens.shared.color(for: .textPrimary)
                self.navigationItem.setRightBarButtonItems([indexButton, likeButton], animated: false)
            } else {
                self.navigationItem.setRightBarButtonItems([likeButton], animated: false)
            }
        } else {
            self.navigationItem.setRightBarButtonItems([likeButton], animated: false)
        }
    }

    @objc func openIndex(){
        let indexVC = SutraIndexViewController();
        indexVC.tree = Book.shared.itemOfPath(path!);
        indexVC.defaultExpandLevel = 2;
        indexVC.isShowSutraButton = false;
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
    }
    
    func setPageTitle() {
        if path == nil { return }
        let item = Book.shared.itemOfPath(path!);
        if self.navigationItem.titleView is UILabel {
            (self.navigationItem.titleView as! UILabel).attributedText = Book.shared.getTitle(item)
        } else {
            self.navigationItem.titleView = Book.shared.getTitleView(item);
        }
    }
    
}
