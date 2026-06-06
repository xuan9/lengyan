//
//  SutraIndexViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/22.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    var onDismiss: (() -> Void)?

    fileprivate var treeView: RATreeView!
    
    internal var tree:[String:Any]?, path:String?
    
    var defaultExpandLevel:Int = 2
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
        treeView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(treeView)
        treeView.rowHeight = 44.0  // iOS 最小触摸目标
        treeView.separatorStyle = RATreeViewCellSeparatorStyleNone
                
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
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
        }
        self.updateHeader()

        // 监听主题变化，即时刷新颜色
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.hidesBarsOnSwipe = false;
        self.navigationItem.leftBarButtonItem?.tintColor = SutraDesignTokens.shared.color(for: .sutraText)
        treeView.visibleCells()?.forEach({ (cell) in
            let item = treeView.item(for: cell as! UITableViewCell)
            treeView.expandRow(forItem: item, expandChildren: false, with: RATreeViewRowAnimationNone)
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let bottomPadding = self.view.safeAreaInsets.bottom + 44
        self.treeView.scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomPadding,
            right: 0
        )
        self.treeView.scrollView.scrollIndicatorInsets = self.treeView.scrollView.contentInset
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
        } while rows < Int(view.frame.height * 1.5 / 34)
        
        if rows > Int(view.frame.height / 34) {
            let height = self.treeView.rowHeight * view.frame.height / CGFloat(Float(34 * rows))
            self.treeView.rowHeight = height > 28 ? height : 28
        }
        
    }
    func loadRootTree(){
        Book.shared.loadDataWithCompletionHandler { () in
            self.tree = Book.shared.tree
            self.path = self.tree!["path"] as? String;
            DispatchQueue.main.async{
                self.treeView.reloadData()
            }
        }
    }
    
    @objc func onApplicationWillTerminate(){
    }
   
    func autoExpandNode(_ node:[String:Any]){
  
        let currentLevel = treeView.levelForCell(forItem: node)
        if(currentLevel >= defaultExpandLevel) {return}
        
        if (node["path"] as! String) != self.path {
            treeView.expandRow(forItem: node, with:
                RATreeViewRowAnimationNone)
        }
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
        let navBarColor = SutraDesignTokens.shared.color(for: .navigationBar)
        self.navigationController?.navigationBar.backgroundColor = navBarColor
        self.navigationController?.navigationBar.isTranslucent = false;
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        self.navigationItem.leftBarButtonItem?.tintColor = SutraDesignTokens.shared.color(for: .textSecondary)
        self.navigationItem.rightBarButtonItems = nil
    }
    
    
    @objc func close(){
        onDismiss?();
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - 主题变化即时刷新
    @objc private func themeDidChange() {
        treeView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        updateHeader()
        // 强制所有 cell 重新渲染以应用新颜色
        treeView.reloadData()
    }
    
    func menu(){
        let alert = UIAlertController(title: NSLocalizedString("menu", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        let firstAction:UIAlertAction
        if(!Prefers.shared.isLike(path!)){
            firstAction = UIAlertAction(title: "★加入精選", style: .default) { (alert: UIAlertAction!) -> Void in
                Prefers.shared.like(self.path!)
                self.updateHeader();
            }
        } else {
            firstAction = UIAlertAction(title: "☆移除精選", style: .destructive) { (alert: UIAlertAction!) -> Void in
                Prefers.shared.unlike(self.path!)
                self.updateHeader();
            }
        }
        
        let secondAction = UIAlertAction(title: "👍讚", style: .default) { (alert: UIAlertAction!) -> Void in
            Prefers.shared.like(self.path!)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) -> Void in
        }
        alert.addAction(firstAction)
        alert.addAction(secondAction)
        alert.addAction(cancelAction)

        // iPad: Action Sheet 需要 popover 配置，否则崩溃
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(
                x: self.view.bounds.midX, y: self.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true, completion:nil)
        
    }
    //Called, when long press occurred
    @objc func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        
        if longPressGestureRecognizer.state == UIGestureRecognizerState.began {
            
            let touchPoint = longPressGestureRecognizer.location(in: self.treeView.scrollView)
            if let item = treeView.itemForRow(at: touchPoint) as? [String : Any] {
                if(item["children"] == nil){
                    openItem(item)
                } else {
                    // Avoid recursively pushing another index view.
                    // Instead, toggle the expansion state of the parent node inline.
                    if self.treeView.isCell(forItemExpanded: item) {
                        self.treeView.collapseRow(forItem: item, collapseChildren: false, with: RATreeViewRowAnimationNone)
                    } else {
                        self.treeView.expandRow(forItem: item, expandChildren: false, with: RATreeViewRowAnimationNone)
                    }
                }
            }
        }
    }
    
    func openItem(_ item: [String:Any]){
        // SAFE: Check if path exists and is a string
        guard let path = item["path"] as? String else {
            print("⚠️ ERROR: Failed to get path from item in openItem")
            return
        }

        // SAFE: Check if Book.shared.index exists
        guard let bookIndex = Book.shared.index else {
            print("⚠️ ERROR: Book.shared.index is nil in openItem")
            return
        }

        // SAFE: Check if there's an existing reader on the navigation stack.
        // If so, we instantiate a new clean copy of that reader type, set the stack to place it on top of self (IndexVC),
        // and animate to it. This avoids both navigation recursion and UIKit stack-corruption bugs from reordering existing instances.
        if let viewControllers = self.navigationController?.viewControllers {
            if let existingPageVC = viewControllers.first(where: { $0 is SutraPageViewController }) as? SutraPageViewController {
                if let foundIndex = bookIndex.index(where: { $0["path"] == path }) {
                    let pageVC = SutraPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
                    pageVC.page = foundIndex
                    
                    var newStack = viewControllers
                    newStack.removeAll(where: { $0 is SutraPageViewController })
                    if let selfIndex = newStack.firstIndex(of: self) {
                        newStack.insert(pageVC, at: selfIndex + 1)
                        newStack = Array(newStack.prefix(through: selfIndex + 1))
                    }
                    
                    pageVC.hidesBottomBarWhenPushed = true
                    pageVC.onDismiss = { [weak self, weak pageVC] in
                        guard let strongSelf = self, let reader = pageVC else { return }
                        let indexValue = reader.page
                        if indexValue < bookIndex.count,
                           let itemPath = bookIndex[indexValue]["path"] {
                            strongSelf.openPath(itemPath)
                        }
                    }
                    
                    self.navigationController?.setViewControllers(newStack, animated: true)
                    return
                }
            } else if let existingPurePageVC = viewControllers.first(where: { $0 is SutraPurePageViewController }) as? SutraPurePageViewController {
                let purePageVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
                purePageVC.path = path
                
                var newStack = viewControllers
                newStack.removeAll(where: { $0 is SutraPurePageViewController })
                if let selfIndex = newStack.firstIndex(of: self) {
                    newStack.insert(purePageVC, at: selfIndex + 1)
                    newStack = Array(newStack.prefix(through: selfIndex + 1))
                }
                
                purePageVC.hidesBottomBarWhenPushed = true
                purePageVC.onDismiss = { [weak self, weak purePageVC] in
                    guard let strongSelf = self, let reader = purePageVC else { return }
                    if let itemPath = reader.path {
                        strongSelf.openPath(itemPath)
                    }
                }
                
                self.navigationController?.setViewControllers(newStack, animated: true)
                return
            }
        }

        let pageVC = SutraPageViewController.init( transitionStyle:.scroll,
                                                   navigationOrientation:.horizontal,
                                                   options: .none)

        TICK()

        // SAFE: Find the page index safely
        if let foundIndex = bookIndex.index(where: { $0["path"] == path }) {
            pageVC.page = foundIndex
        } else {
            print("⚠️ ERROR: Failed to find page for path: \(path)")
            return
        }

        TOCK()

        // SAFE: Create weak reference to prevent retain cycle crashes.
        // Capturing pageVC weakly allows reading pageVC.page dynamically when dismissed,
        // so the tree view always scrolls/highlights the correct last-read page.
        pageVC.onDismiss = { [weak self, weak pageVC] in
            guard let strongSelf = self, let reader = pageVC else { return }

            let indexValue = reader.page
            if indexValue < bookIndex.count,
               let itemPath = bookIndex[indexValue]["path"] {
                strongSelf.openPath(itemPath)
            } else {
                print("⚠️ ERROR: Failed to get path from page in onDismiss closure")
            }
        }

        pageVC.hidesBottomBarWhenPushed = true
        print("DEBUG: SutraIndexViewController openItem - Stack before push: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
        self.navigationController?.pushViewController(pageVC, animated: true)
        print("DEBUG: SutraIndexViewController openItem - Stack after push: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
    }
    
    func openIndex(_ item:  [String : Any]){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item
        indexVC.defaultExpandLevel = 2;

        // SAFE: Create weak reference to prevent retain cycle crashes
        indexVC.onDismiss = { [weak self] in
            guard let strongSelf = self else { return }

            // SAFE: Check if tree and path exist
            if let tree = indexVC.tree,
               let path = tree["path"] as? String {
                strongSelf.openPath(path)
            } else {
                print("⚠️ ERROR: Failed to get path from tree in openIndex onDismiss")
            }
        }

        indexVC.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    func openPath(_ path:String) {
        // SAFE: Check if path is valid
        guard !path.isEmpty && path != "/" else {
            return
        }

        // SAFE: Check if tree exists and has path
        guard let tree = self.tree,
              let rootPath = tree["path"] as? String else {
            print("⚠️ ERROR: Failed to get root path from tree in openPath")
            return
        }

        // SAFE: Check if rootPath is valid
        guard rootPath.count <= path.count else {
            return
        }

        let subPath = path[rootPath.endIndex...]
        var currentNode = tree
        var isExpanded = false

        for id in subPath.components(separatedBy: "/") {
            guard !id.isEmpty else { continue }

            // SAFE: Check if current node has children
            guard let children = currentNode["children"] as? NSArray else {
                return
            }

            // SAFE: Filter children safely
            if let foundNode = children.filter({ child in
                if let childDict = child as? [String:Any],
                   let childId = childDict["id"] as? String {
                    return childId == id
                }
                return false
            }).first as? [String:Any] {
                currentNode = foundNode
            } else {
                print("⚠️ WARNING: Failed to find child with id: \(id)")
                return
            }

            // SAFE: Expand node if needed
            if !treeView.isCell(forItemExpanded: currentNode) {
                treeView.expandRow(forItem: currentNode, with: RATreeViewRowAnimationNone)
                isExpanded = true
            }
        }

        if isExpanded {
            treeView.selectRow(forItem: currentNode, animated: true, scrollPosition: RATreeViewScrollPositionMiddle)
        }
    }
    
    // MARK - RATreeView
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return (self.tree?["children"] as? NSArray)?.count ?? 0
        } else if let itemDict = item as? [String:Any] {
            return (itemDict["children"] as? NSArray)?.count ?? 0
        } else {
            print("⚠️ ERROR: Failed to cast item to [String:Any] in numberOfChildrenOfItem")
            return 0
        }
    }
    
    private func updateCellText(_ cell: UITableViewCell, for item: NSDictionary) {
        let isLeaf = item["children"] == nil
        let name = item["name"] as? String ?? ""
        let primaryTextColor = SutraDesignTokens.shared.color(for: .sutraText)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        
        // 🌿 禅意前缀装饰：根据节点展开状态动态显示折叠（▸）或展开（▾）
        let prefix: String
        if isLeaf {
            prefix = "•  "
        } else {
            let isExpanded = treeView.isCell(forItemExpanded: item)
            prefix = isExpanded ? "▾  " : "▸  "
        }
        
        let attrText = NSMutableAttributedString(string: prefix + name)
        
        let prefixColor = isLeaf ? SutraDesignTokens.shared.color(for: .decorativeGold) : SutraDesignTokens.shared.color(for: .textTertiary)
        let textColor = isLeaf ? primaryTextColor : secondaryTextColor
        
        attrText.addAttribute(.foregroundColor, value: prefixColor, range: NSRange(location: 0, length: prefix.utf16.count))
        attrText.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: prefix.utf16.count, length: name.utf16.count))
        
        cell.textLabel?.attributedText = attrText
    }
    
    func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        // SAFE: Check if item can be cast to NSDictionary
        guard let item = item as? NSDictionary else {
            print("⚠️ ERROR: Failed to cast item to NSDictionary in cellForItem")
            return UITableViewCell()
        }
        let isLeaf = item["children"] == nil
        let identifier = isLeaf ? "leafCell" : "indexCell"
        var newCell = treeView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell;

        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.value1,reuseIdentifier:identifier)
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true
            newCell!.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)

            if (isLeaf) {
                // 叶子节点：右侧为标准右向箭头，表明点击可跳转到正文
                let chevronImage = UIImage(systemName: "chevron.right")?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12, weight: .medium))
                let chevronView = UIImageView(image: chevronImage)
                chevronView.contentMode = .center
                newCell!.accessoryView = chevronView
            } else {
                // 章节/目录节点：无右侧图标，点击直接展开/折叠，不再提供单独的阅读跳转链接
                newCell!.accessoryView = nil
            }
        }

        // 每次渲染都刷新颜色（新建 + 复用），确保主题切换即时生效
        let cell = newCell!;
        cell.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let selectedBg = UIView()
        selectedBg.backgroundColor = SutraDesignTokens.shared.color(for: .sacredGlow)
        cell.selectedBackgroundView = selectedBg
        
        if let imgView = cell.accessoryView as? UIImageView {
            imgView.tintColor = SutraDesignTokens.shared.color(for: .textTertiary)
        }

        updateCellText(cell, for: item)
        return cell
    }
    
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
        guard let itemNS = item as? NSDictionary,
              let cell = treeView.cell(forItem: item) else { return }
        updateCellText(cell, for: itemNS)
    }
    
    func treeView(_ treeView:RATreeView, didCollapseRowForItem item:Any){
        guard let itemNS = item as? NSDictionary,
              let cell = treeView.cell(forItem: item) else { return }
        updateCellText(cell, for: itemNS)
    }
    
    func treeView(_ treeView:RATreeView,  didSelectRowForItem item:Any){
        // SAFE: Check if item can be cast to dictionary
        guard let itemDict = item as? [String:Any] else {
            print("⚠️ ERROR: Failed to cast item to [String:Any] in didSelectRowForItem")
            return
        }

        // SAFE: Check if item has children (leaf nodes have no children)
        if itemDict["children"] == nil {
            self.openItem(itemDict)
        }
    }
    
    func treeView(_ treeView:RATreeView,  accessoryButtonTappedForRowForItem item:Any){
        // SAFE: Check if item can be cast to dictionary
        guard let itemDict = item as? [String:Any] else {
            print("⚠️ ERROR: Failed to cast item to [String:Any] in accessoryButtonTappedForRowForItem")
            return
        }
        self.openItem(itemDict);
    }
    
    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any] {
        return [Any]()
    }
    
}
