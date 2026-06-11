//
//  SutraFrontViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/2.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class SutraFrontViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    fileprivate var treeView: RATreeView!
    internal var tree:[[String]]?;
    fileprivate var sutraIndexButtons = [String]();
    
    override func viewDidLoad() {
        super.viewDidLoad()

        print("🔥 === SUTRA FRONT VIEW LOADING ===")
        print("🔥 viewDidLoad() - view.bounds: \(self.view.bounds)")

        // Apply Zen Temple Serenity Design System FIRST
        applyZenTempleSerenityDesignSystem()
        print("🔥 Design system applied")

        // Setup theme observer for dynamic theme changes
        setupThemeObserverForView()
        print("🔥 Theme observer setup")

        let bounds:CGRect = self.view.bounds;
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 5 ,y:bounds.origin.y + 0),
            size:   CGSize(width: bounds.size.width + 8 , height:bounds.size.height - 0 )));
        print("🔥 TreeView created with frame: \(treeView.frame)")

        treeView.delegate = self
        treeView.dataSource = self
        treeView.rowHeight = max(44, SutraDesignTokens.shared.responsiveSpacing(44))
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        view.addSubview(treeView)
        print("🔥 TreeView added to view hierarchy")

        self.setupHeaderView(self.view.bounds.size)
        print("🔥 Header setup complete")

        self.showList()
        print("🔥 ShowList complete")

        self.setupFooterView(self.view.bounds.size)
        print("🔥 Footer setup complete")

        // 经题已移入 header 内容区，无需 navigationItem.titleView
        print("🔥 === VIEW SETUP COMPLETE ===")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 先隐藏导航栏，避免黄色闪现
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.navigationController?.hidesBarsOnSwipe = false

        // Refresh design system on appearance
        applyZenTempleSerenityDesignSystem()

        // Rebuild header to refresh "续读" text with latest reading progress
        setupHeaderView(self.view.bounds.size)

        // 设置导航栏外观（隐藏状态下设置，供子页面返回时使用）
        let navColor = SutraDesignTokens.shared.color(for: .navigationBar)
        if let navBar = self.navigationController?.navigationBar {
            navBar.isTranslucent = false
            navBar.backgroundColor = navColor
            navBar.barTintColor = navColor
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = navColor
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [
                .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary),
                .font: SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .medium)
            ]
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.compactAppearance = appearance
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 确保首页导航栏完全隐藏
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        // 禁用残留的手势识别器，防止点击/滑动弹出空白导航栏吞掉首次点击事件。
        // 子页面（阅读页）会在各自的 viewWillAppear 中重新启用。
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = false
        self.navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开首页时恢复导航栏，供阅读页/索引页使用
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // Deprecated: Floating theme switch button removed for a calmer, unified front view.
    private func addThemeSwitchingButton() {
        let themeButton = UIButton(type: .system)
        themeButton.setTitle("🎨", for: .normal)
        themeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        themeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeButton)

        NSLayoutConstraint.activate([
            themeButton.widthAnchor.constraint(equalToConstant: 44),
            themeButton.heightAnchor.constraint(equalToConstant: 44),
            themeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            themeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        // Use semantic navigation colors
        themeButton.setTitleColor(SutraDesignTokens.shared.color(for: .navigationBar), for: .normal)
        themeButton.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        themeButton.layer.cornerRadius = 22
        themeButton.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
        themeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        themeButton.layer.shadowOpacity = 0.2
        themeButton.layer.shadowRadius = 4

        themeButton.addTarget(self, action: #selector(themeButtonTapped), for: .touchUpInside)
    }

    @objc private func themeButtonTapped() {
        // Use animated theme cycling (borrowed from SutraDesignSystem)
        SutraDesignTokens.shared.cycleToNextTheme()

        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Refresh the UI with current design tokens
        applyZenTempleSerenityDesignSystem()
    }

    // MARK: - Zen Temple Serenity Design System Application
    private func applyZenTempleSerenityDesignSystem() {
        print("🏛️ APPLYING ZEN TEMPLE SERENITY DESIGN SYSTEM")

        // Apply theme colors and background
        applyThemeColorsToView()
        setupThemeObserverForView()

        // Configure tree view with design system
        configureTreeViewWithDesignSystem()

        print("✅ ZEN TEMPLE SERENITY DESIGN SYSTEM APPLIED")
    }

    private func applyThemeColorsToView() {
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
    }

    private func setupThemeObserverForView() {
        // TODO: Add theme observer if needed
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChangeForFrontViewController), name: .themeDidChange, object: nil)
    }

    @objc private func themeDidChangeForFrontViewController() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.applyThemeColorsToView()
            self.configureTreeViewWithDesignSystem()
            self.setupHeaderView(self.view.bounds.size)
            self.setupFooterView(self.view.bounds.size)
        }, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTreeViewWithDesignSystem() {
        // Guard against treeView not being initialized yet (can happen during early notification calls)
        guard let treeView = treeView else { return }

        let bgColor = SutraDesignTokens.shared.color(for: .background)
        treeView.backgroundColor = bgColor
        treeView.rowHeight = max(44, SutraDesignTokens.shared.responsiveSpacing(44))
        treeView.separatorStyle = RATreeViewCellSeparatorStyleNone
    }

    private func setupZenBackgroundGradient() {
        // Remove any existing background views
        for subview in view.subviews {
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }

        // Create zen gradient background using unified color system
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.tag = 999
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = backgroundView.bounds

        // Use semantic colors from design system
        let bgColor = SutraDesignTokens.shared.color(for: .background)
        let surfaceColor = SutraDesignTokens.shared.color(for: .surface)

        gradientLayer.colors = [
            bgColor.cgColor,
            surfaceColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.2, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.8, y: 1)
        gradientLayer.locations = [0.0, 0.6, 1.0]

        backgroundView.layer.addSublayer(gradientLayer)
        view.insertSubview(backgroundView, at: 0)
    }

    private func setupZenTreeViewStyling() {
        treeView.backgroundColor = .clear

        // Simple approach - only use what we know works
        // The crash is caused by KVC on properties that don't exist or expect different types
        // So we'll keep it minimal and safe

        treeView.rowHeight = max(44, SutraDesignTokens.shared.responsiveSpacing(50))
    }

    // Deprecated: Legacy recursive chapter button restyling removed to rely on makeSutraChapterButton styling.
    private func enhanceChapterButtons() {
        // Find all chapter buttons and enhance them
        for subview in view.subviews {
            if subview is RATreeView {
                for cellSubview in subview.subviews {
                    enhanceButtonsInView(cellSubview)
                }
            }
        }
    }

    private func enhanceButtonsInView(_ view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                // Comprehensive zen enhancement for all buttons
                enhanceButtonWithCompleteZenStyling(button)
            }
            enhanceButtonsInView(subview)
        }
    }

    private func enhanceButtonWithCompleteZenStyling(_ button: UIButton) {
        let buttonText = button.titleLabel?.text ?? ""

        // 🏯 Sacred Temple Styling - 神圣寺庙样式
        if buttonText.contains("卷") || buttonText.contains("品") {
            // Chapter button - golden sacred temple styling
            button.backgroundColor = SutraDesignTokens.shared.color(for: .card)
            button.setTitleColor(SutraDesignTokens.shared.color(for: .chapterTitle), for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .bold)

            // Sacred temple styling with enhanced visual impact
            button.layer.cornerRadius = 20
            button.layer.borderWidth = 3
            button.layer.borderColor = SutraDesignTokens.shared.color(for: .bookmark).cgColor  // 鎏金边框
            button.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8
            button.layer.shadowOpacity = 0.3

            // Add sacred gradient background
            addSacredGradientToButton(button)

        } else if buttonText.contains("楞嚴經") || buttonText.contains("首楞嚴經") {
            // Main title - divine sutra title styling
            button.backgroundColor = .clear
            button.setTitleColor(SutraDesignTokens.shared.color(for: .sutraText), for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .heavy)
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.numberOfLines = 0

            // Add enhanced divine glow effect with multiple layers
            addDivineGlowToTitle(button)

        } else {
            // Other buttons - elegant zen styling
            button.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
            button.setTitleColor(SutraDesignTokens.shared.color(for: .textSecondary), for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = SutraDesignTokens.shared.color(for: .border).cgColor
            button.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.2
        }

        // Enhanced touch feedback for all buttons
        enhanceButtonTouchFeedback(button)
    }

    private func addSacredGradientToButton(_ button: UIButton) {
        // Remove existing gradient if any
        button.layer.sublayers?.removeAll { $0 is CAGradientLayer }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = button.bounds

        // 🌅 Enhanced Sacred gradient with multiple divine colors
        let sacredGold = SutraDesignTokens.shared.color(for: .bookmark)  // 鎏金色
        let divineLight = SutraDesignTokens.shared.color(for: .surface)   // 佛光色
        let pureWhite = SutraDesignTokens.shared.color(for: .card)       // 纯净色
        let zenGreen = SutraDesignTokens.shared.color(for: .primary)      // 竹翠绿

        // Multi-stop gradient for divine effect
        gradientLayer.colors = [
            pureWhite.cgColor,
            divineLight.cgColor,
            sacredGold.withAlphaComponent(0.4).cgColor,
            zenGreen.withAlphaComponent(0.2).cgColor,
            pureWhite.cgColor
        ]

        // Enhanced gradient animation
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.locations = [0.0, 0.3, 0.5, 0.7, 1.0]
        gradientLayer.cornerRadius = button.layer.cornerRadius

        // Replace existing background if present
        if let sublayers = button.layer.sublayers,
           let existingLayer = sublayers.first(where: { $0 is CAGradientLayer }) {
            existingLayer.removeFromSuperlayer()
        }

        button.layer.insertSublayer(gradientLayer, at: 0)
        button.clipsToBounds = true
    }

    private func enhanceButtonTouchFeedback(_ button: UIButton) {
        // Preserve existing touch targets (like onSutraChapterButtonTouchUp)
        // Add zen-style touch feedback
        button.addTarget(self, action: #selector(zenButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(zenButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(zenButtonTapped(_:)), for: .touchUpInside)
    }

    @objc private func zenButtonTouchDown(_ button: UIButton) {
        // Enhanced sacred touch down animation
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            button.alpha = 0.85

            // Enhanced sacred glow effect on touch
            button.layer.shadowRadius = 12
            button.layer.shadowOpacity = 0.4
            button.layer.shadowColor = SutraDesignTokens.shared.color(for: .bookmark).cgColor
        }

        // Haptic feedback for sacred interaction
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    @objc private func zenButtonTouchUp(_ button: UIButton) {
        // Enhanced sacred touch up animation with bounce
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.curveEaseOut]) {
            button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            button.alpha = 1.0

            // Restore enhanced shadow
            button.layer.shadowRadius = 8
            button.layer.shadowOpacity = 0.3
        }

        // Return to normal after bounce
        UIView.animate(withDuration: 0.1, delay: 0.2, options: [.curveEaseOut]) {
            button.transform = .identity
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.2
        }
    }

    @objc private func zenButtonTapped(_ button: UIButton) {
        // Sacred haptic feedback for divine interaction
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        // Additional haptic feedback for sacred confirmation
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    // MARK: - Serene Cell Styling - 宁静单元格样式
    private func enhanceCellWithSacredStyling(_ cell: UITableViewCell) {
        let name = cell.textLabel?.text ?? ""

        if name.contains("卷") || name.contains("品") {
            // 🍃 Chapter cell - 宁静清透，摒弃一切底色与边框
            cell.backgroundColor = .clear

            // 优雅平和的文本样式
            cell.textLabel?.textColor = SutraDesignTokens.shared.color(for: .chapterTitle)
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular)

        } else if name.contains("楞嚴經") || name.contains("首楞嚴經") {
            // 🌸 Main title cell - 宁静而庄重
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = SutraDesignTokens.shared.color(for: .sutraText)
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .medium)
        }
    }



    // MARK: - Divine Glow Effects - 神圣光辉效果
    private func addDivineGlowToTitle(_ button: UIButton) {
        // Remove existing glow layers
        button.layer.sublayers?.removeAll { $0.name == "divineGlow" }

        let sacredGold = SutraDesignTokens.shared.color(for: .bookmark)  // 鎏金色

        // 仅保留极其微弱单层光晕，退却红尘浮光
        let glowLayers: [(radius: CGFloat, opacity: Float, color: UIColor)] = [
            (radius: 12, opacity: 0.25, color: sacredGold)
        ]

        for glow in glowLayers {
            let glowLayer = CALayer()
            glowLayer.name = "divineGlow"
            glowLayer.frame = button.bounds
            glowLayer.backgroundColor = glow.color.cgColor
            glowLayer.cornerRadius = 8
            glowLayer.opacity = glow.opacity

            // Create glow mask
            let glowMask = CAShapeLayer()
            glowMask.path = UIBezierPath(roundedRect: button.bounds, cornerRadius: 8).cgPath
            glowLayer.mask = glowMask

            // Apply blur effect for glow
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(glow.radius, forKey: kCIInputRadiusKey)
                glowLayer.filters = [blurFilter]
            }

            // Insert behind button content
            button.layer.insertSublayer(glowLayer, at: 0)
        }

        // Add subtle pulse animation to glow
        addPulseAnimationToGlow(button)
    }

    private func addPulseAnimationToGlow(_ button: UIButton) {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 2.0
        pulseAnimation.fromValue = 0.8
        pulseAnimation.toValue = 1.2
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity

        // Apply to all glow layers
        button.layer.sublayers?.forEach { layer in
            if layer.name == "divineGlow" {
                layer.add(pulseAnimation, forKey: "divinePulse")
            }
        }
    }

    private func getCurrentColors() -> (background: UIColor, accent: UIColor) {
        // Unified with SutraDesignTokens for consistency
        return (
            background: SutraDesignTokens.shared.color(for: .background),
            accent: SutraDesignTokens.shared.color(for: .accent)
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupHeaderView(size)
        setupFooterView(size)
    }
    
    func setupHeaderView(_ size:CGSize) {
        let width = size.width
        let rs = SutraDesignTokens.shared.responsiveSpacing
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // iPad: 限制内容宽度并居中
        let cx = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: width,
            maxWidth: SutraAdaptiveLayout.homeContentWidth,
            minMargin: 0
        )
        let cw = width - (cx * 2)

        // 🏛️ Sacred header - 含经题 + 开经偈 + 今日读经 + 卷章按钮 + 功能行
        let titleTopPadding: CGFloat = rs(14)
        let titleHeight: CGFloat = rs(28)
        let titleLineGap: CGFloat = rs(4)
        let verseHeight: CGFloat = rs(44)
        let verseGap: CGFloat = rs(12)       // 开经偈上方呼吸空间
        let buttonSectionTopGap: CGFloat = rs(10) // 开经偈到卷章按钮间距
        let buttonHeight: CGFloat = max(44, rs(44))
        let verticalSpacing: CGFloat = rs(4)
        let toolRowPadding: CGFloat = rs(18)
        let toolRowHeight: CGFloat = max(44, rs(44))

        let headerHeight = titleTopPadding + titleHeight + titleLineGap + verseGap + verseHeight + buttonSectionTopGap + buttonHeight * 2 + verticalSpacing + toolRowPadding + toolRowHeight

        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: headerHeight))
        header.backgroundColor = backgroundColor

        // 📜 经题 — "大佛頂首楞嚴經"，如古卷匾额
        let titleLabel = UILabel()
        let sutraTitle = "大佛頂首楞嚴經"
        let titleKern: CGFloat = 3.0
        titleLabel.attributedText = NSAttributedString(string: sutraTitle, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary),
            .kern: titleKern
        ])
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(x: 0, y: titleTopPadding, width: width, height: titleHeight)
        header.addSubview(titleLabel)

        // 经题下方金线
        let titleLineY = titleLabel.frame.maxY + titleLineGap
        let titleLine = UIView(frame: CGRect(x: cx + rs(80), y: titleLineY, width: cw - rs(160), height: 0.5))
        titleLine.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.3)
        header.addSubview(titleLine)

        // 📜 开经偈 - 分为匀称的两行
        let subTitle = UIButton.init(type: .custom)
        let verseY = titleLineY + verseGap
        subTitle.frame = CGRect(x: cx + rs(16), y: verseY, width: cw - rs(32), height: verseHeight)
        let subTitleText = "无上甚深微妙法 百千万劫难遭遇\n我今见闻得受持 愿解如来真实义"
        subTitle.setTitle(subTitleText, for: .normal)
        subTitle.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .light)
        subTitle.titleLabel?.numberOfLines = 2

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = rs(6)
        paragraphStyle.alignment = .center
        let attributedSubTitle = NSAttributedString(string: subTitleText, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .light),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary),
            .paragraphStyle: paragraphStyle
        ])
        subTitle.setAttributedTitle(attributedSubTitle, for: .normal)
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)

        var nextY = verseY + verseHeight + buttonSectionTopGap

        // 🏋️ 卷章按钮网格
        let horizontalPadding: CGFloat = rs(20)
        let buttonSpacing: CGFloat = rs(10)
        let totalSpacing = horizontalPadding * 2 + buttonSpacing * 4
        let chapterButtonWidth = (cw - totalSpacing) / 5

        let indexes = UIView(frame: CGRect(x: cx, y: nextY, width: cw, height: buttonHeight * 2 + verticalSpacing))

        for i in 1...10 {
            let row = (i - 1) / 5
            let col = (i - 1) % 5
            let x = horizontalPadding + (chapterButtonWidth + buttonSpacing) * CGFloat(col)
            let y = (buttonHeight + verticalSpacing) * CGFloat(row)

            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: x, y: y, width: chapterButtonWidth, height: buttonHeight))
            indexes.addSubview(btn)
        }
        header.addSubview(indexes)

        // ✨ 底部边界装饰性细线
        let dividerFrame = CGRect(x: cx + rs(32), y: header.frame.height - rs(25), width: cw - rs(64), height: 0.5)
        let dividerLine = UIView(frame: dividerFrame)
        dividerLine.backgroundColor = decorativeGold.withAlphaComponent(0.2)
        header.addSubview(dividerLine)

        // ── 合并功能行：续读（左）+ 搜索（右）──
        let toolRowY = indexes.frame.maxY + toolRowPadding
        let toolRow = UIView(frame: CGRect(x: cx, y: toolRowY, width: cw, height: toolRowHeight))

        // 续读 — 始终显示，有进度时显示章节名，无进度时引导开始读经
        let bodyColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let primaryColor = SutraDesignTokens.shared.color(for: .textPrimary)
        let goldColor = SutraDesignTokens.shared.color(for: .decorativeGold)
        let continueLabel = UIButton(type: .system)
        let toolFont = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
        let hasProgress = Prefers.shared.lastReadPath != nil
        let buttonText = hasProgress ? "•  续读" : "•  开始读经"
        let continueAttr = NSMutableAttributedString(string: buttonText, attributes: [
            .font: toolFont,
            .foregroundColor: bodyColor
        ])
        continueAttr.addAttribute(.foregroundColor, value: goldColor, range: NSRange(location: 0, length: 1))
        if let lastPath = Prefers.shared.lastReadPath {
            let itemName = Book.shared.itemOfPath(lastPath)["name"] as? String ?? ""
            if !itemName.isEmpty {
                let sepAttr = NSMutableAttributedString(string: "·", attributes: [
                    .font: SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .regular),
                    .foregroundColor: bodyColor
                ])
                let titleAttr = NSMutableAttributedString(string: "\(itemName) →", attributes: [
                    .font: SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .semibold),
                    .foregroundColor: bodyColor
                ])
                continueAttr.append(sepAttr)
                continueAttr.append(titleAttr)
            }
        }
        continueLabel.setAttributedTitle(continueAttr, for: .normal)
        let btnHeight = max(44, rs(32))
        let btnY = (toolRowHeight - btnHeight) / 2
        continueLabel.frame = CGRect(x: rs(20), y: btnY, width: cw * 0.65, height: btnHeight)
        continueLabel.contentHorizontalAlignment = .left
        continueLabel.tag = 9991
        continueLabel.addTarget(self, action: #selector(continueReading), for: .touchUpInside)
        toolRow.addSubview(continueLabel)

        // 搜索 — 左对齐卷十按钮的右边缘
        let colTenRight = horizontalPadding + (chapterButtonWidth + buttonSpacing) * 4 + chapterButtonWidth
        let searchBtn = UIButton(type: .system)
        let searchAttr = NSMutableAttributedString(string: "•  搜索", attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium),
            .foregroundColor: bodyColor
        ])
        searchAttr.addAttribute(.foregroundColor, value: goldColor, range: NSRange(location: 0, length: 1))
        searchBtn.setAttributedTitle(searchAttr, for: .normal)
        let searchWidth: CGFloat = rs(72)
        searchBtn.frame = CGRect(x: colTenRight - searchWidth, y: btnY, width: searchWidth, height: btnHeight)
        searchBtn.contentHorizontalAlignment = .right
        searchBtn.addTarget(self, action: #selector(openSearch), for: .touchUpInside)
        toolRow.addSubview(searchBtn)

        header.addSubview(toolRow)

        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let rs = SutraDesignTokens.shared.responsiveSpacing
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // iPad: 限制内容宽度并居中
        let cx = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: width,
            maxWidth: SutraAdaptiveLayout.homeContentWidth,
            minMargin: 0
        )
        let cw = width - (cx * 2)

        let bottomPadding = rs(80)
        let footerHeight = rs(20) + rs(30) + rs(6) + bottomPadding
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: width, height: footerHeight))
        footer.backgroundColor = backgroundColor

        // 顶部金线
        let topLine = UIView(frame: CGRect(x: cx + rs(80), y: 0, width: cw - rs(160), height: 0.5))
        topLine.backgroundColor = decorativeGold.withAlphaComponent(0.3)
        footer.addSubview(topLine)

        // 🙏 南無楞嚴會上佛菩薩 — 始终使用繁体以显庄严，颜色为清晰饱满的古金色以确保对比度
        let homageText = "南無楞嚴會上佛菩薩"
        let homageLabel = UILabel()
        homageLabel.attributedText = NSAttributedString(string: homageText, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular),
            .foregroundColor: decorativeGold, // 使用饱满的古金色确保易读性，不再过淡
            .kern: 3.0
        ])
        homageLabel.textAlignment = .center
        homageLabel.sizeToFit()
        homageLabel.frame = CGRect(x: 0, y: rs(20), width: width, height: rs(30))
        footer.addSubview(homageLabel)

        // 经题下方金线
        let homageLineY = homageLabel.frame.maxY + rs(6)
        let homageLine = UIView(frame: CGRect(x: cx + rs(100), y: homageLineY, width: cw - rs(200), height: 0.5))
        homageLine.backgroundColor = decorativeGold.withAlphaComponent(0.25)
        footer.addSubview(homageLine)

        self.treeView.treeFooterView = footer
    }
    func makeSutraChapterButton(_ chapter:Int, frame:CGRect?) ->UIButton {
        let btn = UIButton(type: .custom)
        if let frame = frame {
            btn.frame = frame
        }
        btn.setTitle(NSLocalizedString("chapter_\(chapter+1)", comment: "chapter_name"), for: .normal)
        btn.tag = chapter
        btn.addTarget(self, action: #selector(onSutraChapterButtonTouchUp(_:)), for: .touchUpInside)
        btn.addTarget(self, action: #selector(chapterTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(chapterTouchUp(_:)), for: [.touchUpOutside, .touchCancel])
        btn.titleLabel?.adjustsFontSizeToFitWidth = true

        // 当前正在阅读的卷用 bold 字重突出
        let isCurrentChapter = Prefers.shared.lastReadChapter == chapter
        btn.backgroundColor = .clear
        btn.setTitleColor(
            SutraDesignTokens.shared.color(for: isCurrentChapter ? .textSecondary : .textPrimary),
            for: .normal
        )
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(
            for: .buttonMedium,
            weight: isCurrentChapter ? .bold : .regular
        )

        // 去除原本的强边框与阴影，仅留极细微的底边暗示
        btn.layer.borderWidth = 0
        btn.layer.shadowOpacity = 0

        return btn
    }

    // MARK: - 古卷经题（签名时刻）
    /// 如古卷印章，经题从右至左横排，配以金线框装饰
    private func makeVerticalSutraTitle() -> UIView {
        let sutraName = "大佛頂首楞嚴經"
        let containerWidth: CGFloat = 240
        let container = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: 40))

        // 从右到左排列（传统直排方向）
        let chars = Array(sutraName).reversed()
        let fullText = String(chars)

        let titleLabel = UILabel()
        titleLabel.text = fullText
        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular)
        titleLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 0, y: 4, width: containerWidth, height: 32)
        // 适度字距，七字疏朗有致
        titleLabel.attributedText = NSAttributedString(string: fullText, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary),
            .kern: 4.0
        ])
        container.addSubview(titleLabel)

        // 金线框装饰
        let linePadding: CGFloat = 20
        let lineWidth = containerWidth - linePadding * 2
        let topLine = UIView(frame: CGRect(x: linePadding, y: 0, width: lineWidth, height: 0.5))
        topLine.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.35)
        container.addSubview(topLine)

        let bottomLine = UIView(frame: CGRect(x: linePadding, y: 39.5, width: lineWidth, height: 0.5))
        bottomLine.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.35)
        container.addSubview(bottomLine)

        return container
    }

    func makeSutraIndexButton(_ path:String, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        if let name = Book.shared.itemOfPath(path)["name"] as? String {
            btn.setTitle(name, for: .normal)
        }
        btn.addTarget(self, action: #selector(onSutraIndexButtonTouchUp(_:)), for: .touchUpInside)
        let count = sutraIndexButtons.count;
        btn.tag = count
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;

        // 🏛️ 首页经题 - 回归墨色，与经卷传统一致；金色退居装饰角色
        let titleColor = SutraDesignTokens.shared.color(for: .textPrimary)
        btn.setTitleColor(titleColor, for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .medium)
        
        let titleText = btn.title(for: .normal) ?? ""
        if titleText.count > 0 {
            // 给导航栏文字上方增加一条细金线装饰 (贴近文字顶端，减小悬空感)
            let topBorder = UIView()
            topBorder.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.4)
            topBorder.translatesAutoresizingMaskIntoConstraints = false
            btn.addSubview(topBorder)
            NSLayoutConstraint.activate([
                topBorder.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 6),
                topBorder.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -6),
                topBorder.topAnchor.constraint(equalTo: btn.topAnchor, constant: -2),
                topBorder.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }

        sutraIndexButtons.append(path)
        return btn;
    }
    
    @objc func onSutraIndexButtonTouchUp(_ sender:UIButton){
        let path = sutraIndexButtons[sender.tag]
        self.openIndex(Book.shared.itemOfPath(path))
    }

    // MARK: - Chapter Button Touch Feedback
    @objc private func chapterTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            sender.alpha = 0.7
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    @objc private func chapterTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8, options: .curveEaseOut) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    @objc func onSutraChapterButtonTouchUp(_ sender:UIButton){
        let chapter = sender.tag
        // 有进度且是同一卷时恢复位置，否则从第一页开始
        let offset: CGFloat? = (Prefers.shared.lastReadChapter == chapter && Prefers.shared.lastReadChapterOffset > 0)
            ? Prefers.shared.lastReadChapterOffset : nil
        self.openChapter(chapter: chapter, restoreOffset: offset)
    }

    
    @objc func openRootIndex() {
        self.openIndex(Book.shared.itemOfPath(""))
    }
    
    @objc func openDrbaLink(_ sender:UIButton) {
        if let url = URL(string: "http://www.drbachinese.org/online_reading/sutra_explanation/Shu/contents.htm") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc func openAcknowledgments() {
        let hostingController = UIHostingController(rootView: SutraAcknowledgmentsView())
        hostingController.title = "致谢"
        self.navigationController?.pushViewController(hostingController, animated: true)
    }

    // MARK: - 合并行功能

    @objc func continueReading() {
        guard let lastPath = Prefers.shared.lastReadPath else {
            // 首次用户：打开卷一开始读经
            openChapter(chapter: 0)
            return
        }
        let mode = Prefers.shared.lastReadMode ?? "paged"

        self.navigationController?.setNavigationBarHidden(false, animated: false)

        if mode == "tree" {
            // 科判式阅读
            let sutraVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            sutraVC.path = lastPath
            sutraVC.hidesBottomBarWhenPushed = true
            sutraVC.onDismiss = { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
            }
            self.navigationController?.pushViewController(sutraVC, animated: true)
        } else {
            // 卷式翻页阅读
            let pageVC = SutraPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            pageVC.hidesBottomBarWhenPushed = true
            if let pageIndex = Book.shared.index?.firstIndex(where: { $0["path"] == lastPath }) {
                pageVC.page = pageIndex
            } else {
                // path 找不到对应页，fallback 到科判式
                let sutraVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
                sutraVC.path = lastPath
                sutraVC.hidesBottomBarWhenPushed = true
                sutraVC.onDismiss = { [weak self] in
                    self?.navigationController?.setNavigationBarHidden(false, animated: false)
                }
                self.navigationController?.pushViewController(sutraVC, animated: true)
                return
            }
            self.navigationController?.pushViewController(pageVC, animated: true)
        }
    }

    @objc func openSearch() {
        let nav = UINavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = SutraAdaptiveLayout.shouldUseSheetModal(for: traitCollection)
            ? .pageSheet : .fullScreen
        if nav.modalPresentationStyle == .pageSheet,
           let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
        }

        let searchView = SearchView(
            onDismiss: { [weak nav] in
                nav?.dismiss(animated: true)
            },
            onNavigate: { [weak nav] result in
                guard let nav = nav else { return }
                let sutraVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
                sutraVC.path = result.path
                nav.pushViewController(sutraVC, animated: true)
            }
        )

        let hostingController = SearchHostingController(rootView: searchView)
        nav.setViewControllers([hostingController], animated: false)
        present(nav, animated: true)
    }
    
    func close(){
        self.navigationController?.popViewController(animated: true)
    }
    
    func showList(){
        print("🔥 showList() called - Book.shared.loaded = \(Book.shared.loaded)")
        self.tree = Book.shared.getKeyItems();

        if let tree = self.tree {
            print("🔥 Tree loaded with \(tree.count) items")
        } else {
            print("🔥 ERROR - tree is nil! Book data may not be loaded properly.")
        }

        print("🔥 Reloading treeView...")
        DispatchQueue.main.async {
            self.treeView.reloadData()
            print("🔥 TreeView has \(self.treeView.visibleCells()?.count ?? 0) visible cells")
        }
    }
    
    
    // 长按科判行 → 打开该条目的下级科判列表（与纯阅读页右上角 index 一致）
    @objc func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == UIGestureRecognizerState.began {
            let touchPoint = longPressGestureRecognizer.location(in: self.treeView.scrollView)
            if let rowItem = treeView.itemForRow(at: touchPoint) as? [String] {
                let path = rowItem[0]
                let item = Book.shared.itemOfPath(path)
                if item["children"] != nil {
                    openIndex(item)
                }
            }
        }
    }
    
    func openSutraOfPath(path:String){
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.scroll, navigationOrientation:.horizontal, options: .none)
        sutraVC.path = path
        sutraVC.hidesBottomBarWhenPushed = true
        sutraVC.onDismiss = {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    func openContent(_ item: [String : Any]){
        let pageVC = SutraPageViewController.init( transitionStyle:.scroll,
                                                   navigationOrientation:.horizontal,
                                                   options: .none)
        let path:String = item["path"] as! String
        pageVC.hidesBottomBarWhenPushed = true
        // TICK()
        pageVC.page=Book.shared.index!.index(where: { (
            item) -> Bool in
            return item["path"] == path
        })!;
        // TOCK()

        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.pushViewController(pageVC, animated: true)
    }
    func openIndex(_ item: [String:Any]){
        let indexVC = SutraIndexViewController();
        indexVC.tree = item;
        indexVC.defaultExpandLevel = 2;
        indexVC.onDismiss = {
            } as (() -> Void)
        
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.pushViewController(indexVC, animated: true)
    }
    
    func openChapter(chapter:Int, restoreOffset: CGFloat? = nil){
        let content = Book.shared.getSutraAttributeString(text: Book.shared.getChapterSutra(chapter: chapter))
        let title = NSLocalizedString("chapter_\(chapter + 1)", comment: "chapter_name");
        let pageVC = ReaderViewController(title: title, content: content, chapter: chapter, restoreOffset: restoreOffset)
        pageVC.hidesBottomBarWhenPushed = true
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.pushViewController(pageVC, animated: true)
    }

    // MARK - RATreeView
    
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if(item == nil){
            let count = self.tree?.count ?? 0
            print("🔥 Root level: returning \(count) children")
            return count
        } else {
            return 0
        }
    }
    
    public func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        var newCell = treeView.dequeueReusableCell(withIdentifier: "indexCell") as? UITableViewCell;

        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.value1,reuseIdentifier:"indexCell");
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            newCell!.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
        }

        let cell = newCell!;
        let item = item as! [String];
        let name = item[1];
        
        // 🌿 添加精致的金色引导点
        let dot = "•  "
        let attrText = NSMutableAttributedString(string: dot + name)
        attrText.addAttribute(.foregroundColor, value: SutraDesignTokens.shared.color(for: .decorativeGold), range: NSRange(location: 0, length: 1))
        
        cell.textLabel?.attributedText = attrText

        // Apply enhanced design system styling
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let primaryTextColor = SutraDesignTokens.shared.color(for: .textPrimary)
        let accentColor = SutraDesignTokens.shared.color(for: .accent)
        let cardColor = SutraDesignTokens.shared.color(for: .card)

        cell.backgroundColor = backgroundColor
        cell.textLabel?.textColor = primaryTextColor
        // 科判字体同听经列表一样，减小粗重感并偏向衬线雅正
        cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)
        cell.tintColor = accentColor
        cell.accessoryView?.tintColor = accentColor

        // 🏯 Apply sacred styling to cell content view
        enhanceCellWithSacredStyling(cell)

  
        // 🧹 扫除强烈的凡俗卡片边框与阴影，仅保留纯粹的底色与文字交互
        cell.layer.cornerRadius = 0
        cell.layer.shadowOpacity = 0
        cell.layer.borderWidth = 0

        // 紧凑行内留白，目录密度舒适
        let rs = SutraDesignTokens.shared.responsiveSpacing
        cell.contentView.layoutMargins = UIEdgeInsets(top: rs(4), left: rs(24), bottom: rs(4), right: rs(24))

        // 收紧层级缩进，回归朴素雅致的古风目录
        cell.indentationWidth = rs(15)

        // 淡淡的点按反馈
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = SutraDesignTokens.shared.color(for: .card).withAlphaComponent(0.5)
        cell.selectedBackgroundView = selectedBackgroundView

        // 🚫 去去去，莫要那庸俗的系统箭头
        cell.accessoryType = .none

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

    // MARK: - Enhanced Design System Integration
    // TODO: Migrate theme system - private var currentTheme: SutraTheme { return SutraDesignTokens.shared.currentTheme }

    enum Theme {
        case light, sepia, dark
    }

    private func setupEnhancedDesign() {
        print("🎨 Applying enhanced design")

        // Apply enhanced colors using design tokens - 禅意色彩哲学
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        treeView.backgroundColor = SutraDesignTokens.shared.color(for: .background)

        // Enhanced navigation bar styling - 禅意色彩
        navigationController?.navigationBar.backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar)
        navigationController?.navigationBar.barTintColor = SutraDesignTokens.shared.color(for: .navigationBar)
     
        }
    }

