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
    var sutraView: UITextView? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        self.addSutra(sutra: Book.shared.getChapterSutra(chapter: self.pageIndex));
        updateHeader()
    }

    func updateTheme(_ theme: SutraTheme) {
        // Implementation for theme update if needed
    }

    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    func addSutra(sutra:String){
        let sutraTextView = UITextView()
        sutraTextView.isSelectable = true
        sutraTextView.isScrollEnabled = true
        sutraTextView.isEditable = false

        // 🏛️ 禅意经文排版
        sutraTextView.font = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        sutraTextView.backgroundColor = SutraDesignTokens.shared.color(for: .surface)   // 层次感
        sutraTextView.textColor = SutraDesignTokens.shared.color(for: .sutraText)

        // 增加上下呼吸空间
        sutraTextView.textContainerInset = UIEdgeInsets(top: 24, left: 4, bottom: 24, right: 4)

        let text = Book.shared.getSutraAttributeString(text: sutra)
        sutraTextView.attributedText = text
        view.addSubview(sutraTextView)

        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            sutraTextView.bindFrameToSuperviewBounds(paddingHorizontal: 44, paddingVertical: 10)
        } else {
            sutraTextView.bindFrameToSuperviewBounds(paddingHorizontal: 20, paddingVertical: 0)
        }
        self.sutraView = sutraTextView
    }
    override func viewDidLayoutSubviews() {
        self.sutraView?.setContentOffset(.zero, animated:false);
    }
    
    func updateHeader(){
        self.navigationItem.title = NSLocalizedString("chapter_\(self.pageIndex + 1)", comment: "chapter_name")
        
        self.navigationController?.navigationBar.isTranslucent = false;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "  ❬   ", style: .plain, target: self, action: #selector(close))
        
        self.navigationItem.leftBarButtonItem?.tintColor = SutraDesignTokens.shared.color(for: .textPrimary)
    }
    
    @objc func close(){
        let topBarView = UIView(frame: CGRect(
            origin: CGPoint(x:0 ,y:0 ),
            size:   CGSize(width: view.bounds.size.width , height:60 )));
        topBarView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        view.addSubview(topBarView)
        
        onDismiss?();
        self.navigationController?.popViewController(animated: true);
    }
}

