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
    internal var tree:[[String]]?;
    fileprivate var sutraIndexButtons = [String]();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bounds:CGRect = self.view.bounds;
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 5 ,y:bounds.origin.y + 0),
            size:   CGSize(width: bounds.size.width + 8 , height:bounds.size.height - 0 )));
        
        
        treeView.delegate = self
        treeView.dataSource = self
        treeView.rowHeight = 30;
        treeView.backgroundColor = UIColor.white
        view.backgroundColor = UIColor.white
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        view.addSubview(treeView)
        
        self.setupHeaderView(self.view.bounds.size)
        self.showList()
        self.setupFooterView(self.view.bounds.size)
        
        let title = self.makeSutraIndexButton("", frame: CGRect(x: 3, y: 0, width: self.view.bounds.width - 3, height: 40));
        self.navigationItem.titleView = title;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.hidesBarsOnSwipe = false;
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupHeaderView(size)
        setupFooterView(size)
    }
    
    func setupHeaderView(_ size:CGSize) {
        let width = size.width
        
        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: 18 + 90 + 10))
        let indexes = UIView(frame: CGRect(x: 0, y: 20, width: width, height: 88));
        let chapterButtonWidth=(width - 20)/5;
        for i in 1...10 {
            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: Int(10 + Float(chapterButtonWidth) * Float((i>5 ? i - 5 : i) - 1)), y: i<6 ? 0 : 44, width: Int(chapterButtonWidth), height: 44));
            indexes.addSubview(btn);
        }
        let subTitle = UIButton.init(type: .custom);
        subTitle.frame = CGRect(x: 12, y: 5, width: width-10, height: 15);
        let subTitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subTitle.setTitle(subTitleText, for: UIControlState())
        subTitle.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        subTitle.titleLabel!.adjustsFontSizeToFitWidth = true;
        subTitle.setTitleColor(UIColor.darkGray, for: UIControlState())
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)
        header.addSubview(indexes)
        
        
        let px = 1 / UIScreen.main.scale
        let frame = CGRect(x: 0, y: header.frame.height - px, width: self.treeView.frame.size.width, height: px)
        let line: UIView = UIView(frame: frame)
        line.backgroundColor = self.treeView.separatorColor
        header.addSubview(line)
        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width

        let footerSeperator = UIView(frame: CGRect(x: 0, y: 2, width: width - 10, height: 1))
        footerSeperator.backgroundColor = UIColor.lightGray
        
        let footerText1 = NSLocalizedString("footer_txt_1", comment: "南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩")
        let footerText2 = NSLocalizedString("footer_txt_2", comment: "經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站")
        let footerText3 = NSLocalizedString("footer_txt_3", comment: "感恩法界佛教總會！本屏中列出部分關鍵科判以方便檢索，可點擊經名打開完整科判。")
        let footerLabel = UILabel(frame: CGRect(x: 20, y: 10, width: width - 20, height: 60))
        footerLabel.text = footerText1
        footerLabel.numberOfLines = 3
        footerLabel.textAlignment = .center
        footerLabel.font = UIFont.systemFont(ofSize: 14)
        footerLabel.adjustsFontSizeToFitWidth = true;
        
        let linkButton = UIButton(frame: CGRect(x: 10, y: 70, width: width - 30, height: 20))
        linkButton.setTitle(footerText2, for: .normal)
        linkButton.contentHorizontalAlignment = .center
        linkButton.setImage(UIImage.init(named: "ic_link")?.withRenderingMode(.alwaysTemplate), for: .normal)
        linkButton.addTarget(self, action: #selector(self.openDrbaLink(_:)), for: .touchUpInside)
        linkButton.semanticContentAttribute = .forceRightToLeft
        linkButton.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        linkButton.titleLabel?.adjustsFontSizeToFitWidth = true;
        linkButton.setTitleColor(UIColor.darkText, for: .normal)
        linkButton.backgroundColor = UIColor.white
        linkButton.tintColor = UIColor.darkText
        
        let footerLabel2 = UILabel(frame: CGRect(x: 10, y: 85, width: width - 20, height: 40))
        footerLabel2.text = footerText3
        footerLabel2.textAlignment = .center
        footerLabel2.numberOfLines = 3
        footerLabel2.font = UIFont.systemFont(ofSize: 10)
        footerLabel2.adjustsFontSizeToFitWidth = true;
        
        let footer:UIView = UIView(frame: CGRect(x: 5, y: 2, width: width - 20, height: 140))
        footer.backgroundColor = UIColor.white
        footer.addSubview(footerSeperator)
        footer.addSubview(footerLabel)
        footer.addSubview(linkButton)
        footer.addSubview(footerLabel2)
        self.treeView.treeFooterView = footer
    }
    func makeSutraChapterButton(_ chapter:Int, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        btn.setTitle(NSLocalizedString("chapter_\(chapter+1)", comment: "chapter_name"), for: UIControlState())
        btn.addTarget(self, action: #selector(onSutraChapterButtonTouchUp(_:)), for: .touchUpInside)
        btn.tag = chapter
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;
        btn.setTitleColor(UIColor.black, for: UIControlState())
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return btn;
    }
    
    func makeSutraIndexButton(_ path:String, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        btn.setTitle(Book.shared.itemOfPath(path)["name"] as! String?, for: UIControlState())
        btn.addTarget(self, action: #selector(onSutraIndexButtonTouchUp(_:)), for: .touchUpInside)
        let count = sutraIndexButtons.count;
        btn.tag = count
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;
        btn.setTitleColor(UIColor.black, for: UIControlState())
        btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
        sutraIndexButtons.append(path)
        return btn;
    }
    
    @objc func onSutraIndexButtonTouchUp(_ sender:UIButton){
        let path = sutraIndexButtons[sender.tag]
        self.openIndex(Book.shared.itemOfPath(path))
    }
    
    @objc func onSutraChapterButtonTouchUp(_ sender:UIButton){
        let chapter = sender.tag
        self.openChapter(chapter: chapter);
    }
    
    
    @objc func openRootIndex() {
        self.openIndex(Book.shared.itemOfPath(""))
    }
    
    @objc func openDrbaLink(_ sender:UIButton) {
        UIApplication.shared.openURL(URL.init(string: "http://www.drbachinese.org/online_reading/sutra_explanation/Shu/contents.htm")!)
    }
    
    func close(){
        self.navigationController?.popViewController(animated: true)
    }
    
    func showList(){
        self.tree = Book.shared.getKeyItems();
        self.treeView.reloadData()
    }
    
    
    //Called, when long press occurred
    @objc func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
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
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        sutraVC.path = path
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
        // TICK()
        pageVC.page=Book.shared.index!.index(where: { (
            item) -> Bool in
            return item["path"] == path
        })!;
        // TOCK()
        
        
        self.navigationController?.pushViewController(pageVC, animated: true)
    }
    
    func openIndex(_ item: [String:Any]){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item;
        indexVC.defaultExpandLevel = 2;
        indexVC.onDismiss = {
            } as (() -> Void)
        
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    func openChapter(chapter:Int){
        let pageVC = SutraChapterPageViewController.init( transitionStyle:.pageCurl,
                                                   navigationOrientation:.horizontal,
                                                   options: .none)
        pageVC.pageIndex = chapter;
        self.navigationController?.pushViewController(pageVC, animated: true)
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
            newCell!.textLabel?.font = UIFont .systemFont(ofSize: font.pointSize + 2, weight: UIFont.Weight.regular);
        }
        let cell = newCell!;
        let item = item as! [String];
        let name = item[1];
        let chapterStartIndex = CHAPTER_START_PATHS.index(of: item[0]);
        if chapterStartIndex != nil {
            cell.textLabel?.attributedText = Book.shared.getItemName(name, withChapter: chapterStartIndex!);
        }else {
            cell.textLabel?.text =  name
        }
        cell.backgroundColor=UIColor.clear;
        cell.accessoryType = .disclosureIndicator
        
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
        let path = (item as! [String])[0]
        let level = path.components(separatedBy: "/").count
        return (level - 2)
    }
    
    func treeView(_ treeView:RATreeView,  didSelectRowForItem item:Any){
        self.treeView(treeView,accessoryButtonTappedForRowForItem: item);
    }
    
    func treeView(_ treeView:RATreeView,  accessoryButtonTappedForRowForItem item:Any){
        let item = item as! [String];
        self.openSutraOfPath(path: item[0])
    }
    
    func treeView(_ treeView:RATreeView,  commit editingStyle:UITableViewCellEditingStyle, forRowForItem item:Any){
    }
    
    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any] {
        return [Any]()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
