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
    var onDismiss: (Void -> Void)?
    var page:Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = .None;
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "X", style: .Plain, target: self, action: #selector(SutraPageViewController.close))
        self.navigationController?.navigationBar.translucent = false;
 
        if page < 0 {
            self.close()
        }
        
        let item = Book.data.index![page]
        self.setPageTitle(item as NSDictionary)
        self.dataSource = self;
        self.delegate = self;
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)

        self.setViewControllers([getViewControllerAtIndex(page)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
        
    }
    
    func close() {
        onDismiss?();
        self.navigationController?.dismissViewControllerAnimated(true, completion: { 
            
        })
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController?
    {
        let pageContent:  SutraPage = viewController as!  SutraPage
        var index = pageContent.pageIndex
        if ((index == 0) || (index == NSNotFound))
        {
            self.close();
            return nil;
        }
        index -= 1;
        return getViewControllerAtIndex(index)
    }
    
    func getViewControllerAtIndex(index: Int) -> UIViewController
    {

        let pageContent:SutraPageContentViewController = self.sutraStoryBoard!.instantiateViewControllerWithIdentifier("SutraPageContentViewController") as! SutraPageContentViewController
        
        pageContent.pageIndex = index
        
        let frame = self.view.frame;
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;
        
       pageContent.view.frame = CGRect(
        origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))
        
        return pageContent
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPage = viewController as! SutraPage
        var index = pageContent.pageIndex
        if (index == NSNotFound || index + 1 == Book.data.index?.count)
        {
            self.close();
            return nil;
        }
        index += 1;

        return getViewControllerAtIndex(index)
    }
    // MARK - UIPageViewControllerDelegate
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){
        
        let pageContent = pageViewController.viewControllers![0] as! SutraPage
        self.page = pageContent.pageIndex;
        self.setPageTitle(Book.data.index![page] as NSDictionary)
    }
    
    func setPageTitle(item:NSDictionary) {
//        let children = Book.data.itemOfPath(item["path"] as! String)["children"] as? NSArray
        let title:String = (item["name"] as? String ?? "")
        
        // (item["id"] as! String) + " " +
        let parent = Book.data.parentOfItem(item as! [String : AnyObject]);
        let parentTitle = (parent?["name"] as! String)  ;
//        let titleAttributes = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline), NSForegroundColorAttributeName: UIColor.purpleColor()]
        
        let font:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString = NSMutableAttributedString(
            string: parentTitle as String,
            attributes: [NSFontAttributeName: font!])
      
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center;
        
        let font2:UIFont? = UIFont(name: "Arial", size: 11.0)
        let attrString2 = NSMutableAttributedString(
            string: " 之" as String,
            attributes: [NSFontAttributeName: font2!]);
        
        let font1:UIFont? = UIFont(name: "Arial", size: 17.0)
        let attrString1 = NSMutableAttributedString(
            string: "\n" + title as String,
            attributes: [NSFontAttributeName: font1!,     NSParagraphStyleAttributeName : paragraphStyle]);
        
        attrString.appendAttributedString(attrString2)
        attrString.appendAttributedString(attrString1)
        let label = UILabel(frame: CGRectMake(0, 0, 400, 44))
        label.backgroundColor = UIColor.clearColor()
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.Left
        label.attributedText = attrString;
        self.navigationItem.titleView = label
    }
    
    // MARK: - view controller functions overwrites
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
