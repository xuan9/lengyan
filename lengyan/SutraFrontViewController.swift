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
    internal var tree:[[String:AnyObject]]?;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 2 ,y:bounds.origin.y + 110),
            size:   CGSize(width: bounds.size.width + 4 , height:bounds.size.height  - 110 - (self.tabBarController?.tabBar.bounds.size.height ?? 0))));
        treeView.delegate = self
        treeView.dataSource = self
        treeView.rowHeight = 34;
        treeView.backgroundColor = UIColor.whiteColor()
        view.backgroundColor = UIColor.whiteColor()
        treeView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(treeView)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SutraFrontViewController.longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.showList()
        }
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(SutraIndexViewController.onApplicationWillTerminate),
            name: UIApplicationWillTerminateNotification,
            object: nil)
    }
    
    func showList(){
            var firstLevelItems=[[String:AnyObject]]();
//            firstLevelItems.append(["name":"大佛頂如來密因修證了義諸菩薩萬行首楞嚴經","header":true]);
//            for item in (Book.data.tree!["children"] as! NSArray) {
//                firstLevelItems.append(item as! [String : AnyObject]);
//            }
//            firstLevelItems.append(["name":"★精选","header":true]);
            let sortedLikes = KEY_PATHS;//Data.shared.likes.sort({$0 < $1})
            for like in sortedLikes {
                firstLevelItems.append(Book.data.itemOfPath(like))
            }
            self.tree = firstLevelItems;
            dispatch_async(dispatch_get_main_queue()){
                self.treeView.reloadData()
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
            if item["header"] == nil {
                openContent(item)
            }
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
        
        self.presentViewController(navVC, animated: true, completion: nil)
    }
    
    func openIndex(item: NSDictionary){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item;
        indexVC.defaultExpandLevel = 1;
        indexVC.onDismiss = {
            self.showList()
        }
        
        let navVC = UINavigationController.init(rootViewController: indexVC);
        self.presentViewController(navVC, animated: true, completion: nil)
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
//            cell.textLabel?.textColor = UIColor.darkTextColor()
        }else{
//            cell.textLabel?.textColor = UIColor.init(red: 0, green: 0, blue:76/255, alpha: 0.8)//very darkblue
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
        let path = item["path"] as! String
        let level = path.componentsSeparatedByString("/").count
        return (level - 3)
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
    
    func treeView(treeView:RATreeView,  commitEditingStyle editingStyle:UITableViewCellEditingStyle, forRowForItem item:AnyObject){
        if (editingStyle == .Delete) {
            let item = item as! NSDictionary as! [String:AnyObject];
            Data.shared.unlike(item["path"] as! String)
            if let i = tree!.indexOf({$0["path"] as? String == item["path"] as? String }) {
                tree?.removeAtIndex(i)
            }

            treeView.reloadData()
        }
    }
 
    // MARK: - view controller functions overwrites
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
