//
//  SutraIndexViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/22.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate, NavigationPopAware{
    
    var onDismiss: (() -> Void)?

    fileprivate var treeView: RATreeView!
    
    internal var tree:[String:Any]?, path:String?
    
    var defaultExpandLevel:Int = 2
    var isRootIndex = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "reader.outlineIndex"
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
                name: UIApplication.willTerminateNotification,
                object: nil)
        } else {
            var resolvedTree = tree!
            if self.path == nil {
                self.path = resolvedTree["path"] as? String
            }
            while resolvedTree["children"] == nil {
                if let parent = Book.shared.parentOfItem(resolvedTree) {
                    resolvedTree = parent
                } else {
                    break
                }
            }
            self.tree = resolvedTree
            self.treeView.reloadData()
            if let currentPath = self.path, !currentPath.isEmpty, currentPath != "/" {
                self.openPath(currentPath, shouldCenter: true)
            }
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
        Book.shared.loadDataWithCompletionHandler { result in
            guard case .success = result else {
                self.tree = [:]
                self.treeView.reloadData()
                self.updateHeader()
                return
            }
            self.tree = Book.shared.tree
            if self.path == nil || self.path == "/" {
                switch Prefers.shared.outlineResumeTarget {
                case let .paged(path, _), let .tree(path):
                    self.path = path
                case .chapter, nil:
                    self.path = self.tree?["path"] as? String
                }
            }
            self.treeView.reloadData()
            self.updateHeader()
            if let currentPath = self.path {
                self.openPath(currentPath, shouldCenter: true)
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
        if let tree = tree {
            let path = tree["path"] as? String ?? ""
            self.title = path.isEmpty || path == "/"
                ? L10n.str("home_full_outline")
                : (tree["name"] as? String ?? "")
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
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.popViewController(animated: true)
    }

    func navigationControllerDidPop() {
        onDismiss?()
    }

    // MARK: - 主题变化即时刷新
    @objc private func themeDidChange() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.treeView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            self.updateHeader()
            // RATreeView.reloadData() 会清空展开结构。只重绘可见行即可；
            // 离屏行在复用时会自然使用最新主题。
            self.treeView.visibleCells()?.forEach { cell in
                guard let cell = cell as? UITableViewCell,
                      let item = self.treeView.item(for: cell) as? NSDictionary else { return }
                cell.backgroundColor = SutraDesignTokens.shared.color(for: .background)
                self.updateCellText(cell, for: item)
            }
        }, completion: nil)
    }
    
    func menu(){
        let alert = UIAlertController(title: NSLocalizedString("menu", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        let firstAction:UIAlertAction
        if(!Prefers.shared.isLike(path!)){
            firstAction = UIAlertAction(title: L10n.str("menu_add_curated"), style: .default) { (alert: UIAlertAction!) -> Void in
                Prefers.shared.like(self.path!)
                NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
                self.updateHeader();
            }
        } else {
            firstAction = UIAlertAction(title: L10n.str("menu_remove_curated"), style: .destructive) { (alert: UIAlertAction!) -> Void in
                Prefers.shared.unlike(self.path!)
                NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
                self.updateHeader();
            }
        }
        
        let secondAction = UIAlertAction(title: L10n.str("menu_like"), style: .default) { (alert: UIAlertAction!) -> Void in
            Prefers.shared.like(self.path!)
            NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
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
        
        if longPressGestureRecognizer.state == UIGestureRecognizer.State.began {
            
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

        // The tapped leaf is already visible. Mark it current without moving
        // the list so returning from the reader restores the exact viewport.
        self.openPath(path, shouldCenter: false)

        // SAFE: Check if there's an existing reader on the navigation stack.
        // If so, we instantiate a new clean copy of that reader type, set the stack to place it on top of self (IndexVC),
        // and animate to it. This avoids both navigation recursion and UIKit stack-corruption bugs from reordering existing instances.
        if let viewControllers = self.navigationController?.viewControllers {
            if viewControllers.contains(where: { $0 is SutraPageViewController }) {
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
            } else if viewControllers.contains(where: { $0 is SutraPurePageViewController }) {
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

        let resumesInTreeMode: Bool
        if case .tree? = Prefers.shared.outlineResumeTarget {
            resumesInTreeMode = true
        } else {
            resumesInTreeMode = false
        }
        if resumesInTreeMode {
            let purePageVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            purePageVC.path = path
            purePageVC.hidesBottomBarWhenPushed = true
            purePageVC.onDismiss = { [weak self, weak purePageVC] in
                guard let strongSelf = self, let reader = purePageVC else { return }
                if let itemPath = reader.path {
                    strongSelf.openPath(itemPath)
                }
            }
            print("DEBUG: SutraIndexViewController openItem (Pure) - Stack before push: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
            self.navigationController?.pushViewController(purePageVC, animated: true)
            print("DEBUG: SutraIndexViewController openItem (Pure) - Stack after push: \(self.navigationController?.viewControllers.map { type(of: $0) } ?? [])")
            return
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
    
    /// Keeps the hidden outline synchronized with the visible reader. Updating
    /// immediately (without animation) means an edge-pop reveals the correct
    /// destination throughout the transition instead of jumping afterwards.
    func prepareToRevealPath(_ path: String) {
        guard !path.isEmpty, path != "/" else { return }
        guard isViewLoaded, treeView != nil else {
            // A newly pushed outline will perform the actual reveal from
            // viewDidLoad once its legacy tree view exists.
            self.path = path
            return
        }
        openPath(path, animated: false)
    }

    func openPath(
        _ path:String,
        shouldCenter: Bool? = nil,
        animated: Bool? = nil
    ) {
        // SAFE: Check if path is valid
        guard !path.isEmpty && path != "/" else {
            return
        }

        let previousPath = self.path

        // A contextual outline normally starts at the current node's parent.
        // If paging crosses that boundary, promote only to the smallest common
        // ancestor. This preserves the compact context without ever resolving
        // a same-named suffix inside the wrong branch.
        guard let rootNode = rootNode(containing: path) else { return }
        guard let rootPath = rootNode["path"] as? String else {
            print("⚠️ ERROR: Failed to get root path from tree in openPath")
            return
        }
        let rootComponents = pathComponents(rootPath)
        let targetComponents = pathComponents(path)
        guard targetComponents.starts(with: rootComponents) else { return }

        var currentNode = rootNode

        for id in targetComponents.dropFirst(rootComponents.count) {
            // SAFE: Check if current node has children
            guard let children = currentNode["children"] as? NSArray else {
                return
            }

            // Keep the original Foundation object owned by RATreeView. Casting
            // every child to a Swift Dictionary creates a bridged copy that the
            // legacy tree control cannot resolve back to its internal node.
            if let foundNode = children.first(where: { child in
                guard let childDict = child as? NSDictionary,
                      let childId = childDict["id"] as? String else { return false }
                return childId == id
            }) as? NSDictionary {
                currentNode = foundNode
            } else {
                print("⚠️ WARNING: Failed to find child with id: \(id)")
                return
            }

            // SAFE: Expand node if needed
            if !treeView.isCell(forItemExpanded: currentNode) {
                treeView.expandRow(forItem: currentNode, with: RATreeViewRowAnimationNone)
            }
        }

        // Commit the reading path only after the exact node has been resolved.
        // A failed lookup must never clear the old active-row highlight.
        self.path = path

        // New reading locations are centered. Re-selecting the same path keeps
        // the user's exact scroll position (reader round-trip / tab switch).
        let centersCurrentPath = shouldCenter ?? (previousPath != path)
        let animatesSelection = animated ?? centersCurrentPath
        treeView.selectRow(
            forItem: currentNode,
            animated: centersCurrentPath && animatesSelection,
            scrollPosition: centersCurrentPath
                ? RATreeViewScrollPositionMiddle
                : RATreeViewScrollPositionNone
        )
        
        // Refresh visible cells to update text colors immediately
        treeView.visibleCells()?.forEach { cell in
            if let cell = cell as? UITableViewCell,
               let item = treeView.item(for: cell) as? NSDictionary {
                self.updateCellText(cell, for: item)
            }
        }
    }

    private func rootNode(containing targetPath: String) -> NSDictionary? {
        guard let currentTree = tree,
              let currentRootPath = currentTree["path"] as? String else {
            print("⚠️ ERROR: Failed to get root path from tree in openPath")
            return nil
        }

        let currentRootComponents = pathComponents(currentRootPath)
        let targetComponents = pathComponents(targetPath)
        if targetComponents.starts(with: currentRootComponents) {
            return currentTree as NSDictionary
        }

        let targetNode = Book.shared.itemOfPath(targetPath)
        guard let resolvedTargetPath = targetNode["path"] as? String,
              pathComponents(resolvedTargetPath) == targetComponents else {
            print("⚠️ ERROR: Failed to resolve outline path: \(targetPath)")
            return nil
        }

        let sharedComponents = zip(currentRootComponents, targetComponents)
            .prefix(while: { pair in pair.0 == pair.1 })
            .map { $0.0 }
        let sharedPath = sharedComponents.isEmpty
            ? ""
            : "/" + sharedComponents.joined(separator: "/")
        let promotedTree = Book.shared.itemOfPath(sharedPath)
        guard let promotedPath = promotedTree["path"] as? String,
              pathComponents(promotedPath) == sharedComponents else {
            print("⚠️ ERROR: Failed to promote outline for path: \(targetPath)")
            return nil
        }

        tree = promotedTree
        isRootIndex = sharedComponents.isEmpty
        treeView.reloadData()
        updateHeader()
        return promotedTree as NSDictionary
    }

    private func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }
    
    // MARK - RATreeView
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return (self.tree?["children"] as? NSArray)?.count ?? 0
        } else if let itemDict = item as? NSDictionary {
            return (itemDict["children"] as? NSArray)?.count ?? 0
        } else {
            print("⚠️ ERROR: Failed to cast outline item in numberOfChildrenOfItem")
            return 0
        }
    }
    
    private func updateCellText(_ cell: UITableViewCell, for item: NSDictionary) {
        let isLeaf = item["children"] == nil
        let name = item["name"] as? String ?? ""
        let level = treeView.levelForCell(forItem: item)
        
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let chapterTitleColor = SutraDesignTokens.shared.color(for: .chapterTitle)
        let tertiaryTextColor = SutraDesignTokens.shared.color(for: .textTertiary)
        
        cell.textLabel?.text = name
        
        if isLeaf {
            let itemPath = item["path"] as? String ?? ""
            let isActive = (itemPath == self.path)
            
            // 🌿 解决对齐问题：使用与目录相同尺寸的隐形占位 Chevron，确保叶子节点与同级目录完美对齐
            let config = level == 0
                ? UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
                : UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
            let spacerImage = UIImage(systemName: "chevron.right")?.withConfiguration(config)
            cell.imageView?.image = spacerImage
            cell.imageView?.tintColor = .clear
            
            if isActive {
                // 🎋 当前阅读中的叶子节点：古典雅致的朱砂红 (favorite) + Medium字重
                let activeColor = SutraDesignTokens.shared.color(for: .favorite)
                cell.textLabel?.textColor = activeColor
                cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .medium)
            } else {
                // 🌿 普通叶子节点：清雅素淡的竹翠绿 (primary) + Regular字重
                let leafDefaultColor = SutraDesignTokens.shared.color(for: .primary)
                cell.textLabel?.textColor = leafDefaultColor
                cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)
            }
        } else if level == 0 {
            // 🌿 顶级章节：黄金鎏金主色 (chapterTitle) + 24pt Medium，醒目的章节标志
            cell.textLabel?.textColor = chapterTitleColor
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .medium)
            
            let isExpanded = treeView.isCell(forItemExpanded: item)
            let iconName = isExpanded ? "chevron.down" : "chevron.right"
            let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            let chevronImage = UIImage(systemName: iconName)?.withConfiguration(config)
            cell.imageView?.image = chevronImage
            cell.imageView?.tintColor = chapterTitleColor
        } else {
            // 🌿 子级目录：檀褐色 (textSecondary) + 18pt Medium，轻量中性过渡
            cell.textLabel?.textColor = secondaryTextColor
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .menuItem, weight: .medium)
            
            let isExpanded = treeView.isCell(forItemExpanded: item)
            let iconName = isExpanded ? "chevron.down" : "chevron.right"
            let config = UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
            let chevronImage = UIImage(systemName: iconName)?.withConfiguration(config)
            cell.imageView?.image = chevronImage
            cell.imageView?.tintColor = tertiaryTextColor
        }
        cell.setNeedsLayout()
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
        }

        // 每次渲染都刷新颜色和附件样式（新建 + 复用），确保主题切换即时生效
        let cell = newCell!;
        cell.accessibilityIdentifier = "outline.row.\(item["path"] as? String ?? "")"
        // 🌿 回归全屏背景色平整统一，符合纯净留白风格，避免花哨的条叠感
        cell.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        cell.selectionStyle = .none
        cell.selectedBackgroundView = nil
        
        if (isLeaf) {
            // 叶子节点：右侧为经典简洁的系统原生右向箭头，用户关注力回归到左侧内容本身
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
        } else {
            // 章节/目录节点：无右侧图标，点击直接展开/折叠
            cell.accessoryType = .none
            cell.accessoryView = nil
        }

        updateCellText(cell, for: item)
        return cell
    }
    
    func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? NSDictionary,
           let children = item["children"] as? NSArray {
            return children[index]
        }
        return (self.tree?["children"] as! NSArray)[index]
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
