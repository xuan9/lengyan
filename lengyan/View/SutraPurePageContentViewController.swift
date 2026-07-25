//
//  SutraPurePageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/21.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class SutraPurePageContentViewController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {

    private struct TextPositionAnchor {
        let character: Int
        let lineDelta: CGFloat
    }

    private struct PendingTextLayoutPosition {
        let anchor: TextPositionAnchor?
        let contentOffset: CGPoint
    }

    var onDismiss: (() -> Void)?
    var isShowIndexButton = false;
    weak var parentReader: SutraPurePageViewController?

    var item:[String:Any]? = nil;
    var path:String? = nil;

    var sutraView: UITextView? = nil;
    private var lastContentOffset: CGFloat = 0
    private var lastLaidOutWidth: CGFloat = 0
    private var pendingTextLayoutPosition: PendingTextLayoutPosition?
    private var stableTextLayoutPosition: PendingTextLayoutPosition?

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
        let targetNavController = self.navigationController ?? self.parentReader?.navigationController ?? self.parent?.navigationController
        return targetNavController?.isNavigationBarHidden ?? false
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

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleContentTap))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        sutraTextView.addGestureRecognizer(tapGesture)

        self.sutraView = sutraTextView
    }
    
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        if abs(size.width - view.bounds.width) > 0.5 {
            captureTextPositionForPendingLayoutIfNeeded()
        }
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self else { return }
            if context.isCancelled
                || abs(self.view.bounds.width - self.lastLaidOutWidth) <= 0.5 {
                self.pendingTextLayoutPosition = nil
            }
        }
    }

    override func viewWillLayoutSubviews() {
        let newWidth = view.bounds.width
        if lastLaidOutWidth > 0,
           abs(newWidth - lastLaidOutWidth) > 0.5 {
            captureTextPositionForPendingLayoutIfNeeded()
        }
        super.viewWillLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 核心：让文字内容优雅地居中在 optimalReadingWidth 内，同时保持外层 textView 满屏
        let horizontalInset = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: view.bounds.width,
            containerHeight: view.bounds.height
        )
        sutraView?.textContainerInset = UIEdgeInsets(top: 12, left: horizontalInset, bottom: 24, right: horizontalInset)

        let newWidth = view.bounds.width
        let widthChanged = lastLaidOutWidth > 0
            && abs(newWidth - lastLaidOutWidth) > 0.5
        let pendingPosition = widthChanged ? pendingTextLayoutPosition : nil
        if widthChanged {
            // Consume the old-width anchor before layoutIfNeeded can re-enter
            // this method and mistake it for another resize.
            pendingTextLayoutPosition = nil
        }
        if newWidth > 0 {
            lastLaidOutWidth = newWidth
        }
        if let pendingPosition, let sutraView {
            sutraView.layoutIfNeeded()
            restoreTextPosition(
                anchor: pendingPosition.anchor,
                fallbackOffset: pendingPosition.contentOffset,
                in: sutraView
            )
        }
        updateStableTextPosition()
    }

    // 移除手动计算偏移量来隐藏标题栏的逻辑，
    // 因为这会和 iOS 系统底层的 contentInsetAdjustmentBehavior = .always 发生无限循环冲突，导致剧烈晃动。
    // 我们依赖 SutraPurePageViewController 中开启的系统级 hidesBarsOnSwipe = true 来完成丝滑隐藏。

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 🌿 获取最准确的导航栏隐藏状态。在 UIPageViewController 中，子控制器预加载时 self.navigationController 可能为空，
        // 此时我们通过 fallback 到 parentReader?.navigationController 或 parent?.navigationController 来获取真实的隐藏状态并将其同步，防止翻页时导航栏自动跳出。
        let targetNavController = self.navigationController ?? self.parentReader?.navigationController ?? self.parent?.navigationController
        let wasNavBarHidden = targetNavController?.isNavigationBarHidden ?? false
        if wasNavBarHidden {
            targetNavController?.setNavigationBarHidden(true, animated: false)
        }

        // UIPageViewController can deliver repeated appearance transitions while
        // preloading neighbours. Keep exactly one observer for each preference.
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .fontSizeDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeDidChangeEvent),
            name: .themeDidChange, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(fontSizeDidChangeEvent),
            name: .fontSizeDidChange, object: nil
        )
        refreshContentForCurrentPreferences()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .fontSizeDidChange, object: nil)
    }

    @objc public func themeDidChange() {
        themeDidChangeEvent()
    }

    @objc private func themeDidChangeEvent() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            self.sutraView?.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            // attributedText 的 foregroundColor 优先级高于 textColor，需重建整段文字
            self.refreshContentForCurrentPreferences()
        }, completion: nil)
    }

    @objc private func fontSizeDidChangeEvent() {
        refreshContentForCurrentPreferences()
        if let item {
            updateHeader(item)
        }
    }

    private func refreshContentForCurrentPreferences() {
        guard let item, let sutraView else { return }
        let anchor = visibleTextAnchor(in: sutraView)
        let previousOffset = sutraView.contentOffset
        sutraView.attributedText = Book.shared.getSutraAttributeString(item)
        view.layoutIfNeeded()

        let requestedY: CGFloat
        if let anchor, let anchoredY = contentOffsetY(for: anchor, in: sutraView) {
            requestedY = anchoredY
        } else {
            requestedY = previousOffset.y
        }
        restoreTextPosition(
            requestedY: requestedY,
            fallbackOffset: previousOffset,
            in: sutraView
        )
    }

    /// A character index is stable across typography changes; the small line
    /// delta keeps a partially visible first line at the same visual position.
    private func visibleTextAnchor(in textView: UITextView) -> TextPositionAnchor? {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        guard layoutManager.numberOfGlyphs > 0 else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let visibleTextY = textView.contentOffset.y
            + textView.adjustedContentInset.top
            - textView.textContainerInset.top
        let visibleRect = CGRect(
            x: 0,
            y: visibleTextY,
            width: max(textContainer.size.width, 1),
            height: max(textView.bounds.height, 1)
        )
        let visibleGlyphs = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        guard visibleGlyphs.location != NSNotFound else { return nil }
        let glyph = min(visibleGlyphs.location, layoutManager.numberOfGlyphs - 1)
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return TextPositionAnchor(
            character: character,
            lineDelta: lineRect.minY - visibleTextY
        )
    }

    private func contentOffsetY(
        for anchor: TextPositionAnchor,
        in textView: UITextView
    ) -> CGFloat? {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        guard layoutManager.numberOfGlyphs > 0, textView.textStorage.length > 0 else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let character = min(max(anchor.character, 0), textView.textStorage.length - 1)
        let glyph = min(
            layoutManager.glyphIndexForCharacter(at: character),
            layoutManager.numberOfGlyphs - 1
        )
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let visibleTextY = lineRect.minY - anchor.lineDelta
        return visibleTextY
            + textView.textContainerInset.top
            - textView.adjustedContentInset.top
    }

    private func restoreTextPosition(
        anchor: TextPositionAnchor?,
        fallbackOffset: CGPoint,
        in textView: UITextView
    ) {
        let requestedY = anchor.flatMap { contentOffsetY(for: $0, in: textView) }
            ?? fallbackOffset.y
        restoreTextPosition(
            requestedY: requestedY,
            fallbackOffset: fallbackOffset,
            in: textView
        )
    }

    private func restoreTextPosition(
        requestedY: CGFloat,
        fallbackOffset: CGPoint,
        in textView: UITextView
    ) {
        let minimumOffsetY = -textView.adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            textView.contentSize.height
                - textView.bounds.height
                + textView.adjustedContentInset.bottom
        )
        let restoredY = min(max(requestedY, minimumOffsetY), maximumOffsetY)
        textView.setContentOffset(
            CGPoint(x: fallbackOffset.x, y: restoredY),
            animated: false
        )
    }

    private func captureTextPositionForPendingLayoutIfNeeded() {
        guard pendingTextLayoutPosition == nil,
              let sutraView,
              sutraView.bounds.width > 0 else { return }
        // Autoresizing can change the text view before viewWillLayoutSubviews.
        // Prefer the last semantic position captured with known-stable geometry.
        pendingTextLayoutPosition = stableTextLayoutPosition
            ?? PendingTextLayoutPosition(
                anchor: visibleTextAnchor(in: sutraView),
                contentOffset: sutraView.contentOffset
            )
    }

    private func updateStableTextPosition() {
        guard pendingTextLayoutPosition == nil,
              lastLaidOutWidth > 0,
              abs(view.bounds.width - lastLaidOutWidth) <= 0.5,
              let sutraView,
              sutraView.bounds.width > 0 else { return }
        stableTextLayoutPosition = PendingTextLayoutPosition(
            anchor: visibleTextAnchor(in: sutraView),
            contentOffset: sutraView.contentOffset
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateStableTextPosition()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        parentReader?.confirmReadingInteraction()
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

    @objc func handleContentTap() {
        if parentReader?.isEmbedded == true { return } // 🌿 嵌套状态下由 SwiftUI 接管头部，不响应轻点切换导航栏
        guard let navController = self.navigationController else { return }
        let isHidden = navController.isNavigationBarHidden
        navController.setNavigationBarHidden(!isHidden, animated: true)
        
        UIView.animate(withDuration: 0.2) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 🌿 如果另一个手势是拖动/滚动手势（UIPanGestureRecognizer），则不允许同时识别，防止滑动翻页时误触发“轻点显示/隐藏导航栏”
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }
}
