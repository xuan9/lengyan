//
//  SutraPageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    var sutraStoryBoard:UIStoryboard?;
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
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)
        
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
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:" ❬   ", style: .plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem?.setBackButtonBackgroundImage(UIImage.init(named: "ic_chevron_left_18pt"), for: .normal, barMetrics: .default)

        
        if(Prefers.shared.likes.contains(path!)){
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"★", style: .plain, target: self, action: #selector(unlike))
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"☆", style: .plain, target: self, action: #selector(like))
        }
        
        
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.darkText
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.darkText
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
        
        let pageContent:SutraPageContentViewController = self.sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPageContentViewController") as! SutraPageContentViewController
        
        pageContent.pageIndex = index
        
        let frame = self.view.frame;
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;
        
        pageContent.view.frame = CGRect(
            origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))
        
        return pageContent
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
