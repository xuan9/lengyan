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
        treeView.rowHeight = 64; // World-class iOS touch targets (increased from 56pt)
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

        let title = self.makeSutraIndexButton("", frame: CGRect(x: 3, y: 0, width: self.view.bounds.width - 3, height: 40));
        self.navigationItem.titleView = title;
        print("🔥 === VIEW SETUP COMPLETE ===")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Refresh design system on appearance
        applyZenTempleSerenityDesignSystem()

        // Configure navigation bar behavior
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.hidesBarsOnSwipe = false
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
        applyThemeColorsToView()
        configureTreeViewWithDesignSystem()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTreeViewWithDesignSystem() {
        // Guard against treeView not being initialized yet (can happen during early notification calls)
        guard let treeView = treeView else { return }

        // FIXED: Use the same background as the view so it's visible
        let bgColor = SutraDesignTokens.shared.color(for: .background)
        treeView.backgroundColor = bgColor
        treeView.rowHeight = 64  // World-class iOS touch targets
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

        treeView.rowHeight = 50 // Increased for zen styling
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
            // 🍃 Chapter cell - 宁静而生机勃勃
            cell.backgroundColor = SutraDesignTokens.shared.color(for: .card)

            // 添加微妙的渐变背景
            addSubtleGradientToCell(cell)

            // 简约而雅致的边框
            cell.layer.borderWidth = 0.5
            cell.layer.borderColor = SutraDesignTokens.shared.color(for: .bookmark).withAlphaComponent(0.3).cgColor

            // 轻柔的阴影，不干扰阅读
            cell.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
            cell.layer.shadowRadius = 4
            cell.layer.shadowOpacity = 0.1
            cell.layer.shadowOffset = CGSize(width: 0, height: 1)

            // 优雅的文本样式
            cell.textLabel?.textColor = SutraDesignTokens.shared.color(for: .chapterTitle)
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)

        } else if name.contains("楞嚴經") || name.contains("首楞嚴經") {
            // 🌸 Main title cell - 宁静而庄重
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = SutraDesignTokens.shared.color(for: .sutraText)
            cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .semibold)

            // 添加微妙的呼吸感
            addSubtleBreathingToCell(cell)
        }
    }

    // MARK: - 宁静微妙的渐变效果
    private func addSubtleGradientToCell(_ cell: UITableViewCell) {
        // Remove existing gradients
        cell.layer.sublayers?.removeAll { $0.name == "subtleGradient" }

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "subtleGradient"
        gradientLayer.frame = cell.bounds

        // 🌸 宁静而微妙的渐变
        let surfaceColor = SutraDesignTokens.shared.color(for: .surface)
        let cardColor = SutraDesignTokens.shared.color(for: .card)
        let primaryColor = SutraDesignTokens.shared.color(for: .primary)

        // 极简的两色渐变，营造宁静感
        gradientLayer.colors = [
            cardColor.cgColor,
            surfaceColor.withAlphaComponent(0.3).cgColor,
            cardColor.cgColor
        ]

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.cornerRadius = cell.layer.cornerRadius

        // Insert behind cell content
        cell.layer.insertSublayer(gradientLayer, at: 0)

        // Store gradient layer reference for bounds changes
        objc_setAssociatedObject(cell, "subtleGradient", gradientLayer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - 微妙的呼吸感效果
    private func addSubtleBreathingToCell(_ cell: UITableViewCell) {
        // 为文本标签添加微妙的阴影效果
        cell.textLabel?.layer.shadowColor = SutraDesignTokens.shared.color(for: .bookmark).withAlphaComponent(0.3).cgColor
        cell.textLabel?.layer.shadowRadius = 2
        cell.textLabel?.layer.shadowOpacity = 0.5
        cell.textLabel?.layer.shadowOffset = CGSize(width: 0, height: 1)

        // 添加非常缓慢的呼吸动画
        let breathingAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        breathingAnimation.duration = 8.0  // 8秒周期，非常缓慢
        breathingAnimation.fromValue = 0.3
        breathingAnimation.toValue = 0.7
        breathingAnimation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
        breathingAnimation.autoreverses = true
        breathingAnimation.repeatCount = .infinity

        cell.textLabel?.layer.add(breathingAnimation, forKey: "breathing")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds", let cell = object as? UITableViewCell {
            // 更新微妙的渐变层
            if let gradientLayer = objc_getAssociatedObject(cell, "subtleGradient") as? CAGradientLayer {
                gradientLayer.frame = cell.bounds
            }
        }
    }

    // MARK: - Divine Glow Effects - 神圣光辉效果
    private func addDivineGlowToTitle(_ button: UIButton) {
        // Remove existing glow layers
        button.layer.sublayers?.removeAll { $0.name == "divineGlow" }

        let sacredGold = SutraDesignTokens.shared.color(for: .bookmark)  // 鎏金色
        let divineOrange = SutraDesignTokens.shared.color(for: .accent)   // 佛光橙

        // Create multiple glow layers for divine effect
        let glowLayers: [(radius: CGFloat, opacity: Float, color: UIColor)] = [
            (radius: 15, opacity: 0.6, color: sacredGold),
            (radius: 25, opacity: 0.3, color: divineOrange),
            (radius: 35, opacity: 0.15, color: sacredGold),
            (radius: 45, opacity: 0.08, color: divineOrange)
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
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // 🏛️ Sacred header - 增大高度到240pt，给开经偈和卷章按钮更充裕的呼吸空间
        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: 240))
        header.backgroundColor = backgroundColor

        // 📜 开经偈 - 增大字号、增加字距向读者展示禅意
        let subTitle = UIButton.init(type: .custom)
        subTitle.frame = CGRect(x: 24, y: 20, width: width - 48, height: 40)
        let subTitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subTitle.setTitle(subTitleText, for: .normal)
        subTitle.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .sacredText, weight: .regular)
        subTitle.titleLabel?.numberOfLines = 2
        subTitle.titleLabel?.lineBreakMode = .byCharWrapping
        subTitle.titleLabel?.textAlignment = .center
        subTitle.setTitleColor(SutraDesignTokens.shared.color(for: .textTertiary), for: .normal)
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)

        // 🏋️ 鎏金卡片风格卷章按钮网格
        let horizontalPadding: CGFloat = 20
        let buttonSpacing: CGFloat = 10
        let totalSpacing = horizontalPadding * 2 + buttonSpacing * 4
        let chapterButtonWidth = (width - totalSpacing) / 5
        let buttonHeight: CGFloat = 56
        let verticalSpacing: CGFloat = 10

        let indexes = UIView(frame: CGRect(x: 0, y: 76, width: width, height: buttonHeight * 2 + verticalSpacing))

        for i in 1...10 {
            let row = (i - 1) / 5
            let col = (i - 1) % 5
            let x = horizontalPadding + (chapterButtonWidth + buttonSpacing) * CGFloat(col)
            let y = (buttonHeight + verticalSpacing) * CGFloat(row)

            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: x, y: y, width: chapterButtonWidth, height: buttonHeight))
            indexes.addSubview(btn)
        }
        header.addSubview(indexes)

        // ✨ 装饰性金色渐隐分隔线 (开经偈下方)
        let subTitleBottom = subTitle.frame.maxY + 12
        let lotusDividerView = UIView(frame: CGRect(x: 60, y: subTitleBottom, width: width - 120, height: 1.0))
        let lotusDivider = CAGradientLayer()
        lotusDivider.frame = CGRect(x: 0, y: 0, width: lotusDividerView.frame.width, height: 1.0)
        lotusDivider.colors = [
            UIColor.clear.cgColor,
            decorativeGold.withAlphaComponent(0.8).cgColor,
            UIColor.clear.cgColor
        ]
        lotusDivider.startPoint = CGPoint(x: 0, y: 0.5)
        lotusDivider.endPoint = CGPoint(x: 1, y: 0.5)
        lotusDividerView.layer.addSublayer(lotusDivider)
        header.addSubview(lotusDividerView)

        // ✨ 底部边界装饰性细线
        let dividerFrame = CGRect(x: 32, y: header.frame.height - 1, width: width - 64, height: 0.5)
        let dividerLine = UIView(frame: dividerFrame)
        dividerLine.backgroundColor = decorativeGold.withAlphaComponent(0.3)
        header.addSubview(dividerLine)

        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)

        // 🏛️ 庄严尾部 - 280pt呼吸空间
        let footer:UIView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 280))
        footer.backgroundColor = backgroundColor

        // ✨ 装饰性金色渐隐分隔线
        let dividerLineView = UIView(frame: CGRect(x: 40, y: 10, width: width - 80, height: 0.5))
        let dividerLine = CAGradientLayer()
        dividerLine.frame = CGRect(x: 0, y: 0, width: dividerLineView.frame.width, height: 0.5)
        dividerLine.colors = [UIColor.clear.cgColor, decorativeGold.withAlphaComponent(0.4).cgColor, UIColor.clear.cgColor]
        dividerLine.startPoint = CGPoint(x: 0, y: 0.5)
        dividerLine.endPoint = CGPoint(x: 1, y: 0.5)
        dividerLineView.layer.addSublayer(dividerLine)
        footer.addSubview(dividerLineView)

        let footerText1 = NSLocalizedString("footer_txt_1", comment: "南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩")
        let footerText2 = NSLocalizedString("footer_txt_2", comment: "經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站")
        let footerText3 = NSLocalizedString("footer_txt_3", comment: "感恩法界佛教總會！本屏中列出部分關鍵科判以方便檢索，可點擊經名打開完整科判。")

        // 🌸 莲花装饰符 (替代法轮避免字体不支持)
        let decoration = UILabel(frame: CGRect(x: 0, y: 30, width: width, height: 24))
        decoration.text = "✧   ❀   ✧"
        decoration.font = UIFont.systemFont(ofSize: 16)
        decoration.textColor = decorativeGold
        decoration.textAlignment = .center
        footer.addSubview(decoration)

        // 🙏 「南無楞嚴會上佛菩薩」- 使用鎏金色，增加行距，高度扩充到100
        let footerLabel = UILabel(frame: CGRect(x: 20, y: 64, width: width - 40, height: 100))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center
        footerLabel.attributedText = NSAttributedString(string: footerText1, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .sacredText, weight: .medium),
            .foregroundColor: bookmarkColor,
            .paragraphStyle: paragraphStyle
        ])
        footerLabel.numberOfLines = 3
        footerLabel.lineBreakMode = .byWordWrapping
        footer.addSubview(footerLabel)

        // 🔗 来源链接 - 使用 accent 色，调整排版Y轴
        let linkButton = UIButton(frame: CGRect(x: 20, y: 174, width: width - 40, height: 44))
        linkButton.setTitle(footerText2, for: .normal)
        linkButton.contentHorizontalAlignment = .center
        linkButton.setImage(UIImage(systemName: "link")?.withRenderingMode(.alwaysTemplate), for: .normal)
        linkButton.addTarget(self, action: #selector(self.openDrbaLink(_:)), for: .touchUpInside)
        linkButton.semanticContentAttribute = .forceRightToLeft
        linkButton.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .medium)
        linkButton.titleLabel?.numberOfLines = 2
        linkButton.titleLabel?.lineBreakMode = .byCharWrapping
        linkButton.setTitleColor(SutraDesignTokens.shared.color(for: .accent), for: .normal)
        linkButton.backgroundColor = .clear
        linkButton.tintColor = SutraDesignTokens.shared.color(for: .accent)
        footer.addSubview(linkButton)

        // 说明文字 - 更淡雅的次要文字，调整段落间距
        let footerLabel2 = UILabel(frame: CGRect(x: 20, y: 222, width: width - 40, height: 44))
        let footer2Paragraph = NSMutableParagraphStyle()
        footer2Paragraph.lineSpacing = 4
        footer2Paragraph.alignment = .center
        footerLabel2.attributedText = NSAttributedString(string: footerText3, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .regular),
            .foregroundColor: secondaryTextColor.withAlphaComponent(0.6),
            .paragraphStyle: footer2Paragraph
        ])
        footerLabel2.numberOfLines = 0
        footerLabel2.lineBreakMode = .byWordWrapping
        footer.addSubview(footerLabel2)

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
        btn.titleLabel?.adjustsFontSizeToFitWidth = true

        // 🏛️ 鎏金卡片风格卷章按钮
        btn.backgroundColor = SutraDesignTokens.shared.color(for: .card)
        btn.setTitleColor(SutraDesignTokens.shared.color(for: .textPrimary), for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
        btn.layer.cornerRadius = 14

        // 古金 hairline 边框
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.4).cgColor

        // 极柔软的暖色阴影
        btn.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowOpacity = 0.08
        btn.layer.shadowRadius = 6
        btn.layer.masksToBounds = false

        return btn
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

        // 🏛️ 首页经题装饰 - 使用大标题色（鎏金色），增加强调神圣感
        let titleColor = SutraDesignTokens.shared.color(for: .chapterTitle)
        btn.setTitleColor(titleColor, for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .heavy)
        
        let titleText = btn.title(for: .normal) ?? ""
        if titleText.count > 0 {
            // 给导航栏文字上方增加一条细金线装饰
            let topBorder = UIView(frame: CGRect(x: 20, y: 0, width: UIScreen.main.bounds.width - 46, height: 0.5))
            topBorder.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold)
            btn.addSubview(topBorder)
        }

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
        if let url = URL(string: "http://www.drbachinese.org/online_reading/sutra_explanation/Shu/contents.htm") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
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
        self.treeView.reloadData()
        print("🔥 TreeView has \(treeView.visibleCells()?.count ?? 0) visible cells")
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
        let content = Book.shared.getSutraAttributeString(text: Book.shared.getChapterSutra(chapter: chapter))
        let title = NSLocalizedString("chapter_\(chapter + 1)", comment: "chapter_name");
        let pageVC = ReaderViewController.init(title: title, content: content)
        
//        let pageVC = SutraChapterPageViewController.init( transitionStyle:.pageCurl,
//                                                   navigationOrientation:.horizontal,
//                                                   options: .none)
//        pageVC.pageIndex = chapter;
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
        cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
        cell.tintColor = accentColor
        cell.accessoryView?.tintColor = accentColor

        // 🏯 Apply sacred styling to cell content view
        enhanceCellWithSacredStyling(cell)

  
        // Add world-class card styling with subtle elevation
        cell.layer.cornerRadius = 12
        cell.layer.shadowColor = SutraDesignTokens.shared.color(for: .shadow).cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowRadius = 8
        cell.layer.shadowOpacity = 0.08
        cell.layer.masksToBounds = false

        // Add subtle border for definition
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = SutraDesignTokens.shared.color(for: .divider).cgColor

        // Add content inset for breathing room
        cell.contentView.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)

        // Add enhanced selection background
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = cardColor
        selectedBackgroundView.layer.cornerRadius = 12
        cell.selectedBackgroundView = selectedBackgroundView

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

