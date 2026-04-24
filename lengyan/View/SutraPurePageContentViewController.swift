//
//  SutraPurePageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/21.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageContentViewController: UIViewController, UITextViewDelegate {

    var onDismiss: (() -> Void)?
    var isShowIndexButton = false;

    var item:[String:Any]? = nil;
    var path:String? = nil;

    var sutraView: UITextView? = nil;
    private var lastContentOffset: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)

        if item == nil {
            item = Book.shared.itemOfPath(path!)
        } else {
            path = (item!["path"]! as! String);
        }

        self.addSutra(self.item!);
        updateHeader(item!)
    }

    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    func addSutra(_ meta:[String:Any]){
        let sutraTextView = UITextView()
        sutraTextView.isSelectable = true
        sutraTextView.isScrollEnabled = true
        sutraTextView.isEditable = false
        sutraTextView.delegate = self

        // 🏛️ 禅意经文排版
        sutraTextView.font = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        sutraTextView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        sutraTextView.textColor = SutraDesignTokens.shared.color(for: .sutraText)

        // 增加上下呼吸空间，无缝衔接
        sutraTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12)

        // 移除 iOS 自动调整 insets 的限制，因为我们现在使用了 .scroll 翻页，不再有 pageCurl 的跳动 bug
        // 让系统帮我们处理刘海/灵动岛的距离
        sutraTextView.contentInsetAdjustmentBehavior = .always

        let text = Book.shared.getSutraAttributeString(meta)
        sutraTextView.attributedText = text
        view.addSubview(sutraTextView)

        sutraTextView.translatesAutoresizingMaskIntoConstraints = false
        
        let guide = view.safeAreaLayoutGuide
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            NSLayoutConstraint.activate([
                sutraTextView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 44),
                sutraTextView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -44),
                sutraTextView.topAnchor.constraint(equalTo: view.topAnchor),
                sutraTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                sutraTextView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
                sutraTextView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
                sutraTextView.topAnchor.constraint(equalTo: view.topAnchor),
                sutraTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        self.sutraView = sutraTextView
    }

    // 移除手动计算偏移量来隐藏标题栏的逻辑，
    // 因为这会和 iOS 系统底层的 contentInsetAdjustmentBehavior = .always 发生无限循环冲突，导致剧烈晃动。
    // 我们依赖 SutraPurePageViewController 中开启的系统级 hidesBarsOnSwipe = true 来完成丝滑隐藏。

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 在页面即将出现时将滚动位置重置为顶部，避免在 viewDidLayoutSubviews 中频繁触发导致跳动
        self.sutraView?.setContentOffset(.zero, animated: false)
    }

    func updateHeader(_ item:[String:Any]){
        self.navigationItem.titleView = Book.shared.getTitleView(item);
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
