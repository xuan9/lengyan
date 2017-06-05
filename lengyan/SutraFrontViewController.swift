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
    
    
    fileprivate var treeView: RATreeView!
    internal var tree:[[String:Any]]?;
    fileprivate var sutraIndexButtons = [String]();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bounds:CGRect = self.view.bounds;
        self.navigationController?.isNavigationBarHidden = true

        let topBarView = UIView(frame: CGRect(
            origin: CGPoint(x:0 ,y:0 ),
            size:   CGSize(width: bounds.size.width , height:20 )));
        topBarView.backgroundColor = UIColor.white
        view.addSubview(topBarView)
        
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 2 ,y:bounds.origin.y + 20 ),
            size:   CGSize(width: bounds.size.width + 4 , height:bounds.size.height - 20 )));
        treeView.delegate = self
        treeView.dataSource = self
        treeView.rowHeight = 30;
        treeView.backgroundColor = UIColor.white
        view.backgroundColor = UIColor.white
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(treeView)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SutraFrontViewController.longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.setupHeaderView()
            self.showList()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(SutraIndexViewController.onApplicationWillTerminate),
            name: NSNotification.Name.UIApplicationWillTerminate,
            object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupHeaderView()
    }
    
    func setupHeaderView() {
        DispatchQueue.main.async{
            let width = self.view.bounds.width
            
            let header:UIView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 110))
            //            header.backgroundColor = UIColor.init(red: 247.0/255.0, green: 247.0/255, blue: 247.0/255, alpha: 1)
            
            let title = self.makeSutraIndexButton("", frame: CGRect(x: 0, y: 10, width: width, height: 21));
            let subTitle = UIButton.init(type: .custom);
            subTitle.frame = CGRect(x: 0, y: 40, width: width, height: 17);
            
            let indexes = UIView(frame: CGRect(x: 0, y: 70, width: width, height: 21));
            let i1 = self.makeSutraIndexButton("/A1",frame: CGRect(x: (width - 51)/2 - 40 - 36, y: 0, width: 36, height: 21));
            let i2 =  self.makeSutraIndexButton("/A2",frame: CGRect(x: (width - 51)/2 , y: 0, width: 51, height: 21));
            let i3 =  self.makeSutraIndexButton("/A3",frame: CGRect(x: (width + 51)/2 + 40,y: 0, width: 51, height: 21));
            //            let underlineAttriString = NSAttributedString(string:(i2.titleLabel?.text)!, attributes: [NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue])
            //            i2.titleLabel?.attributedText = underlineAttriString
            
            subTitle.setTitle("   無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義", for: UIControlState())
                        
            subTitle.semanticContentAttribute = .forceRightToLeft

            subTitle.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            subTitle.titleLabel!.adjustsFontSizeToFitWidth = true;
            subTitle.setTitleColor(UIColor.darkGray, for: UIControlState())
