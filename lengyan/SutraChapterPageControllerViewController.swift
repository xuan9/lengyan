//
//  SutraChapterPageViewController
//  lengyan
//
//  Created by Xuan on 16/7/20.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraChapterPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    var sutraStoryBoard:UIStoryboard?;
    var onDismiss: (() -> Void)?
    var pageIndex:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        
//        self.edgesForExtendedLayout = UIRectEdge();
//        self.extendedLayoutIncludesOpaqueBars = false;
//        self.automaticallyAdjustsScrollViewInsets = true;
        
        
        self.setPageTitle()
        self.dataSource = self;
        self.delegate = self;
        
        self.setViewControllers(([getViewControllerAtPage(self.pageIndex)] as! [UIViewController]), direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)
        
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
        let pageContent: SutraChapterContentViewController = viewController as! SutraChapterContentViewController
        let page = pageContent.pageIndex;
        var previousPage:Int?
        if page > 0 {
            previousPage = page - 1;
        }
        return getViewControllerAtPage(previousPage)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraChapterContentViewController = viewController as! SutraChapterContentViewController
        let page = pageContent.pageIndex;
        var nextPage:Int?
        if page < 9  {
            nextPage = page + 1;
        }
        return getViewControllerAtPage(nextPage)
    }
    
    func getViewControllerAtPage(_ page: Int?) -> UIViewController?
    {
        if page == nil { return nil;}
        let pageContent:SutraChapterContentViewController = SutraChapterContentViewController();
        pageContent.pageIndex = page!
        
        let frame = self.view.frame;
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;
        
        pageContent.view.frame = CGRect(
            origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))
        
        return pageContent
    }
    
    // MARK - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){
        let pageContent = pageViewController.viewControllers![0] as! SutraChapterContentViewController
        self.pageIndex = pageContent.pageIndex;
        self.setPageTitle()
    }
    
    func setPageTitle() {
        self.navigationItem.title = NSLocalizedString("chapter_\(self.pageIndex + 1)", comment: "chapter_name")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
