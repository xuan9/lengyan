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
        
        // 彻底禁用水平滚动，解决左右滑动和翻页手势冲突的问题
        sutraTextView.showsHorizontalScrollIndicator = false
        sutraTextView.alwaysBounceHorizontal = false
        sutraTextView.isDirectionalLockEnabled = true

        // 🏛️ 禅意经文排版
        sutraTextView.font = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        sutraTextView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        sutraTextView.textColor = SutraDesignTokens.shared.color(for: .sutraText)

        // 增加基础上下呼吸空间，左右边距将在 viewDidLayoutSubviews 中动态计算
        sutraTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12)

        // 恢复系统默认的 safeArea 适配机制，保护灵动岛和底部 Home Indicator 不被文字遮挡
        sutraTextView.contentInsetAdjustmentBehavior = .always

        let text = Book.shared.getSutraAttributeString(meta)
        sutraTextView.attributedText = text
        view.addSubview(sutraTextView)

        sutraTextView.translatesAutoresizingMaskIntoConstraints = false

        // 核心：让 textView 撑满屏幕边缘，以确保手势滑动和滚动条都在屏幕边缘
        NSLayoutConstraint.activate([
            sutraTextView.topAnchor.constraint(equalTo: view.topAnchor),
            sutraTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sutraTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sutraTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.sutraView = sutraTextView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 核心：让文字内容优雅地居中在 optimalReadingWidth 内，同时保持外层 textView 满屏
        let horizontalInset = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: view.bounds.width
        )
        sutraView?.textContainerInset = UIEdgeInsets(top: 12, left: horizontalInset, bottom: 24, right: horizontalInset)
    }

    // 移除手动计算偏移量来隐藏标题栏的逻辑，
    // 因为这会和 iOS 系统底层的 contentInsetAdjustmentBehavior = .always 发生无限循环冲突，导致剧烈晃动。
    // 我们依赖 SutraPurePageViewController 中开启的系统级 hidesBarsOnSwipe = true 来完成丝滑隐藏。

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 重置滚动位置时保留导航栏状态，防止 setContentOffset 触发 hidesBarsOnSwipe 导致导航栏跳出
        let wasNavBarHidden = navigationController?.isNavigationBarHidden ?? false
        if wasNavBarHidden {
            navigationController?.setNavigationBarHidden(true, animated: false)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(themeDidChangeEvent),
            name: .themeDidChange, object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
    }

    @objc private func themeDidChangeEvent() {
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        sutraView?.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        // attributedText的foregroundColor优先级高于textColor，需重建整段文字
        if let item = item {
            sutraView?.attributedText = Book.shared.getSutraAttributeString(item)
        }
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
