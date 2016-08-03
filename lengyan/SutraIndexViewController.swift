//
//  SutraIndexViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/22.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    var onDismiss: (Void -> Void)?
    private var treeView: RATreeView!
    
    internal var tree:NSDictionary?, path:String?
    
    var defaultExpandLevel:Int = 0
    var expandedItemPaths:[String] = []
    var isRootIndex = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x ,y:bounds.origin.y + 5),
            size:   CGSize(width: bounds.size.width , height:bounds.size.height - 5 - (self.tabBarController?.tabBar.bounds.size.height ?? 0))));
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
            path = tree!["path"] as? String;
            self.treeView.reloadData()
            var rows = self.treeView.numberOfRows();
            repeat {
                print("to expend to level: \(self.defaultExpandLevel)")
                self.autoExpandNode(tree!)
                self.defaultExpandLevel =  self.defaultExpandLevel + 1
                if rows == self.treeView.numberOfRows() {
                    break;
                }
                rows = self.treeView.numberOfRows()
            } while rows < Int(view.height * 1.5 / 34)
            
            if rows > Int(view.height / 34) {
                let height = self.treeView.rowHeight * view.height / CGFloat(Float(34 * rows))
                self.treeView.rowHeight = height > 28 ? height : 28
            }
            self.updateHeader()
        }
    }
    
    func loadRootTree(){
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.tree = Book.data.tree
            self.path = self.tree!["path"] as? String;
            dispatch_async(dispatch_get_main_queue()){
                self.treeView.reloadData()
            }
        }
    }
    
    func onApplicationWillTerminate(){
        Data.shared.lastExpanded = self.expandedItemPaths;
    }
    
    //    func expandItemsAsLastTime(){
    //        Data.shared.lastExpanded.sort {
    //            $0.localizedCaseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending
    //        } .forEach { (path) in
    //            let item = Book.data.itemOfPath(path);
    //            print("Expand: ", path)
    //            self.treeView.expandRowForItem(item, withRowAnimation: RATreeViewRowAnimationNone)
    //
    //        }
    //    }
    
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
    
    func updateHeader(){
        if(tree != nil) {
            self.title = tree?["name"] as? String ?? ""
        }
        self.navigationController?.navigationBar.translucent = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "❬", style: .Plain, target: self, action: #selector(SutraIndexViewController.close))//✕
        
        //        let likeTitle = Data.shared.isLike(path!) ? "★" : "☆"
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: likeTitle, style: .Plain, target: self, action: #selector(SutraIndexViewController.toggleLike))
            let sutraButton = UIBarButtonItem(image: UIImage.init(named: "sutra"), style: .Plain, target: self, action: #selector(SutraIndexViewController.openSutra))
        
        
        
        //        let detailBtn = UIButton.init(type: .DetailDisclosure);
        //        detailBtn.addTarget(self, action: #selector(SutraIndexViewController.openAsPage), forControlEvents: .TouchUpInside)
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: detailBtn);
        //               let buttonEdges = UIEdgeInsetsMake(0, 10, 0, -10);
        //        detailBtn.imageEdgeInsets = buttonEdges;
        
       let listButton = UIBarButtonItem(image: UIImage.init(named: "ic_format_list_bulleted_18pt"), style: .Plain, target: self, action: #selector(SutraIndexViewController.openAsPage))
        
        self.navigationItem.setRightBarButtonItems([listButton,sutraButton], animated: false)
    }
    
    
    func close(){
        onDismiss?();
        self.dismissViewControllerAnimated(true) {
            
        }
    }
    
    func menu(){
        let alert = UIAlertController(title: "菜單", message: nil, preferredStyle: .ActionSheet)
        
        let firstAction:UIAlertAction
        if(!Data.shared.isLike(path!)){
            firstAction = UIAlertAction(title: "★加入精選", style: .Default) { (alert: UIAlertAction!) -> Void in
                Data.shared.like(self.path!)
                self.updateHeader();
            }
        } else {
            firstAction = UIAlertAction(title: "☆移除精選", style: .Destructive) { (alert: UIAlertAction!) -> Void in
                Data.shared.unlike(self.path!)
                self.updateHeader();
            }
        }
        
        let secondAction = UIAlertAction(title: "👍讚", style: .Default) { (alert: UIAlertAction!) -> Void in
            Data.shared.like(self.path!)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .Cancel) { (alert: UIAlertAction!) -> Void in
        }
        alert.addAction(firstAction)
        alert.addAction(secondAction)
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion:nil) // 6
        
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
    
    func openSutra(){
        let sutraVC = SutraPurePageContentViewController.init();
        sutraVC.item = tree as? [String:AnyObject]
        let navVC = UINavigationController.init(rootViewController: sutraVC);
        self.navigationController?.presentViewController(navVC, animated: true, completion: nil)
    }
    
    func openAsPage(){
        openItem(self.tree!)
    }
    
    func openAsPageFromCellButton(sender:UIButton){
        let cell:UITableViewCell = sender.superview as! UITableViewCell
        let item = self.treeView.itemForCell(cell)
        openItem(item as! NSDictionary)
    }
    
    func openItem(item: NSDictionary){
        
        let pageVC = SutraPageViewController.init( transitionStyle:.PageCurl,
                                                   navigationOrientation:.Horizontal,
                                                   options: .None)
        let path:String = item["path"] as! String
        TICK()
        pageVC.page = Book.data.index!.indexOf({ (
            item) -> Bool in
            return item["path"] == path
        })!;
        TOCK()
        
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
        
        indexVC.onDismiss = {
            self.openPath(indexVC.tree!["path"] as! String);
        }
        
        self.presentViewController(navVC, animated: true, completion: {
            
        })
    }
    
    func openPath(path:String) {
        if path == "" || path == "/" {
            return;
        }
        let rootPath = tree!["path"] as!String;
        if rootPath.characters.count > path.characters.count {
            return
        }
        let subPath = path.substringFromIndex(rootPath.endIndex);
        var node = tree, isExpanded = false;
        for id in subPath.componentsSeparatedByString("/") {
            if(id==""){continue}
            if(node!["children"] != nil) {
                node = (node!["children"] as! NSArray).filter({
                    $0["id"] as! String == id
                }).first as? NSDictionary
            } else {
                return;
            }
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
        let item = item as! NSDictionary;
        let isLeaf = item["children"] == nil
        let identifier = isLeaf ? "leafCell" : "indexCell"
        var newCell = treeView.dequeueReusableCellWithIdentifier(identifier) as? UITableViewCell;
        
        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.Value1,reuseIdentifier:identifier);
            //            newCell!.detailTextLabel?.lineBreakMode = .ByWordWrapping;
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            //            newCell!.detailTextLabel?.numberOfLines = 2
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote).fontWithSize(14);
            //            newCell!.detailTextLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            
            if (!isLeaf) {
                let bookBtn = UIButton.init(type: .Custom)
                bookBtn.frame = CGRectMake(0, 0.0, 38, treeView.rowHeight)
//                bookBtn.backgroundColor = UIColor.redColor()
                bookBtn.setTitle("❭", forState: .Normal)
//                bookBtn.tintColor = UIColor.whiteColor()
//                bookBtn.setTitleColor(UIColor.lightGrayColor(), forState: .Normal)
//                let bookImage = UIImage.init(named: "book_18pt")
//                bookBtn.setImage(bookImage, forState: .Normal)
                bookBtn.addTarget(self, action: #selector(SutraIndexViewController.openAsPageFromCellButton(_:)) , forControlEvents: .TouchUpInside)
                newCell!.accessoryView = bookBtn;
            }
            
        } else {
            //            print(newCell!.bounds.height);
        }
        
        let cell = newCell!;
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
//            cell.accessoryType = .None;
            
        } else {
            //            cell.detailTextLabel!.text = ""
            //            cell.detailTextLabel?.textColor = UIColor.grayColor()
            //            for child in item["children"]!as! NSArray {
            //                cell.detailTextLabel!.text = (cell.detailTextLabel!.text ?? "")  + (child["name"] as? String ?? "") + " "
            //            }
            //            cell.selectionStyle = UITableViewCellSelectionStyleNone;
//            cell.accessoryType = .DisclosureIndicator
            //            UIImage.init(named: "book_18pt")
            cell.textLabel?.textColor =  UIColor.darkTextColor();
        }
        
