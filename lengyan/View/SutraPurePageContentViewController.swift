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

        // 阻止 iOS 自动调整 insets，防止在翻页动画中出现偏移跳动
        sutraTextView.contentInsetAdjustmentBehavior = .never

        let text = Book.shared.getSutraAttributeString(meta)
        sutraTextView.attributedText = text
        view.addSubview(sutraTextView)

        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            sutraTextView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                sutraTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
                sutraTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -44),
                sutraTextView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
                sutraTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            ])
        } else {
            sutraTextView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                sutraTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                sutraTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                sutraTextView.topAnchor.constraint(equalTo: view.topAnchor),
                sutraTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        self.sutraView = sutraTextView
    }

    // MARK: - UITextViewDelegate — 手动跟踪滚动方向控制导航栏

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset.y
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        let delta = currentOffset - lastContentOffset

        // 下拉 → 显示导航栏
        if delta < -30 {
            navigationController?.setNavigationBarHidden(false, animated: true)
        }
        // 上滑 → 隐藏导航栏
        else if delta > 30 {
            navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }

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
