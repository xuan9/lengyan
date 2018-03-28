//
//  SutraPurePageViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/20.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    var sutraStoryBoard:UIStoryboard?;
    var onDismiss: (() -> Void)?
//    var page:Int = 0
    var path:String?
//    var item:[String:String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        self.edgesForExtendedLayout = UIRectEdge();
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        

        self.setPageTitle()
        self.dataSource = self;
        self.delegate = self;
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)
        
        self.setViewControllers([getViewControllerAtPath(self.path!)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)
        
        self.setTitle()
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    
    @objc func close() {
        onDismiss?();
        self.navigationController?.popViewController(animated: true);

//        self.navigationController?.dismiss(animated: true, completion: {})
    }
    
    func setTitle() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:" ❬  ", style: .plain, target: self, action: #selector(close))
    self.navigationItem.leftBarButtonItem?.setBackButtonBackgroundImage(UIImage.init(named: "ic_chevron_left_18pt"), for: .normal, barMetrics: .default)
        
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.darkText
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.darkText
        self.navigationController?.navigationBar.isTranslucent = false;
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        let path = pageContent.getPreviousPagePath()
        if (path == nil)
        {
            return nil;
        }
        return getViewControllerAtPath(path!)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        
        let path = pageContent.getNextPagePath()
        if (path == nil)
        {
            return nil;
        }
        return getViewControllerAtPath(path!)
    }
    
    func getViewControllerAtPath(_ path: String) -> UIViewController
    {
        
        let pageContent:SutraPurePageContentViewController = SutraPurePageContentViewController();
//        self.sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPurePageContentViewController") as! SutraPurePageContentViewController
        
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
        self.setPageTitle()
    }
    
    func setPageTitle() {
        if path == nil { return }
        let item = Book.data.itemOfPath(path!);
        if self.navigationItem.titleView is UILabel {
            (self.navigationItem.titleView as! UILabel).attributedText = Book.data.getTitle(item)
        } else {
            self.navigationItem.titleView = Book.data.getTitleView(item);
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