//        let path = item["path"]! as? String
        cell.textLabel?.text = name!; //Data.shared.isLike(path!) ? name! + " ★"
        
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
        let item = item as! NSDictionary;
        if(item["children"] == nil){
            self.openItem(item)
        }
    }
    
    func treeView(treeView:RATreeView,  accessoryButtonTappedForRowForItem item:AnyObject){
        let item = item as! NSDictionary;
        self.openItem(item);
    }
    
    func treeView(treeView: RATreeView, editActionsForItem item: AnyObject) -> [AnyObject] {
        /*let likeAction:UITableViewRowAction;
        let path = (item as! NSDictionary)["path"] as! String;
        if(!Data.shared.isLike(path)){
            likeAction = UITableViewRowAction(style: .Normal, title: "☆") { (action: UITableViewRowAction!, indexPath: NSIndexPath!) -> Void in
                Data.shared.like(path)
                self.treeView.setEditing(false, animated: true)
                self.treeView.reloadRowsForItems([item], withRowAnimation: RATreeViewRowAnimationNone)
            }
        } else {
            likeAction = UITableViewRowAction(style: .Default, title: "★") { (action: UITableViewRowAction!, indexPath: NSIndexPath!) -> Void in
                Data.shared.unlike(path)
                self.treeView.setEditing(false, animated: true)
                self.treeView.reloadRowsForItems([item], withRowAnimation: RATreeViewRowAnimationNone)
            }
        }
        likeAction.backgroundColor = self.treeView.tintColor;
        
        if item["children"]! == nil {
            return [likeAction]
        } else {
            let newWindowAction = UITableViewRowAction(style: .Default, title: "⇪") { (action: UITableViewRowAction!, indexPath: NSIndexPath!) -> Void in
                self.openIndex(item as! NSDictionary)
                self.treeView.setEditing(false, animated: true)
            }
            newWindowAction.backgroundColor = self.treeView.tintColor;
            
            //            let pageViewAction = UITableViewRowAction(style: .Default, title: "📖") { (action: UITableViewRowAction!, indexPath: NSIndexPath!) -> Void in
            //                self.openItem(item as! NSDictionary)
            //                self.treeView.setEditing(false, animated: true)
            //            }
            //            pageViewAction.backgroundColor = self.treeView.tintColor;
            
            
            return [likeAction, newWindowAction]
        }
     */
     
        return [AnyObject]()
    }
    
    //    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    //
    //        // Intentionally blank. Required to use UITableViewRowActions
    //    }
    
    
    // MARK: - view controller functions overwrites
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
