//
//  SutraFrontViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/2.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation
import UIKit

class SutraFrontViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    private var treeView: RATreeView!
    internal var tree:NSArray?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x  ,y:bounds.origin.y),
            size:   CGSize(width: bounds.size.width , height:bounds.size.height-(self.tabBarController?.tabBar.bounds.size.height ?? 0))));
        treeView.delegate = self
        treeView.dataSource = self
        treeView.backgroundColor = UIColor.whiteColor()
        view.backgroundColor = UIColor.whiteColor()
        treeView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(treeView)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SutraFrontViewController.longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        
        self.loadRootTree();
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(SutraIndexViewController.onApplicationWillTerminate),
            name: UIApplicationWillTerminateNotification,
            object: nil)
    }
    
    func loadRootTree(){
        Book.data.loadDataWithCompletionHandler { (Void) in
            var firstLevelItems=[[String:AnyObject]]();
            firstLevelItems.append(["name":"总科","header":true]);
            firstLevelItems.append(Book.data.itemOfPath("/A1"));
            firstLevelItems.append(Book.data.itemOfPath("/A2"));
            firstLevelItems.append(Book.data.itemOfPath("/A3"));
            firstLevelItems.append(["name":"精选","header":true]);
            firstLevelItems.append(Book.data.itemOfPath("/A2/B1"));
            firstLevelItems.append(Book.data.itemOfPath("/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M1"));
            firstLevelItems.append(Book.data.itemOfPath("/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M2"));
            self.tree = firstLevelItems;
            dispatch_async(dispatch_get_main_queue()){
                self.treeView.reloadData()
            }
        }
    }
    
    //Called, when long press occurred
    func longPress(longPressGestureRecognizer: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == UIGestureRecognizerState.Began {
            let touchPoint = longPressGestureRecognizer.locationInView(self.treeView.scrollView)
            if let item = treeView.itemForRowAtPoint(touchPoint) as? NSDictionary {
               openItem(item)
            }
        }
    }
    func openItem(item: NSDictionary){
        if(item["children"] == nil){
            openContent(item)
        } else {
            openIndex(item);
        }
    }
    
    func openContent(item: NSDictionary){
        let pageVC = SutraPageViewController.init( transitionStyle:.PageCurl,
                                                   navigationOrientation:.Horizontal,
                                                   options: .None)
        let path:String = item["path"] as! String
        pageVC.page=Book.data.index!.indexOf({ (
            item) -> Bool in
            return item["path"] == path
        })!;
        
        let navVC = UINavigationController.init(rootViewController: pageVC);
        
        self.presentViewController(navVC, animated: true, completion: {
            
        })
    }
    
    func openIndex(item: NSDictionary){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item;
        indexVC.defaultExpandLevel = 1;
        let navVC = UINavigationController.init(rootViewController: indexVC);
        
        self.presentViewController(navVC, animated: true, completion: {
            
        })
    }
    
    // MARK - RATreeView
    func treeView(treeView: RATreeView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if(item == nil){
            return self.tree?.count ?? 0
        } else {
            return 0
        }
    }
    
    func treeView(treeView: RATreeView, cellForItem item: AnyObject?) -> UITableViewCell {
        var newCell = treeView.dequeueReusableCellWithIdentifier("indexCell") as? UITableViewCell;
        
        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.Value1,reuseIdentifier:"indexCell");
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
        }
        let cell = newCell!;
        let item = item as! NSDictionary;
        let name = item["name"]! as? String
        
        cell.textLabel?.text =  name!;
        if(item["header"] != nil){
            cell.accessoryType = .None
            cell.backgroundColor =  UIColor.groupTableViewBackgroundColor()
            cell.textLabel?.textColor = UIColor.darkTextColor()
        }else{
            cell.textLabel?.textColor = self.view.tintColor;
            cell.backgroundColor=UIColor.clearColor();
            cell.accessoryType = .DisclosureIndicator
        }
        
        return cell
    }
    
    
    func treeView(treeView: RATreeView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if(item != nil){
            return (item![index])!
        }else{
            return (self.tree?[index])!
        }
    }
    
    
    func treeView(treeView:RATreeView, indentationLevelForRowForItem item:AnyObject) -> Int{
        if( item["header"] == nil ){
            return 2;
        } else{
            return 0;
        }
    }
    
    func treeView(treeView:RATreeView,  didSelectRowForItem item:AnyObject){
        self.treeView(treeView,accessoryButtonTappedForRowForItem: item);
    }
    
    func treeView(treeView:RATreeView,  accessoryButtonTappedForRowForItem item:AnyObject){
        let item = item as! NSDictionary;
        if(item["header"] == nil ){
            self.openItem(item);
        }
    }
    
    // MARK: - view controller functions overwrites
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
