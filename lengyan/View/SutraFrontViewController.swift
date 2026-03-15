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
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // 🏛️ Sacred header - 适度缩减高度至 200pt，紧凑开经偈与卷章按钮，抹平不均衡的留白
        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: 200))
        header.backgroundColor = backgroundColor

        // 📜 开经偈 - 分为匀称的两行，调大整体宽幅与字号
        let subTitle = UIButton.init(type: .custom)
        subTitle.frame = CGRect(x: 16, y: 12, width: width - 32, height: 50)
        // 使用带有特定换行符的开经偈
        let subTitleText = "无上甚深微妙法 百千万劫难遭遇\n我今见闻得受持 愿解如来真实义"
        subTitle.setTitle(subTitleText, for: .normal)
        subTitle.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .light)
        subTitle.titleLabel?.numberOfLines = 2
        
        // 设置行距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center
        let attributedSubTitle = NSAttributedString(string: subTitleText, attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .light),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textTertiary),
            .paragraphStyle: paragraphStyle
        ])
        subTitle.setAttributedTitle(attributedSubTitle, for: .normal)
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)

        // 🏋️ 卷章按钮网格 (褪去卡片后的字样)
        let horizontalPadding: CGFloat = 20
        let buttonSpacing: CGFloat = 10
        let totalSpacing = horizontalPadding * 2 + buttonSpacing * 4
        let chapterButtonWidth = (width - totalSpacing) / 5
        let buttonHeight: CGFloat = 44 // 缩减按钮高度，减去多余空白
        let verticalSpacing: CGFloat = 4

        let indexes = UIView(frame: CGRect(x: 0, y: 72, width: width, height: buttonHeight * 2 + verticalSpacing))

        for i in 1...10 {
            let row = (i - 1) / 5
            let col = (i - 1) % 5
            let x = horizontalPadding + (chapterButtonWidth + buttonSpacing) * CGFloat(col)
            let y = (buttonHeight + verticalSpacing) * CGFloat(row)

            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: x, y: y, width: chapterButtonWidth, height: buttonHeight))
            indexes.addSubview(btn)
        }
        header.addSubview(indexes)

        // ✨ 装饰性金色渐隐分隔线 (开经偈下方) - 紧凑提上来
        let subTitleBottom = subTitle.frame.maxY + 4
        let lotusDividerView = UIView(frame: CGRect(x: 60, y: subTitleBottom, width: width - 120, height: 1.0))
        let lotusDivider = CAGradientLayer()
        lotusDivider.frame = CGRect(x: 0, y: 0, width: lotusDividerView.frame.width, height: 1.0)
        lotusDivider.colors = [
            UIColor.clear.cgColor,
            decorativeGold.withAlphaComponent(0.4).cgColor, // 减弱金线强度
            UIColor.clear.cgColor
        ]
        lotusDivider.startPoint = CGPoint(x: 0, y: 0.5)
        lotusDivider.endPoint = CGPoint(x: 1, y: 0.5)
        lotusDividerView.layer.addSublayer(lotusDivider)
        header.addSubview(lotusDividerView)

        // ✨ 底部边界装饰性细线 (收尾过渡到科判列表)
        let dividerFrame = CGRect(x: 32, y: header.frame.height - 1, width: width - 64, height: 0.5)
        let dividerLine = UIView(frame: dividerFrame)
        dividerLine.backgroundColor = decorativeGold.withAlphaComponent(0.2)
        header.addSubview(dividerLine)

        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let bookmarkColor = SutraDesignTokens.shared.color(for: .bookmark)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)

        // 🏛️ 庄严尾部 - 增加高度以容纳完整内容
        let footer:UIView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 180))
        footer.backgroundColor = backgroundColor

        // 顶部鎏金分割线
        let topDivider = UIView(frame: CGRect(x: 48, y: 0, width: width - 96, height: 0.5))
        topDivider.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.3)
        footer.addSubview(topDivider)

        // 🙏 南无楞严会上佛菩萨 - 庄严顶礼文字
        let homageLabel = UILabel()
        homageLabel.text = "南无楞严会上佛菩萨！"
        homageLabel.font = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        homageLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        homageLabel.textAlignment = .center
        homageLabel.numberOfLines = 0
        homageLabel.lineBreakMode = .byWordWrapping
        homageLabel.frame = CGRect(x: 32, y: 24, width: width - 64, height: 60)
        footer.addSubview(homageLabel)

        // 🙏 精致致谢按钮 - 带图标和优雅样式
        let acknowledgmentsButton = UIButton(type: .custom)
        acknowledgmentsButton.frame = CGRect(x: width/2 - 60, y: 88, width: 180, height: 44)

        // 创建带图标的富文本
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = UIImage(systemName: "hands.press.fill")
        iconAttachment.bounds = CGRect(x: 0, y: -2, width: 18, height: 18)

        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(attachment: iconAttachment))
        attributedString.append(NSAttributedString(string: "素材来源与致谢", attributes: [
            .font: SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .medium),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary),
            .kern: 1.0
        ]))

        acknowledgmentsButton.setAttributedTitle(attributedString, for: .normal)
        acknowledgmentsButton.backgroundColor = .clear
        acknowledgmentsButton.layer.cornerRadius = 22
        acknowledgmentsButton.addTarget(self, action: #selector(self.openAcknowledgments), for: .touchUpInside)
        footer.addSubview(acknowledgmentsButton)
        

        // 莲花装饰分隔
        let lotusLabel = UILabel()
        lotusLabel.text = "✧ ❀ ✧"
        lotusLabel.font = .systemFont(ofSize: 14)
        lotusLabel.textColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.6)
        lotusLabel.textAlignment = .center
        lotusLabel.frame = CGRect(x: 0, y: 120, width: width, height: 20)
        footer.addSubview(lotusLabel)
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

        // 📜 古雅经卷文字按钮，摒弃红尘卡片相
        btn.backgroundColor = .clear
        btn.setTitleColor(SutraDesignTokens.shared.color(for: .textPrimary), for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .regular) // 换用更纤细平和的字重

        // 去除原本的强边框与阴影，仅留极细微的底边暗示
        btn.layer.borderWidth = 0
        btn.layer.shadowOpacity = 0

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
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .medium)
        
        let titleText = btn.title(for: .normal) ?? ""
        if titleText.count > 0 {
            // 给导航栏文字上方增加一条细金线装饰 (贴近文字顶端，减小悬空感)
            let topBorder = UIView(frame: CGRect(x: 30, y: -2, width: UIScreen.main.bounds.width - 66, height: 0.5))
            topBorder.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.4)
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
    
    @objc func openAcknowledgments() {
        let hostingController = UIHostingController(rootView: SutraAcknowledgmentsView())
        hostingController.title = "致谢"
        self.navigationController?.pushViewController(hostingController, animated: true)
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

        // 维持素雅的段落留白，稍微压缩行高以聚拢内容
        cell.contentView.layoutMargins = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        
        // 收紧层级缩进，回归朴素雅致的古风目录
        cell.indentationWidth = 15

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