//            subTitle.addTarget(self, action: #selector(SutraFrontViewController.openDrbaLink(_:)), for: .touchUpInside)
            subTitle.addTarget(self, action: #selector(SutraFrontViewController.openRootIndex), for: .touchUpInside)

            indexes.addSubview(i1);
            indexes.addSubview(i2);
            indexes.addSubview(i3);
            header.addSubview(title)
            header.addSubview(subTitle)
            header.addSubview(indexes)
            
            
            let px = 1 / UIScreen.main.scale
            let frame = CGRect(x: 0, y: 110 - px, width: self.treeView.frame.size.width, height: px)
            let line: UIView = UIView(frame: frame)
            line.backgroundColor = self.treeView.separatorColor
            header.addSubview(line)
            //            self.treeView.scrollView.contentInset = UIEdgeInsetsMake(110, 0, 0, 0);
            //            self.treeView.scrollView.addSubview(header)
            
            self.treeView.treeHeaderView = header
            
            let footerSeperator = UIView(frame: CGRect(x: 0, y: 2, width: width - 10, height: 1))
            footerSeperator.backgroundColor = UIColor.lightGray

            
            
            let footerLabel = UILabel(frame: CGRect(x: 20, y: 10, width: width - 20, height: 60))
            footerLabel.text = "南無楞嚴會上佛菩薩！\n南無楞嚴會上佛菩薩！\n南無楞嚴會上佛菩薩！"
            footerLabel.numberOfLines = 3
            footerLabel.font = UIFont.systemFont(ofSize: 14)
            footerLabel.adjustsFontSizeToFitWidth = true;

            let linkButton = UIButton(frame: CGRect(x: 10, y: 70, width: width - 30, height: 20))
            linkButton.setTitle("經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站", for: .normal)
            linkButton.setImage(UIImage.init(named: "ic_link")?.withRenderingMode(.alwaysTemplate), for: .normal)
            linkButton.addTarget(self, action: #selector(SutraFrontViewController.openDrbaLink(_:)), for: .touchUpInside)
            linkButton.semanticContentAttribute = .forceRightToLeft
            linkButton.titleLabel?.font = UIFont.systemFont(ofSize: 10)
            linkButton.titleLabel?.adjustsFontSizeToFitWidth = true;
            linkButton.setTitleColor(UIColor.darkText, for: .normal)
            linkButton.backgroundColor = UIColor.white
            linkButton.tintColor = UIColor.darkText
            linkButton.contentHorizontalAlignment = .left
            
            let footerLabel2 = UILabel(frame: CGRect(x: 10, y: 90, width: width - 20, height: 20))
            footerLabel2.text = "感恩法界佛教總會！本屏中間所列為部分關鍵科判，可點擊經名打開完整科判。"
            footerLabel2.numberOfLines = 1
            footerLabel2.font = UIFont.systemFont(ofSize: 10)
            footerLabel2.adjustsFontSizeToFitWidth = true;

            let footer:UIView = UIView(frame: CGRect(x: 5, y: 2, width: width - 20, height: 130))
            footer.backgroundColor = UIColor.white
            footer.addSubview(footerSeperator)
            footer.addSubview(footerLabel)
            footer.addSubview(linkButton)
            footer.addSubview(footerLabel2)

            self.treeView.treeFooterView = footer
        }
    }
    func makeSutraIndexButton(_ path:String, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        btn.setTitle(Book.data.itemOfPath(path)["name"] as! String?, for: UIControlState())
        btn.addTarget(self, action: #selector(SutraFrontViewController.onSutraIndexButtonTouchUp(_:)), for: .touchUpInside)
        let count = sutraIndexButtons.count;
        btn.tag = count
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;
        btn.setTitleColor(UIColor.black, for: UIControlState())
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        sutraIndexButtons.append(path)
        return btn;
    }
    
    func onSutraIndexButtonTouchUp(_ sender:UIButton){
        let path = sutraIndexButtons[sender.tag]
        self.openIndex(Book.data.itemOfPath(path))
    }
    
    func openRootIndex() {
        self.openIndex(Book.data.itemOfPath(""))
    }
    
    func openDrbaLink(_ sender:UIButton) {
//        let webView = UIWebView.init()
//        let webVC = UIViewController.init()
//        webVC.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "❬", style: .plain, target: self, action: #selector(SutraFrontViewController.close))//✕
//
//        webVC.view.addSubview(webView);
//        self.navigationController?.pushViewController(webVC, animated: true)
        
//        let webViewController = SVWebViewController(address: )

//        self.navigationController?.pushViewController(webViewController!, animated: true)
    UIApplication.shared.openURL(URL.init(string: "http://www.drbachinese.org/online_reading/sutra_explanation/Shu/contents.htm")!)
    }
    
    func close(){
        self.navigationController?.popViewController(animated: true)
    }
    
    func showList(){
        var firstLevelItems=[[String:Any]]();
        //            firstLevelItems.append(["name":"大佛頂如來密因修證了義諸菩薩萬行首楞嚴經","header":true]);
        //            for item in (Book.data.tree!["children"] as! NSArray) {
        //                firstLevelItems.append(item as! [String : Any]);
        //            }
        //            firstLevelItems.append(["name":"★精选","header":true]);
        let sortedLikes = KEY_PATHS;//Data.shared.likes.sort({$0 < $1})
        for like in sortedLikes {
            firstLevelItems.append(Book.data.itemOfPath(like))
        }
        self.tree = firstLevelItems;
        DispatchQueue.main.async{
            self.treeView.reloadData()
        }
    }
    
    
    //Called, when long press occurred
    func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == UIGestureRecognizerState.began {
            let touchPoint = longPressGestureRecognizer.location(in: self.treeView.scrollView)
            if let item = treeView.itemForRow(at: touchPoint) as? [String : Any] {
                openItem(item)
            }
        }
    }
    func openItem(_ item: [String : Any]){
        if(item["children"] == nil){
            if item["header"] == nil {
                openContent(item)
            }
        } else {
            openIndex(item);
        }
    }
    
    func openSutraOfPath(path:String){
        openSutra(Book.data.itemOfPath(path))
    }
    
    func openSutra(_ item: [String : Any]){
        let sutraVC = SutraPurePageContentViewController.init();
        sutraVC.item = item
        sutraVC.isShowIndexButton = true
        sutraVC.onDismiss = {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    func openContent(_ item: [String : Any]){
        let pageVC = SutraPageViewController.init( transitionStyle:.pageCurl,
                                                   navigationOrientation:.horizontal,
                                                   options: .none)
        let path:String = item["path"] as! String
        TICK()
        pageVC.page=Book.data.index!.index(where: { (
            item) -> Bool in
            return item["path"] == path
        })!;
        TOCK()
        
        
        self.navigationController?.pushViewController(pageVC, animated: true)
    }
    
    func openIndex(_ item: [String:Any]){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item;
        indexVC.defaultExpandLevel = 2;
        indexVC.onDismiss = {
//            self.showList()
        }
        
//        let navVC = UINavigationController.init(rootViewController: indexVC);
//        self.present(navVC, animated: true, completion: nil)
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    // MARK - RATreeView
    
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if(item == nil){
            return self.tree?.count ?? 0
        } else {
            return 0
        }
    }
    
    public func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        var newCell = treeView.dequeueReusableCell(withIdentifier: "indexCell") as? UITableViewCell;
        
        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.value1,reuseIdentifier:"indexCell");
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote);
            newCell!.textLabel?.font = UIFont .systemFont(ofSize: font.pointSize + 2, weight: UIFontWeightRegular);
        }
        let cell = newCell!;
        let item = item as! NSDictionary;
        let name = item["name"]! as? String
        
        cell.textLabel?.text =  name!;
        if(item["header"] != nil){
            cell.accessoryType = .none
            cell.backgroundColor =  UIColor.groupTableViewBackground
            //            cell.textLabel?.textColor = UIColor.darkTextColor()
        }else{
            //            cell.textLabel?.textColor = UIColor.init(red: 0, green: 0, blue:76/255, alpha: 0.8)//very darkblue
            cell.backgroundColor=UIColor.clear;
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    
    func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
        if(item != nil){
            return (item as! NSArray)[index]
        }else{
            return (self.tree?[index]) as Any
        }
    }
    
    
    func treeView(_ treeView:RATreeView, indentationLevelForRowForItem item:Any) -> Int{
        let path = (item as! [String:Any])["path"] as! String
        let level = path.components(separatedBy: "/").count
        return (level - 3)
    }
    
    func treeView(_ treeView:RATreeView,  didSelectRowForItem item:Any){
        self.treeView(treeView,accessoryButtonTappedForRowForItem: item);
    }
    
    func treeView(_ treeView:RATreeView,  accessoryButtonTappedForRowForItem item:Any){
        let item = item as! [String:Any];
        if(item["header"] == nil ){
            self.openSutra(item);
        }
    }
    
    func treeView(_ treeView:RATreeView,  commit editingStyle:UITableViewCellEditingStyle, forRowForItem item:Any){
        if (editingStyle == .delete) {
            let item = item as! NSDictionary as! [String:Any];
            Data.shared.unlike(item["path"] as! String)
            if let i = tree!.index(where: {$0["path"] as? String == item["path"] as? String }) {
                tree?.remove(at: i)
            }
            
            treeView.reloadData()
        }
    }
    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any] {
        return [Any]()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
