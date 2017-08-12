//
//  SutraIndexViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/22.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    var onDismiss: ((Void) -> Void)?
    var isShowSutraButton = true;
    
    fileprivate var treeView: RATreeView!
    
    internal var tree:[String:Any]?, path:String?
    
    var defaultExpandLevel:Int = 2
    var expandedItemPaths:[String] = []
    var isRootIndex = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        self.navigationController?.isNavigationBarHidden = false

        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x ,y:bounds.origin.y + 5),
            size:   CGSize(width: bounds.size.width + 10 , height:bounds.size.height - 5 )));
        treeView.delegate = self
        treeView.dataSource = self
        treeView.backgroundColor = UIColor.white
        view.backgroundColor = UIColor.white
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(treeView)
        //        treeView.rowHeight = UITableViewAutomaticDimension
        treeView.rowHeight = 34.0
        //        treeView.reg§§isterClass(UITableViewCell.self, forCellReuseIdentifier: "indexCell")
        
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SutraIndexViewController.longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        
        if tree == nil {
            self.isRootIndex = true;
            self.loadRootTree();
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(SutraIndexViewController.onApplicationWillTerminate),
                name: NSNotification.Name.UIApplicationWillTerminate,
                object: nil)
        } else {
            path = tree!["path"] as? String;
            self.treeView.reloadData()
            self.updateHeader()
            
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        treeView.visibleCells()?.forEach({ (cell) in
            let item = treeView.item(for: cell as! UITableViewCell)
            treeView.expandRow(forItem: item, expandChildren: false, with: RATreeViewRowAnimationNone)
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        self .autoExpend()
    }
    
    func autoExpend(){
        var rows = self.treeView.numberOfRows();
        repeat {
            print("to expend to level: \(self.defaultExpandLevel)")
            
            let children:NSArray? = self.tree?["children"] as? NSArray;
            if(children != nil ) {
                children?.forEach({ (item) in
                    self.autoExpandNode(item as! [String : Any])
                })
            }
        
            
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
        
    }
    func loadRootTree(){
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.tree = Book.data.tree
            self.path = self.tree!["path"] as? String;
            DispatchQueue.main.async{
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
    
    func autoExpandNode(_ node:[String:Any]){
  
        let currentLevel = treeView.levelForCell(forItem: node)
        if(currentLevel >= defaultExpandLevel) {return}
        
        if (node["path"] as! String) != self.path {
            treeView.expandRow(forItem: node, with:
                RATreeViewRowAnimationNone)
        }
        //        print("Expanded level \(currentLevel) \(node["name"])");
        if(currentLevel+1 > defaultExpandLevel) {return}
        
        let children:NSArray? = node["children"] as? NSArray;
        if(children != nil ) {
            children?.forEach({ (item) in
                self.autoExpandNode(item as! [String : Any])
            })
        }
    }
    
    func updateHeader(){
        if(tree != nil) {
            self.title = tree?["name"] as? String ?? ""
        }
        self.navigationController?.navigationBar.isTranslucent = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: " ❬   ", style: .plain, target: self, action: #selector(SutraIndexViewController.close))//✕
        
        //        let likeTitle = Data.shared.isLike(path!) ? "★" : "☆"
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: likeTitle, style: .Plain, target: self, action: #selector(SutraIndexViewController.toggleLike))
        
        
        
        //        let detailBtn = UIButton.init(type: .DetailDisclosure);
        //        detailBtn.addTarget(self, action: #selector(SutraIndexViewController.openAsPage), forControlEvents: .TouchUpInside)
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: detailBtn);
        //               let buttonEdges = UIEdgeInsetsMake(0, 10, 0, -10);
        //        detailBtn.imageEdgeInsets = buttonEdges;
        
        let listButton = UIBarButtonItem(image: UIImage.init(named: "ic_format_list_bulleted_18pt"), style: .plain, target: self, action: #selector(SutraIndexViewController.openAsPage))
        
        
        if self.isShowSutraButton {
            let sutraButton = UIBarButtonItem(image: UIImage.init(named: "sutra"), style: .plain, target: self, action: #selector(SutraIndexViewController.openSutra))
            
            self.navigationItem.setRightBarButtonItems([listButton,sutraButton], animated: false)
        } else {
            self.navigationItem.setRightBarButtonItems([listButton], animated: false)
        }

    }
    
    
    func close(){
        onDismiss?();
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.popViewController(animated: true)
    }
    
    func menu(){
        let alert = UIAlertController(title: "菜單", message: nil, preferredStyle: .actionSheet)
        
        let firstAction:UIAlertAction
        if(!Data.shared.isLike(path!)){
            firstAction = UIAlertAction(title: "★加入精選", style: .default) { (alert: UIAlertAction!) -> Void in
                Data.shared.like(self.path!)
                self.updateHeader();
            }
        } else {
            firstAction = UIAlertAction(title: "☆移除精選", style: .destructive) { (alert: UIAlertAction!) -> Void in
                Data.shared.unlike(self.path!)
                self.updateHeader();
            }
        }
        
        let secondAction = UIAlertAction(title: "👍讚", style: .default) { (alert: UIAlertAction!) -> Void in
            Data.shared.like(self.path!)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { (alert: UIAlertAction!) -> Void in
        }
        alert.addAction(firstAction)
        alert.addAction(secondAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion:nil) // 6
        
    }
    //Called, when long press occurred
    func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        
        if longPressGestureRecognizer.state == UIGestureRecognizerState.began {
            
            let touchPoint = longPressGestureRecognizer.location(in: self.treeView.scrollView)
            if let item = treeView.itemForRow(at: touchPoint) as? [String : Any] {
                if(item["children"] == nil){
                    openItem(item)
                } else {
                    openIndex(item  );
                }
            }
        }
    }
    
    func openSutra(){
        let sutraVC = SutraPurePageContentViewController.init();
        sutraVC.item = tree
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    
    func openAsPage(){
        openItem(self.tree!)
    }
    
    func openAsPageFromCellButton(_ sender:UIButton){
        let cell:UITableViewCell = sender.superview as! UITableViewCell
        let item = self.treeView.item(for: cell)
        openItem((item as! NSDictionary) as! [String : Any])
    }
    
    func openItem(_ item: [String:Any]){
        
        let pageVC = SutraPageViewController.init( transitionStyle:.pageCurl,
                                                   navigationOrientation:.horizontal,
                                                   options: .none)
        let path:String = item["path"] as! String
        TICK()
        pageVC.page = Book.data.index!.index(where: { (
            item) -> Bool in
            return item["path"] == path
        })!;
        TOCK()
        
        pageVC.onDismiss = {
            self.openPath((Book.data.index?[pageVC.page] as NSDictionary?)?["path"] as! String);
        }
        self.navigationController?.pushViewController(pageVC, animated: true)
        
    }
    
    func openIndex(_ item:  [String : Any]){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item
        indexVC.defaultExpandLevel = 2;
        let navVC = UINavigationController.init(rootViewController: indexVC);
        
        indexVC.onDismiss = {
            self.openPath(indexVC.tree!["path"] as! String);
        }
        
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    func openPath(_ path:String) {
        if path == "" || path == "/" {
            return;
        }
        let rootPath = tree!["path"] as!String;
        if rootPath.characters.count > path.characters.count {
            return
        }
        let subPath = path.substring(from: rootPath.endIndex);
        var node = tree, isExpanded = false;
        for id in subPath.components(separatedBy: "/") {
            if(id==""){continue}
            if(node!["children"] != nil) {
                let chidrens = node?["children"]
                node = (chidrens as! NSArray).filter({
                    (($0 as! [String:Any])["id"]) as! String == id
                }).first as? [String:Any]
            } else {
                return;
            }
            if(node == nil) {return}
            if !treeView.isCell(forItemExpanded: node!) {
                treeView.expandRow(forItem: node, with: RATreeViewRowAnimationNone);
                isExpanded = true;
            }
        }
        if isExpanded {
            treeView.selectRow(forItem: node, animated: true, scrollPosition: RATreeViewScrollPositionMiddle)
        }
    }
    
    // MARK - RATreeView
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if(item == nil){
            return (self.tree?["children"] as? NSArray)?.count ?? 0
        } else {
            return ((item as! [String:Any])["children"] as? NSArray)?.count ?? 0
        }
    }
    
    func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        let item = item as! NSDictionary;
        let isLeaf = item["children"] == nil
        let identifier = isLeaf ? "leafCell" : "indexCell"
        var newCell = treeView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell;
        
        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.value1,reuseIdentifier:identifier);
            //            newCell!.detailTextLabel?.lineBreakMode = .ByWordWrapping;
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            //            newCell!.detailTextLabel?.numberOfLines = 2
            //            newCell!.detailTextLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote).fontWithSize(14);
            //            newCell!.detailTextLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote);
            newCell!.textLabel?.font = UIFont .systemFont(ofSize: font.pointSize + 2, weight: UIFontWeightRegular);
            
            if (!isLeaf) {
                let bookBtn = UIButton.init(type: .custom)
                bookBtn.frame = CGRect(x: 0, y: 0.0, width: 38, height: treeView.rowHeight)
                //                bookBtn.backgroundColor = UIColor.redColor()
                bookBtn.setTitle("❭", for: UIControlState())
                bookBtn.tintColor = UIColor.black
                bookBtn.setTitleColor(UIColor.lightGray, for: .normal)
                //                let bookImage = UIImage.init(named: "book_18pt")
                //                bookBtn.setImage(bookImage, forState: .Normal)
                bookBtn.addTarget(self, action: #selector(SutraIndexViewController.openAsPageFromCellButton(_:)) , for: .touchUpInside)
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
            cell.textLabel?.textColor =  UIColor.darkText;
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
    
    
    //    func treeView(treeView:RATreeView, estimatedHeightForRowForItem item: Any) -> CGFloat {
    //        return 53;
    //    }
    
    
    func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
        if(item != nil){
            return (((item as! [String:Any])["children"] as! NSArray)[index]) as! [String:Any]
        }else{
            return ((self.tree?["children"] as! NSArray)[index])  as! [String:Any]
        }
    }
    
    
    func treeView(_ treeView:RATreeView, indentationLevelForRowForItem item:Any) -> Int{
        return treeView.levelForCell(forItem: item) * 2;
    }
    
    func treeView(_ treeView:RATreeView, didExpandRowForItem item:Any){
        self.expandedItemPaths.append((item as! NSDictionary)["path"] as! String)
    }
    
    func treeView(_ treeView:RATreeView, didCollapseRowForItem item:Any){
        let index = expandedItemPaths.index(of: (item as! NSDictionary)["path"] as! String)
        if index != nil {
            self.expandedItemPaths.remove(at: index!)
        }
    }
    
    func treeView(_ treeView:RATreeView,  didSelectRowForItem item:Any){
        let item = item   as! [String:Any];
        if(item["children"] == nil){
            self.openItem(item)
        }
    }
    
    func treeView(_ treeView:RATreeView,  accessoryButtonTappedForRowForItem item:Any){
        let item = item  as! [String:Any];
        self.openItem(item);
    }
    
    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any] {
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
        
        return [Any]()
    }
    
    //    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    //
    //        // Intentionally blank. Required to use UITableViewRowActions
    //    }
    
    
    // MARK: - view controller functions overwrites
    //    override func prefersStatusBarHidden() -> Bool {
    //        return true
    //    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
