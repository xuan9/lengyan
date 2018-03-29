//
//  SutraPurePageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/21.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageContentViewController: UIViewController {
    
    var onDismiss: (() -> Void)?
    var isShowIndexButton = false;
    
    var item:[String:Any]? = nil;
    var path:String? = nil;
    
    var sutraView: UITextView? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        view.backgroundColor = UIColor.white

        if item == nil {
            item = Book.data.itemOfPath(path!)
        } else {
            path = (item!["path"]! as! String);
        }
        
        self.addSutra(self.item!);
        updateHeader(item!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    func addSutra(_ meta:[String:Any]){
        let sutraTextView = UITextView();
        sutraTextView.isSelectable = true;
        sutraTextView.isScrollEnabled = true;
        sutraTextView.isEditable = false;
        sutraTextView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        sutraTextView.backgroundColor = UIColor.white
        sutraTextView.textColor = UIColor.darkText
        //        if (meta["children"] == nil) {
        //            item = meta;
        //            let meta = Book.data.parentOfItem(meta)!;
        //            path = (meta["path"]! as! String);
        //            addSutra(meta);
        //            return;
        //        } else {
        //            beforePageIndex = pageIndex - 1;
        //        }
        //        

        //        scrollToItem(item != nil ? item! : meta, text: text);
        let text = Book.data.getSutraAttributeString(meta);
        sutraTextView.attributedText = text;
        view.addSubview(sutraTextView);
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            sutraTextView.bindFrameToSuperviewBounds(paddingHorizontal:44, paddingVertical: 10)
        } else {
            sutraTextView.bindFrameToSuperviewBounds(paddingHorizontal:2, paddingVertical: 0)
        }
        self.sutraView = sutraTextView;
    }
    override func viewDidLayoutSubviews() {
        self.sutraView?.setContentOffset(.zero, animated:false);
    }
    /*
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
     */
    
    

    
    
    func updateHeader(_ item:[String:Any]){
        //        self.title = item["name"] as? String ?? ""
        self.navigationItem.titleView = Book.data.getTitleView(item);
        
//        self.navigationController?.navigationBar.isTranslucent = false;
        
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "  ❬   ", style: .plain, target: self, action: #selector(close))
        
//        self.updateStarButton()
//        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.darkText
    }
    

    
    
    @objc func close(){
        let topBarView = UIView(frame: CGRect(
            origin: CGPoint(x:0 ,y:0 ),
            size:   CGSize(width: view.bounds.size.width , height:60 )));
        topBarView.backgroundColor = UIColor.white
        view.addSubview(topBarView)
        
        onDismiss?();
        self.navigationController?.popViewController(animated: true);
    }
}
