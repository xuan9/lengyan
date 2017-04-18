//
//  SutraPurePageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/21.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageContentViewController: UIViewController,SutraPage {
    
    var pageIndex = 0;
    var item:[String:Any]? = nil;
    var path:String? = nil;
    var nextPageIndex = -1;
    var beforePageIndex = -1;
    var sutraTextView: UITextView = UITextView.init();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let size = view.frame.size;
        sutraTextView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height - (navigationController?.navigationBar.height ?? 0));
        view.addSubview(sutraTextView)
        sutraTextView.isSelectable = true;
        sutraTextView.isScrollEnabled = true;
        sutraTextView.isEditable = false;
        sutraTextView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        sutraTextView.backgroundColor = UIColor.white
        sutraTextView.textColor = UIColor.darkText
        if item == nil {
            let meta = (Book.data.index?[pageIndex])!;
            path = (meta["path"]! as String);
            item = Book.data.itemOfPath(path!)
        } else {
            path = (item!["path"]! as! String);
        }
        
        addSutra(item!);
        updateHeader(item!)
    }
    
    
    func addSutra(_ meta:[String:Any]){
        
        if (meta["children"] == nil) {
            item = meta;
            let meta = Book.data.parentOfItem(meta)!;
            path = (meta["path"]! as! String);
            addSutra(meta);
            return;
        } else {
            beforePageIndex = pageIndex - 1;
        }
        
        if(nextPageIndex == -1){
            if(meta["path"]! as! String == item!["path"]! as! String){
                nextPageIndex = pageIndex + 1 ;
            }
        } else {
            nextPageIndex = nextPageIndex + 1;
        }
        
        sutraTextView.attributedText = Book.data.getSutraAttributeString(meta);
        //        scrollToItem(item != nil ? item! : meta, text: text);
    }
    
    
    func scrollToItem(_ item:[String:Any], text:String){
        if (item["children"] == nil) {
            let content = Book.data.contents?[item["path"] as! String];
            if content != nil {
                for c in content! {
                    if c["type"] == "sutra" {
                        let sutra = c["content"]!
                        let range = NSString(string:text).range(of: sutra);
                        sutraTextView.selectedRange = range;
                        //                        let rect = sutraTextView.firstRectForRange( sutraTextView.selectedTextRange!);
                        sutraTextView.scrollRangeToVisible(range);
                    }
                }
            }
        } else {
            sutraTextView.scrollsToTop = true;
            //            sutraTextView.scrollRangeToVisible(NSRange.init(location: 1, length: 1));
        }
        
    }
    
    
    func getNextPageIndex()->Int{
        return nextPageIndex;
    }
    func getBeforePageIndex()->Int{
        return beforePageIndex;
    }
    
    func updateHeader(_ item:[String:Any]){
        //        self.title = item["name"] as? String ?? ""
        self.navigationItem.titleView = Book.data.getTitleView(item);
        
        self.navigationController?.navigationBar.isTranslucent = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "❬", style: .plain, target: self, action: #selector(SutraIndexViewController.close))
        self.updateStarButton()
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.darkText
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.darkText
        
    }
    func updateStarButton(){                if(Data.shared.likes.contains(path!)){
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"★", style: .plain, target: self, action: #selector(SutraPageViewController.unlike))
    } else {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"☆", style: .plain, target: self, action: #selector(SutraPageViewController.like))
        }
    }
    
    func like() {
        Data.shared.like(self.path!)
        self.updateStarButton()
    }
    
    func unlike() {
        Data.shared.unlike(self.path!)
        self.updateStarButton()
    }
    
    
    func close(){
        self.navigationController?.popViewController(animated: true);
    }
}
