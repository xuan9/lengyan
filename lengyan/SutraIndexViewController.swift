//
//  SutraIndexViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/22.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    private var treeView: RATreeView!
    
    internal var tree:NSDictionary?
    
    var defaultExpandLevel:Int = 0
    var expandedItemPaths:[String] = []
    var isRootIndex = false;
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 10 ,y:bounds.origin.y),
            size:   CGSize(width: bounds.size.width + 20, height:bounds.size.height-(self.tabBarController?.tabBar.bounds.size.height ?? 0))));
        treeView.delegate = self
        treeView.dataSource = self
        treeView.backgroundColor = UIColor.whiteColor()
        view.backgroundColor = UIColor.whiteColor()
        treeView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(treeView)
        //        treeView.rowHeight = UITableViewAutomaticDimension
        treeView.rowHeight = 34.0
        //        treeView.reg§§isterClass(UITableViewCell.self, forCellReuseIdentifier: "indexCell")
        
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SutraIndexViewController.longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        
        if tree == nil {
            self.isRootIndex = true;
            self.loadRootTree();
            
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: #selector(SutraIndexViewController.onApplicationWillTerminate),
                name: UIApplicationWillTerminateNotification,
                object: nil)
        } else {
            self.treeView.reloadData()
            self.autoExpandNode(tree!)
            self.setTitle()
        }
        
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
            self.tree = ["children":firstLevelItems,"name":Book.data.tree!["name"]!];

            dispatch_async(dispatch_get_main_queue()){
                self.treeView.reloadData()
                self.expandItemsAsLastTime();
                
                //                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)),dispatch_get_main_queue()){
                //                    }
            }
        }
    }
    func onApplicationWillTerminate(){
        Data.shared.lastExpanded = self.expandedItemPaths;
    }
    
    func expandItemsAsLastTime(){
        Data.shared.lastExpanded.sort {
            $0.localizedCaseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending
        } .forEach { (path) in
            let item = Book.data.itemOfPath(path);
            print("Expand: ", path)
            self.treeView.expandRowForItem(item, withRowAnimation: RATreeViewRowAnimationNone)
            
        }
    }
    
    func autoExpandNode(node:NSDictionary){
        let currentLevel = treeView.levelForCellForItem(node);
        if(currentLevel >= defaultExpandLevel) {return}
        
        treeView.expandRowForItem(node, withRowAnimation: RATreeViewRowAnimationNone)
        //        print("Expanded level \(currentLevel) \(node["name"])");
        if(currentLevel+1 > defaultExpandLevel) {return}
        
        let children:NSArray? = node["children"] as? NSArray;
        if(children != nil ) {
            children?.forEach({ (item) in
                self.autoExpandNode(item as! NSDictionary)
            })
        }
    }
    
    func setTitle(){
        if(tree != nil) {
            self.title = tree?["name"] as? String ?? ""
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "x", style: .Plain, target: self, action: #selector(SutraIndexViewController.close))
        self.navigationController?.navigationBar.translucent = false;
    }
    
    func close(){
        self.dismissViewControllerAnimated(true) {
            
        }
    }
    //Called, when long press occurred
    func longPress(longPressGestureRecognizer: UILongPressGestureRecognizer) {
        
        if longPressGestureRecognizer.state == UIGestureRecognizerState.Began {
            
            let touchPoint = longPressGestureRecognizer.locationInView(self.treeView.scrollView)
            if let item = treeView.itemForRowAtPoint(touchPoint) as? NSDictionary {
                if(item["children"] == nil){
                    openItem(item)
                } else {
                    openIndex(item);
                }
            }
        }
    }
    
    func openItem(item: NSDictionary){
        let pageVC = SutraPageViewController.init( transitionStyle:.PageCurl,
                                                   navigationOrientation:.Horizontal,
                                                   options: .None)
        let path:String = item["path"] as! String
        pageVC.page=Book.data.index!.indexOf({ (
            item) -> Bool in
            return item["path"] == path
        })!;
        
        pageVC.onDismiss = {
            self.openPath((Book.data.index?[pageVC.page] as NSDictionary?)?["path"] as! String);
        }
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
    
    func openPath(path:String) {
        if path == "" || path == "/" {
            return;
        }
        var node = tree, isExpanded = false;
        for id in path.componentsSeparatedByString("/") {
            if(id==""){continue}
            node = (node!["children"] as! NSArray).filter({
                $0["id"] as! String == id
            }).first as? NSDictionary
            if(node == nil) {return}
            if !treeView.isCellForItemExpanded(node!) {
                treeView.expandRowForItem(node, withRowAnimation: RATreeViewRowAnimationNone);
                isExpanded = true;
            }
        }
        if isExpanded {
            treeView.selectRowForItem(node, animated: true, scrollPosition: RATreeViewScrollPositionMiddle)
        }
    }
    
    // MARK - RATreeView
    func treeView(treeView: RATreeView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if(item == nil){
            return self.tree?["children"]?.count ?? 0
        } else {
            return item!["children"]!?.count ?? 0
        }
    }
    
    func treeView(treeView: RATreeView, cellForItem item: AnyObject?) -> UITableViewCell {
        var newCell = treeView.dequeueReusableCellWithIdentifier("indexCell") as? UITableViewCell;
        
        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.Value1,reuseIdentifier:"indexCell");
            
            //            newCell!.detailTextLabel?.lineBreakMode = .ByWordWrapping;
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            //            newCell!.detailTextLabel?.numberOfLines = 2
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote).fontWithSize(14);
            //            newCell!.detailTextLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            
        } else {
            //            print(newCell!.bounds.height);
        }
        
        let cell = newCell!;
        let item = item as! NSDictionary;
        let name = item["name"]! as? String
        if item["children"] == nil {
            //            cell.detailTextLabel!.text = ""
            //            let content = contents?[item["path"] as! String] as? NSArray;
            //            if content != nil {
            //                for item in content! {
            //                    let type = item["type"];
            //                    if type!!.caseInsensitiveCompare("sutra") == .OrderedSame  {
            //                        cell.detailTextLabel!.text = (cell.detailTextLabel!.text ?? "") +  (item["content"] as? String ?? "")
            //                    }
            //                }
            //            }
            //            cell.accessoryType = .DetailButton;
            cell.textLabel?.textColor = self.view.tintColor;
            
        } else {
            //            cell.detailTextLabel!.text = ""
            //            cell.detailTextLabel?.textColor = UIColor.grayColor()
            //            for child in item["children"]!as! NSArray {
            //                cell.detailTextLabel!.text = (cell.detailTextLabel!.text ?? "")  + (child["name"] as? String ?? "") + " "
            //            }
            //            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //            cell.accessoryType = .None;
            cell.textLabel?.textColor =  UIColor.darkTextColor();
            
            
        }
        cell.textLabel?.text =  name!;
        if(item["header"] != nil && item["header"] as! Bool){
            cell.backgroundColor=UIColor.darkGrayColor();
        }else{
            cell.backgroundColor=UIColor.clearColor();
        }
        
        //
        //        cell.detailTextLabel?.preferredMaxLayoutWidth = CGRectGetWidth(self.view.bounds)
        //        cell.textLabel?.preferredMaxLayoutWidth = CGRectGetWidth(self.view.bounds)
        //
        //        let margins = cell.contentView.layoutMarginsGuide
        //        cell.textLabel?.leadingAnchor.constraintEqualToAnchor(margins.leadingAnchor).active = true
        //
        //        cell.detailTextLabel?.leadingAnchor.constraintEqualToAnchor(cell.textLabel?.trailingAnchor).active = true
        //
        //        cell.detailTextLabel?.trailingAnchor.constraintEqualToAnchor(margins.trailingAnchor).active = true
        //
        //        cell.contentView.setNeedsLayout()
        //        cell.contentView.layoutIfNeeded()
        //
        //
        //        cell.setNeedsLayout()
        //        cell.layoutIfNeeded()
        return cell
    }
    
    
    //    func treeView(treeView:RATreeView, estimatedHeightForRowForItem item: AnyObject) -> CGFloat {
    //        return 53;
    //    }
    
    
    func treeView(treeView: RATreeView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if(item != nil){
            return (item!["children"]?![index])!
        }else{
            return (self.tree?["children"]?[index])!
        }
    }
    
    
    func treeView(treeView:RATreeView, indentationLevelForRowForItem item:AnyObject) -> Int{
        return treeView.levelForCellForItem(item) * 2;
    }
    
    func treeView(treeView:RATreeView, didExpandRowForItem item:AnyObject){
        self.expandedItemPaths.append((item as! NSDictionary)["path"] as! String)
    }
    
    func treeView(treeView:RATreeView, didCollapseRowForItem item:AnyObject){
        let index = expandedItemPaths.indexOf((item as! NSDictionary)["path"] as! String)
        if index != nil {
            self.expandedItemPaths.removeAtIndex(index!)
        }
    }
    
    func treeView(treeView:RATreeView,  didSelectRowForItem item:AnyObject){
        self.treeView(treeView,accessoryButtonTappedForRowForItem: item);
    }
    
    func treeView(treeView:RATreeView,  accessoryButtonTappedForRowForItem item:AnyObject){
        let item = item as! NSDictionary;
        if item["children"] == nil {
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
