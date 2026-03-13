//
//  SutraChapterPageViewController
//  lengyan
//
//  Created by Xuan on 16/7/20.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraChapterPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate{
    // STORYBOARD REMOVED: Using programmatic UI now
    var onDismiss: (() -> Void)?
    var pageIndex:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Modern navigation bar behavior with design system
        if let navigationBar = self.navigationController?.navigationBar {
            // These properties are deprecated in iOS 16+, use scrollEdgeAppearance instead
            navigationBar.prefersLargeTitles = false
        }

        setPageTitle()
        self.dataSource = self
        self.delegate = self
        
        if let initialViewController = getViewControllerAtPage(self.pageIndex) as? UIViewController {
            self.setViewControllers([initialViewController], direction: .forward, animated: false)
        }
        
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
        // SF Symbol 返回按钮
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )

        self.navigationItem.leftBarButtonItem = closeButton

        // Apply theme colors
        let primaryColor: UIColor = SutraDesignTokens.shared.color(for: .textPrimary)
        self.navigationItem.leftBarButtonItem?.tintColor = primaryColor
        self.navigationItem.rightBarButtonItem?.tintColor = primaryColor

        // Modern navigation bar styling
        if let navigationBar = self.navigationController?.navigationBar {
            navigationBar.isTranslucent = false
        }
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
