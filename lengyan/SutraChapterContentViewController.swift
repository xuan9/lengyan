//
//  SutraChapterContentViewController.swift
//  lengyan
//
//  Created by Xuan on 2018/3/20.
//  Copyright © 2018年 xuan. All rights reserved.
//

import UIKit

class SutraChapterContentViewController: UIViewController, SutraPage {
    
    var onDismiss: (() -> Void)?
    var pageIndex = 0;
    var isShowIndexButton = false;
    var nextPageIndex = -1;
    var beforePageIndex = -1;
    
    var sutraView: UITextView? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        view.backgroundColor = UIColor.white
        
        self.addSutra(sutra: Book.data.getChapterSutra(chapter: self.pageIndex));
        updateHeader()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    //    override func viewDidAppear(_ animated: Bool) {
    //        Data.shared.logItemOpened(path)
    //    }
    //    override func viewDidDisappear(_ animated: Bool) {
    //        Data.shared.logItemClosed(path)
    //    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    }
    
    func addSutra(sutra:String){
        let sutraTextView = UITextView();
        sutraTextView.isSelectable = true;
        sutraTextView.isScrollEnabled = true;
        sutraTextView.isEditable = false;
        sutraTextView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        sutraTextView.backgroundColor = UIColor.white
        sutraTextView.textColor = UIColor.darkText
        let text = Book.data.getSutraAttributeString(text: sutra);
        sutraTextView.attributedText = text;
        view.addSubview(sutraTextView);
        sutraTextView.bindFrameToSuperviewBounds();
        self.sutraView = sutraTextView;
    }
    override func viewDidLayoutSubviews() {
        self.sutraView?.setContentOffset(.zero, animated:false);
    }
    
    func getNextPageIndex()->Int{
        if(nextPageIndex == -1){
            nextPageIndex = pageIndex + 1 ;
        } else if(nextPageIndex<9){
            nextPageIndex = nextPageIndex + 1;
        } else {
            nextPageIndex = 0
        }
        
        return nextPageIndex;
    }
    func getBeforePageIndex()->Int{
        return pageIndex - 1;
    }
    
    func updateHeader(){
        self.navigationItem.title = NSLocalizedString("chapter_\(self.pageIndex + 1)", comment: "chapter_name")
        
        self.navigationController?.navigationBar.isTranslucent = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "  ❬   ", style: .plain, target: self, action: #selector(SutraPurePageContentViewController.close))
        
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.darkText
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

