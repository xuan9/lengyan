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
    var onDismiss: ((Void) -> Void)?
    var page:Int = 0
    
    var path:String?
    var item:[String:String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge();
        self.extendedLayoutIncludesOpaqueBars = false;
        self.automaticallyAdjustsScrollViewInsets = false;
        
        if page < 0 {
            self.close()
        }
        
        item = Book.data.index![page]
        self.path = item!["path"];
        
        self.setPageTitle()
        self.dataSource = self;
        self.delegate = self;
        sutraStoryBoard = UIStoryboard(name: "SutraStoryboard", bundle: nil)
        
        self.setViewControllers([getViewControllerAtIndex(page)] as [UIViewController], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)
        
        self.setTitle()
    }
    
    func like() {
        Data.shared.like(self.path!)
        self.setTitle()
    }
    
    func unlike() {
        Data.shared.unlike(self.path!)
        self.setTitle()
    }
    
    func close() {
        onDismiss?();
        self.navigationController?.dismiss(animated: true, completion: {
            
        })
    }
    
    func setTitle() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"❬", style: .plain, target: self, action: #selector(SutraIndexViewController.close))
        
        //        if(Data.shared.likes.contains(path!)){
        //            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"★", style: .Plain, target: self, action: #selector(SutraPageViewController.unlike))
        //        } else {
        //            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"☆", style: .Plain, target: self, action: #selector(SutraPageViewController.like))
        //        }
        //        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.blackColor()
        //        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.blackColor()
        self.navigationController?.navigationBar.isTranslucent = false;
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let pageContent:SutraPurePageContentViewController = self.sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPurePageContentViewController") as! SutraPurePageContentViewController

        var index = pageContent.getBeforePageIndex()
        if ((index == 0) || (index == NSNotFound))
        {
            self.close();
            return nil;
        }
        index -= 1;
        return getViewControllerAtIndex(index)
    }
    
    func getViewControllerAtIndex(_ index: Int) -> UIViewController
    {
        
        let pageContent:SutraPurePageContentViewController = self.sutraStoryBoard!.instantiateViewController(withIdentifier: "SutraPurePageContentViewController") as! SutraPurePageContentViewController
        
        pageContent.pageIndex = index
        
        let frame = self.view.frame;
        let navigationBarHeight = (self.navigationController?.navigationBar.frame.size.height)!;
        
        pageContent.view.frame = CGRect(
            origin: CGPoint(x:frame.origin.x,y:frame.origin.y + navigationBarHeight),
            size:   CGSize(width: frame.size.width, height:frame.size.height - navigationBarHeight))
        
        return pageContent
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let pageContent: SutraPurePageContentViewController = viewController as! SutraPurePageContentViewController
        var index = pageContent.getNextPageIndex()
        if (index == NSNotFound || index  == Book.data.index?.count)
        {
            self.close();
            return nil;
        }
        index += 1;
        
        return getViewControllerAtIndex(index)
    }
    // MARK - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool){
        
        let pageContent = pageViewController.viewControllers![0] as! SutraPage
        self.page = pageContent.pageIndex;
        self.item = Book.data.index![page];
        self.path = item!["path"] ;
        
        self.setPageTitle()
    }
    
    func setPageTitle() {
        //        let children = Book.data.itemOfPath(item["path"] as! String)["children"] as? NSArray
        let title:String = (item!["name"] ?? "")
        
        // (item["id"] as! String) + " " +
        let parent = Book.data.parentOfItem(item! as [String : AnyObject]);
        let parentTitle = parent?["name"] as? String ?? ""
        //        let titleAttributes = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline), NSForegroundColorAttributeName: UIColor.purpleColor()]
        
        let font:UIFont? = UIFont(name: "Arial", size: 12.0)
        let attrString = NSMutableAttributedString(
            string: parentTitle as String,
            attributes: [NSFontAttributeName: font!])
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center;
        
        let font2:UIFont? = UIFont(name: "Arial", size: 10.0)
        let attrString2 = NSMutableAttributedString(
            string: parent == nil ? "" : " 之",
            attributes: [NSFontAttributeName: font2!]);
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString1 = NSMutableAttributedString(
            string: "\n" + title as String,
            attributes: [NSFontAttributeName: font1!,     NSParagraphStyleAttributeName : paragraphStyle]);
        
        attrString.append(attrString2)
        attrString.append(attrString1)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 400, height: 44))
        label.backgroundColor = UIColor.clear
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.left
        label.attributedText = attrString;
        label.isUserInteractionEnabled = true
        self.navigationItem.titleView = label
        
        //        let recognizer = UITapGestureRecognizer(target: self, action: Selector("titleWasTapped"))
        //        self.navigationItem.titleView!.addGestureRecognizer(recognizer)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
