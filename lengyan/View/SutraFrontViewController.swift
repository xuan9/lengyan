//
//  SutraFrontViewController.swift
//  lengyan
//
//  Created by Xuan on 16/7/2.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

private enum HomeActionAlignment {
    case leading
    case center
    case trailing
}

/// A quiet text action with a fixed marker column. Keeping the symbol outside
/// UIButton's title layout avoids per-symbol frame nudges and gives all four
/// home actions the same optical starting point.
private final class HomeActionButton: UIButton {
    private let markerSlot = UIView()
    private let markerView = UIImageView()
    private let actionLabel = UILabel()
    private let contentStack = UIStackView()
    private var horizontalConstraints: [NSLayoutConstraint] = []

    init(
        text: String,
        symbolName: String,
        font: UIFont,
        iconSize: CGFloat,
        markerSlotWidth: CGFloat,
        bodyColor: UIColor,
        iconOpticalScale: CGFloat,
        alignment: HomeActionAlignment
    ) {
        super.init(frame: .zero)

        markerSlot.translatesAutoresizingMaskIntoConstraints = false
        markerSlot.isUserInteractionEnabled = false

        let configuration = UIImage.SymbolConfiguration(
            pointSize: iconSize,
            weight: .regular,
            scale: .small
        )
        markerView.image = UIImage(systemName: symbolName, withConfiguration: configuration)
            ?? UIImage(systemName: "circle.fill", withConfiguration: configuration)
        // Use the label's ink tone at lower emphasis. Decorative gold never
        // reaches enough contrast on paper backgrounds for these tiny symbols.
        markerView.tintColor = bodyColor.withAlphaComponent(0.68)
        markerView.contentMode = .scaleAspectFit
        markerView.transform = CGAffineTransform(
            scaleX: iconOpticalScale,
            y: iconOpticalScale
        )
        markerView.translatesAutoresizingMaskIntoConstraints = false
        markerView.isUserInteractionEnabled = false
        markerSlot.addSubview(markerView)

        actionLabel.text = text
        actionLabel.font = font
        actionLabel.textColor = bodyColor
        actionLabel.numberOfLines = 1
        actionLabel.lineBreakMode = .byTruncatingTail
        actionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        actionLabel.isUserInteractionEnabled = false

        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        contentStack.addArrangedSubview(markerSlot)
        contentStack.addArrangedSubview(actionLabel)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            markerSlot.widthAnchor.constraint(equalToConstant: markerSlotWidth),
            markerSlot.heightAnchor.constraint(equalToConstant: max(iconSize, 16)),
            markerView.leadingAnchor.constraint(equalTo: markerSlot.leadingAnchor),
            markerView.trailingAnchor.constraint(equalTo: markerSlot.trailingAnchor),
            markerView.topAnchor.constraint(equalTo: markerSlot.topAnchor),
            markerView.bottomAnchor.constraint(equalTo: markerSlot.bottomAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
        setContentAlignment(alignment)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContentAlignment(
        _ alignment: HomeActionAlignment,
        edgeInset: CGFloat = 0
    ) {
        NSLayoutConstraint.deactivate(horizontalConstraints)
        switch alignment {
        case .leading:
            horizontalConstraints = [
                contentStack.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: edgeInset
                )
            ]
        case .center:
            horizontalConstraints = [contentStack.centerXAnchor.constraint(equalTo: centerXAnchor)]
        case .trailing:
            horizontalConstraints = [
                contentStack.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -edgeInset
                )
            ]
        }
        NSLayoutConstraint.activate(horizontalConstraints)
    }

    override var isHighlighted: Bool {
        didSet {
            contentStack.alpha = isHighlighted ? 0.52 : 1
        }
    }
}

class SutraFrontViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate{
    
    fileprivate var treeView: RATreeView!
    internal var tree:[[String]]?;
    
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

        // Rebuild header to refresh both reading-resume entries.
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
        maybeShowDailyReminderPrompt()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开首页时恢复导航栏，供阅读页/索引页使用
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
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
        NotificationCenter.default.removeObserver(
            self,
            name: .themeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChangeForFrontViewController), name: .themeDidChange, object: nil)
    }

    @objc private func themeDidChangeForFrontViewController() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.applyThemeColorsToView()
            self.configureTreeViewWithDesignSystem()
            self.setupHeaderView(self.view.bounds.size)
            self.setupFooterView(self.view.bounds.size)
            self.treeView?.reloadData()
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

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setupHeaderView(size)
        setupFooterView(size)
    }
    
    func setupHeaderView(_ size:CGSize) {
        let width = size.width
        let rs = SutraDesignTokens.shared.responsiveSpacing
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // iPad: 限制内容宽度并居中
        let cx = SutraAdaptiveLayout.homeHorizontalInsets(containerSize: size)
        let cw = width - (cx * 2)

        // 🏛️ Sacred header - 含经题 + 开经偈 + 今日读经 + 卷章按钮 + 功能行
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let titleTopPadding: CGFloat = rs(isPad ? 20 : 14)
        let titleHeight: CGFloat = rs(isPad ? 34 : 28)
        let titleLineGap: CGFloat = rs(4)
        let verseFont = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .light)
        let verseLineSpacing = rs(6)
        let verseHeight = SutraAdaptiveLayout.homeOpeningVerseHeight(
            fontLineHeight: verseFont.lineHeight,
            lineSpacing: verseLineSpacing,
            minimumHeight: rs(isPad ? 56 : 44)
        )
        let verseGap: CGFloat = rs(isPad ? 20 : 12)            // 开经偈上方呼吸空间
        let buttonSectionTopGap: CGFloat = rs(isPad ? 22 : 10) // 开经偈到卷章按钮间距
        let buttonHeight: CGFloat = isPad ? 64 : max(44, rs(44))
        let verticalSpacing: CGFloat = rs(isPad ? 14 : 4)
        let toolRowPadding: CGFloat = isPad ? 16 : 12
        // Fixed UI typography does not grow with the user's reading font size,
        // so these touch rows should not inherit responsive reading spacing.
        let actionRowHeight: CGFloat = isPad ? 48 : 44
        // A compact transition is enough: the outline content explains itself.
        let outlineTransitionHeight: CGFloat = 12
        // Keep the divider on the same leading axis as the first-level outline
        // rows on both phone and iPad.
        let outlineListLeading: CGFloat = 24

        // Check if there is playback progress
        let lastPlayFile = Prefers.shared.lastPlayFile?.first
        let hasListening = lastPlayFile != nil && !lastPlayFile!.isEmpty
        let maximumToolRowHeight = actionRowHeight * 2

        let headerHeight = titleTopPadding + titleHeight + titleLineGap + verseGap + verseHeight + buttonSectionTopGap + buttonHeight * 2 + verticalSpacing + toolRowPadding + maximumToolRowHeight + outlineTransitionHeight

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
        let subTitle = UILabel()
        let verseY = titleLineY + verseGap
        subTitle.frame = CGRect(x: cx + rs(16), y: verseY, width: cw - rs(32), height: verseHeight)
        let subTitleText = L10n.str("kai_jing_ji")
        subTitle.font = verseFont
        subTitle.numberOfLines = 2

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = verseLineSpacing
        paragraphStyle.alignment = .center
        let attributedSubTitle = NSAttributedString(string: subTitleText, attributes: [
            .font: verseFont,
            .foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary),
            .paragraphStyle: paragraphStyle
        ])
        subTitle.attributedText = attributedSubTitle
        header.addSubview(subTitle)

        let nextY = verseY + verseHeight + buttonSectionTopGap

        // 🏋️ 卷章按钮网格
        let horizontalPadding: CGFloat = rs(isPad ? 24 : 20)
        let buttonSpacing: CGFloat = rs(isPad ? 16 : 10)
        let totalSpacing = horizontalPadding * 2 + buttonSpacing * 4
        let chapterButtonWidth = (cw - totalSpacing) / 5

        let indexes = UIView(frame: CGRect(x: cx, y: nextY, width: cw, height: buttonHeight * 2 + verticalSpacing))
        var chapterTenButton: UIButton?

        for i in 1...10 {
            let row = (i - 1) / 5
            let col = (i - 1) % 5
            let x = horizontalPadding + (chapterButtonWidth + buttonSpacing) * CGFloat(col)
            let y = (buttonHeight + verticalSpacing) * CGFloat(row)

            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: x, y: y, width: chapterButtonWidth, height: buttonHeight))
            indexes.addSubview(btn)
            if i == 10 {
                chapterTenButton = btn
            }
        }
        header.addSubview(indexes)

        // ✨ 底部边界装饰性细线
        let dividerFrame = CGRect(
            x: outlineListLeading,
            y: header.frame.height - 0.5,
            width: width - outlineListLeading * 2,
            height: 0.5
        )
        let dividerLine = UIView(frame: dividerFrame)
        dividerLine.backgroundColor = decorativeGold.withAlphaComponent(0.2)
        dividerLine.autoresizingMask = [.flexibleWidth]
        header.addSubview(dividerLine)

        // ── 首页操作：科判续读 + 续听 + 搜索 + 科判 ──
        let toolRowY = indexes.frame.maxY + toolRowPadding
        let toolRow = UIView(frame: CGRect(x: cx, y: toolRowY, width: cw, height: maximumToolRowHeight))
        // UITableView may normalize its header to a slightly wider internal
        // width. Keep this row on the same fixed leading axis as the chapter
        // grid; rotations and split-view changes rebuild the entire header.
        toolRow.autoresizingMask = [.flexibleRightMargin]

        let bodyColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let baseToolFont = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
        let toolFont = isPad ? baseToolFont.withSize(22) : baseToolFont
        let toolIconSize: CGFloat = isPad ? 14 : 12
        let markerSlotWidth: CGFloat = isPad ? 18 : 16
        let outlineTarget = validatedOutlineResumeTarget()
        let outlineText: String
        let outlineAccessibilityLabel: String
        switch outlineTarget {
        case let .paged(path, _), let .tree(path):
            let name = Book.shared.itemOfPath(path)["name"] as? String ?? ""
            let fullOutlineDetail = name.isEmpty
                ? L10n.str("home_resume_unknown")
                : name
            outlineText = String(
                format: L10n.str("home_resume_format"),
                fullOutlineDetail
            )
            outlineAccessibilityLabel = String(
                format: L10n.str("home_resume_accessibility_format"),
                fullOutlineDetail
            )
        case .chapter, nil:
            outlineText = L10n.str("home_start_reading")
            outlineAccessibilityLabel = L10n.str("home_start_reading_accessibility")
        }

        let outlineResumeButton = makeHomeActionButton(
            text: outlineText,
            // A quiet scripture scroll is square at phone size and carries
            // nearly the same optical weight as the enlarged play symbol.
            symbolName: "scroll",
            alignment: .leading,
            font: toolFont,
            iconSize: toolIconSize,
            markerSlotWidth: markerSlotWidth,
            bodyColor: bodyColor
        )
        outlineResumeButton.accessibilityIdentifier = outlineTarget == nil
            ? "home.startReadingButton"
            : "home.outlineResumeButton"
        outlineResumeButton.accessibilityLabel = outlineAccessibilityLabel
        outlineResumeButton.addTarget(self, action: #selector(continueOutlineReading), for: .touchUpInside)
        toolRow.addSubview(outlineResumeButton)

        let listeningText: String
        let listeningAccessibilityLabel: String
        
        if hasListening, let trackInfo = getLastPlayTrackInfo() {
            let seconds = Prefers.shared.lastPlayTime
            if seconds >= 1.0 {
                listeningText = String(
                    format: L10n.str("home_continue_listening_with_time_format"),
                    trackInfo.name,
                    trackInfo.formattedTime
                )
                listeningAccessibilityLabel = String(
                    format: L10n.str("home_continue_listening_accessibility_with_time_format"),
                    trackInfo.name,
                    trackInfo.formattedTime
                )
            } else {
                listeningText = String(
                    format: L10n.str("home_continue_listening_format"),
                    trackInfo.name
                )
                listeningAccessibilityLabel = String(
                    format: L10n.str("home_continue_listening_accessibility_format"),
                    trackInfo.name
                )
            }
        } else {
            listeningText = L10n.str("home_start_listening")
            listeningAccessibilityLabel = L10n.str("home_start_listening")
        }
        
        let continueListeningButton = makeHomeActionButton(
            text: listeningText,
            symbolName: "play.fill",
            alignment: .leading,
            font: toolFont,
            iconSize: toolIconSize,
            markerSlotWidth: markerSlotWidth,
            bodyColor: bodyColor,
            // A filled triangle occupies much less area than the open-book
            // silhouette at the same symbol box. Scale it optically, without
            // introducing the visual weight of a play-circle button.
            iconOpticalScale: 1.14
        )
        continueListeningButton.accessibilityIdentifier = "home.listeningButton"
        continueListeningButton.accessibilityLabel = listeningAccessibilityLabel
        continueListeningButton.addTarget(self, action: #selector(continueListening), for: .touchUpInside)
        toolRow.addSubview(continueListeningButton)

        let searchText = L10n.str("home_search")
        let searchButton = makeHomeActionButton(
            text: searchText,
            symbolName: "magnifyingglass",
            alignment: .trailing,
            font: toolFont,
            iconSize: toolIconSize,
            markerSlotWidth: markerSlotWidth,
            bodyColor: bodyColor
        )
        searchButton.accessibilityIdentifier = "home.searchButton"
        searchButton.accessibilityLabel = L10n.str("home_search_accessibility")
        searchButton.addTarget(self, action: #selector(openSearch), for: .touchUpInside)
        toolRow.addSubview(searchButton)

        let fullOutlineText = L10n.str("home_outline_button")
        let fullOutlineButton = makeHomeActionButton(
            text: fullOutlineText,
            symbolName: "list.bullet",
            alignment: .trailing,
            font: toolFont,
            iconSize: toolIconSize,
            markerSlotWidth: markerSlotWidth,
            bodyColor: bodyColor
        )
        fullOutlineButton.accessibilityIdentifier = "home.fullOutlineButton"
        fullOutlineButton.accessibilityLabel = L10n.str("home_full_outline_accessibility")
        fullOutlineButton.addTarget(self, action: #selector(openRootIndex), for: .touchUpInside)
        toolRow.addSubview(fullOutlineButton)

        // Layout topology depends only on the container. Saved node/audio names
        // truncate inside stable slots and can never make the same iPad jump
        // between one and two rows.
        // AppDelegate intentionally overrides the tab bar's horizontal size class to
        // compact on newer iPadOS versions. Use the real container width here so a
        // full-width iPad still gets one row, while split/compact windows use two.
        let usesSingleActionRow = isPad && size.width >= 720
        let actionLeading = horizontalPadding
        let actionTrailing = chapterTenButton?.frame.maxX ?? (cw - horizontalPadding)
        let availableWidth = max(0, actionTrailing - actionLeading)
        // Chapter titles are centered inside generous tap targets. Inset the
        // outer actions by the same amount so their visible ink, rather than
        // only their invisible UIButton bounds, aligns with 卷一 and 卷十.
        let chapterTitleWidth = chapterTenButton?.titleLabel?.sizeThatFits(
            CGSize(width: chapterButtonWidth, height: buttonHeight)
        ).width ?? chapterButtonWidth
        let chapterTitleInset = max(
            0,
            (chapterButtonWidth - min(chapterButtonWidth, chapterTitleWidth)) / 2
        )
        toolRow.accessibilityIdentifier = usesSingleActionRow
            ? "home.actions.singleRow"
            : "home.actions.twoRows"

        if usesSingleActionRow {
            let minimumActionGap: CGFloat = 8
            // The trailing optical inset aligns the visible content with 卷十,
            // but it also consumes usable width. Size this slot from its actual
            // icon + label so the iPad single-row layout never truncates 科判.
            let fullOutlineContentWidth = markerSlotWidth
                + 6
                + ceil((fullOutlineText as NSString).size(withAttributes: [.font: toolFont]).width)
            let fullOutlineWidth = max(
                104,
                fullOutlineContentWidth + chapterTitleInset
            )
            let searchContentWidth = markerSlotWidth
                + 6
                + ceil((searchText as NSString).size(withAttributes: [.font: toolFont]).width)
            let searchWidth = max(72, searchContentWidth + 4)
            let listeningContentWidth = markerSlotWidth
                + 6
                + ceil((listeningText as NSString).size(withAttributes: [.font: toolFont]).width)
            let primaryWidths = SutraAdaptiveLayout.homeSingleRowPrimaryWidths(
                availableWidth: availableWidth,
                reservedWidth: minimumActionGap * 3 + fullOutlineWidth + searchWidth,
                preferredListeningWidth: listeningContentWidth
            )
            let resumeContentWidth = markerSlotWidth
                + 6
                + ceil((outlineText as NSString).size(withAttributes: [.font: toolFont]).width)
            let contentDistribution = SutraAdaptiveLayout.homeSingleRowContentDistribution(
                maximumResumeWidth: primaryWidths.resume,
                initialListeningWidth: primaryWidths.listening,
                preferredResumeWidth: resumeContentWidth + chapterTitleInset,
                preferredListeningWidth: listeningContentWidth,
                minimumGap: minimumActionGap
            )
            let actionGap = contentDistribution.gap

            outlineResumeButton.frame = CGRect(
                x: actionLeading,
                y: 0,
                width: contentDistribution.resume,
                height: actionRowHeight
            )
            continueListeningButton.frame = CGRect(
                x: outlineResumeButton.frame.maxX + actionGap,
                y: 0,
                width: contentDistribution.listening,
                height: actionRowHeight
            )
            searchButton.frame = CGRect(
                x: continueListeningButton.frame.maxX + actionGap,
                y: 0,
                width: searchWidth,
                height: actionRowHeight
            )
            fullOutlineButton.frame = CGRect(
                x: actionTrailing - fullOutlineWidth,
                y: 0,
                width: fullOutlineWidth,
                height: actionRowHeight
            )

            outlineResumeButton.setContentAlignment(.leading, edgeInset: chapterTitleInset)
            continueListeningButton.setContentAlignment(.center)
            searchButton.setContentAlignment(.center)
            fullOutlineButton.setContentAlignment(.trailing, edgeInset: chapterTitleInset)
            toolRow.accessibilityElements = [
                outlineResumeButton,
                continueListeningButton,
                searchButton,
                fullOutlineButton,
            ]
        } else {
            let columnGap: CGFloat = 16
            // 科判／搜索只需要稳定的紧凑宽度。把其余空间交给会随
            // 阅读与播放位置变化的续读／续听，避免在空间充足时仍过早省略。
            let trailingLabelWidth = max(
                (fullOutlineText as NSString).size(withAttributes: [.font: toolFont]).width,
                (searchText as NSString).size(withAttributes: [.font: toolFont]).width
            )
            let trailingContentWidth = markerSlotWidth + 6 + ceil(trailingLabelWidth)
            let preferredTrailingWidth = max(
                72,
                trailingContentWidth + chapterTitleInset
            )
            let actionWidths = SutraAdaptiveLayout.homeTwoRowActionWidths(
                availableWidth: availableWidth,
                columnGap: columnGap,
                preferredTrailingWidth: preferredTrailingWidth
            )
            let trailingColumnWidth = actionWidths.trailing
            let primaryColumnWidth = actionWidths.primary
            let trailingColumnX = actionTrailing - trailingColumnWidth

            outlineResumeButton.frame = CGRect(
                x: actionLeading,
                y: 0,
                width: primaryColumnWidth,
                height: actionRowHeight
            )
            fullOutlineButton.frame = CGRect(
                x: trailingColumnX,
                y: 0,
                width: trailingColumnWidth,
                height: actionRowHeight
            )
            continueListeningButton.frame = CGRect(
                x: actionLeading,
                y: actionRowHeight,
                width: primaryColumnWidth,
                height: actionRowHeight
            )
            searchButton.frame = CGRect(
                x: trailingColumnX,
                y: actionRowHeight,
                width: trailingColumnWidth,
                height: actionRowHeight
            )

            outlineResumeButton.setContentAlignment(.leading, edgeInset: chapterTitleInset)
            fullOutlineButton.setContentAlignment(.trailing, edgeInset: chapterTitleInset)
            continueListeningButton.setContentAlignment(.leading, edgeInset: chapterTitleInset)
            searchButton.setContentAlignment(.trailing, edgeInset: chapterTitleInset)
            toolRow.accessibilityElements = [
                outlineResumeButton,
                fullOutlineButton,
                continueListeningButton,
                searchButton,
            ]
        }

        let finalToolRowHeight = actionRowHeight * (usesSingleActionRow ? 1 : 2)
        toolRow.frame.size.height = finalToolRowHeight
        header.frame.size.height = headerHeight - maximumToolRowHeight + finalToolRowHeight
        dividerLine.frame.origin.y = header.frame.height - 0.5

        header.addSubview(toolRow)

        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let rs = SutraDesignTokens.shared.responsiveSpacing
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let decorativeGold = SutraDesignTokens.shared.color(for: .decorativeGold)

        // iPad: 限制内容宽度并居中
        let cx = SutraAdaptiveLayout.homeHorizontalInsets(containerSize: size)
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
        let homageText = "☸️ 南無楞嚴會上佛菩薩"
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

        // 当前正在阅读的卷：文字回到正文辅助色，状态只交给字重和短金线提示。
        let isCurrentChapter = currentChapterForHomeButtons() == chapter
        btn.backgroundColor = .clear
        btn.setTitleColor(
            SutraDesignTokens.shared.color(for: isCurrentChapter ? .textSecondary : .textPrimary),
            for: .normal
        )
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(
            for: isPad ? .buttonLarge : .buttonMedium,
            weight: isCurrentChapter ? .semibold : .regular
        )

        // 去除原本的强边框与阴影，仅留极细微的底边暗示
        btn.layer.borderWidth = 0
        btn.layer.shadowOpacity = 0

        if isCurrentChapter {
            btn.accessibilityTraits.insert(.selected)
            addCurrentChapterIndicator(to: btn)
        }

        return btn
    }

    private func currentChapterForHomeButtons() -> Int? {
        guard case let .chapter(chapter, _)? = Prefers.shared.chapterResumeTarget else {
            return nil
        }
        return chapter
    }

    private func validatedOutlineResumeTarget() -> ReadingResumeTarget? {
        guard let target = Prefers.shared.outlineResumeTarget else { return nil }
        switch target {
        case .chapter:
            return nil
        case let .paged(path, _), let .tree(path):
            return isValidResumePath(path) ? target : nil
        }
    }

    /// The first leaf carrying scripture text sits under 序分. The home label
    /// names that section, while the destination itself is an immediately
    /// readable page rather than another outline browser.
    private func initialReadableOutlinePath() -> String? {
        Book.shared.index?.first(where: { item in
            guard let path = item["path"], isValidResumePath(path) else {
                return false
            }
            return Book.shared.contents?[path]?.contains(where: { section in
                section["type"] == "sutra"
                    && !(section["content"]?.isEmpty ?? true)
            }) == true
        })?["path"]
    }

    private func isValidResumePath(_ path: String) -> Bool {
        Book.shared.isValidResumePath(path)
    }

    private func addCurrentChapterIndicator(to button: UIButton) {
        let rs = SutraDesignTokens.shared.responsiveSpacing
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let indicatorWidth = min(rs(isPad ? 34 : 28), button.bounds.width * 0.5)
        let indicatorHeight = CGFloat(1)
        let indicatorY = button.bounds.height - rs(isPad ? 10 : 7)
        let indicator = UIView(frame: CGRect(
            x: (button.bounds.width - indicatorWidth) / 2,
            y: indicatorY,
            width: indicatorWidth,
            height: indicatorHeight
        ))
        indicator.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.65)
        indicator.layer.cornerRadius = indicatorHeight / 2
        indicator.isUserInteractionEnabled = false
        indicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]
        button.addSubview(indicator)
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
        // Only the most recently read volume has a retained position. Tapping
        // any other volume starts that volume at its beginning.
        let offset: CGFloat?
        if case let .chapter(savedChapter, savedOffset)? = Prefers.shared.chapterResumeTarget,
           savedChapter == chapter,
           savedOffset.isFinite,
           savedOffset > 0 {
            offset = savedOffset
        } else {
            offset = nil
        }
        let characterIndex = Prefers.shared.chapterResumeCharacterIndex(for: chapter)
        self.openChapter(
            chapter: chapter,
            restoreOffset: offset,
            restoreCharacterIndex: characterIndex
        )
    }

    
    @objc func openRootIndex() {
        self.openIndex(Book.shared.itemOfPath(""))
    }

    private func getLastPlayTrackInfo() -> (name: String, formattedTime: String)? {
        guard let lastFileName = Prefers.shared.lastPlayFile?.first,
              !lastFileName.isEmpty else {
            return nil
        }
        
        // Find the track name
        var trackName: String?
        for group in AudioManager.shared.mediaGroups {
            if let index = group.files.firstIndex(of: lastFileName) {
                if index < group.names.count {
                    trackName = group.names[index]
                    break
                }
            }
        }
        
        if trackName == nil {
            if AudioManager.shared.mediaGroups.isEmpty {
                AudioManager.shared.loadMediaData()
                for group in AudioManager.shared.mediaGroups {
                    if let index = group.files.firstIndex(of: lastFileName) {
                        if index < group.names.count {
                            trackName = group.names[index]
                            break
                        }
                    }
                }
            }
        }
        
        let displayName = displayAudioTrackName(trackName ?? lastFileName)
        
        let seconds = Prefers.shared.lastPlayTime
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let formattedTime = String(format: "%02d:%02d", minutes, remainingSeconds)
        
        return (displayName, formattedTime)
    }

    private func displayAudioTrackName(_ name: String) -> String {
        let removablePrefixes = ["楞严经 ", "楞嚴經 "]
        for prefix in removablePrefixes where name.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    private func makeHomeActionButton(
        text: String,
        symbolName: String,
        alignment: HomeActionAlignment,
        font: UIFont,
        iconSize: CGFloat,
        markerSlotWidth: CGFloat,
        bodyColor: UIColor,
        iconOpticalScale: CGFloat = 1
    ) -> HomeActionButton {
        HomeActionButton(
            text: text,
            symbolName: symbolName,
            font: font,
            iconSize: iconSize,
            markerSlotWidth: markerSlotWidth,
            bodyColor: bodyColor,
            iconOpticalScale: iconOpticalScale,
            alignment: alignment
        )
    }

    @objc private func continueListening() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = 1
        }
        
        let lastPlayFile = Prefers.shared.lastPlayFile?.first
        if lastPlayFile == nil || lastPlayFile!.isEmpty {
            AudioManager.shared.playChapter(chapter: 0)
        } else {
            AudioManager.shared.startPlayback()
        }
    }

    // MARK: - Daily Reminder Prompt

    private func maybeShowDailyReminderPrompt() {
        guard shouldShowDailyReminderPrompt else { return }

        ReminderManager.shared.authorizationStatus { [weak self] status in
            guard let self = self else { return }
            guard status == .notDetermined else { return }
            guard self.presentedViewController == nil else { return }

            Prefers.shared.hasSeenDailyReminderPrompt = true
            self.presentDailyReminderPrompt()
        }
    }

    private var shouldShowDailyReminderPrompt: Bool {
        guard !Prefers.shared.isDailyReminderOn else { return false }
        guard !Prefers.shared.hasSeenDailyReminderPrompt else { return false }
        return Prefers.shared.hasValidReadingProgress
    }

    private func presentDailyReminderPrompt() {
        let isSimplified = Book.shared.isSimplifiedChinese
        let title = isSimplified ? "每天收到一段经文？" : "每天收到一段經文？"
        let reminderTime = formattedReminderTime()
        let message = isSimplified
            ? "想每天 \(reminderTime) 在通知中心收到一段经文吗？没有声音打扰，点开就能继续读。时间可在设置里改。"
            : "想每天 \(reminderTime) 在通知中心收到一段經文嗎？沒有聲音打擾，點開就能繼續讀。時間可在設定裡改。"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: isSimplified ? "好，开启" : "好，開啟", style: .default) { [weak self] _ in
            ReminderManager.shared.requestPermissionAndSchedule { granted in
                if !granted {
                    self?.presentNotificationSettingsAlert()
                }
            }
        })
        alert.addAction(UIAlertAction(title: isSimplified ? "暂不需要" : "暫不需要", style: .cancel))

        present(alert, animated: true)
    }

    private func presentNotificationSettingsAlert() {
        let isSimplified = Book.shared.isSimplifiedChinese
        let alert = UIAlertController(
            title: isSimplified ? "通知未开启" : "通知未開啟",
            message: isSimplified
                ? "每日读经提醒需要通知权限，才能把经文显示在通知中心。请前往「设置」开启本应用的通知。"
                : "每日讀經提醒需要通知權限，才能把經文顯示在通知中心。請前往「設定」開啟本應用的通知。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: isSimplified ? "去设置" : "去設定", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: isSimplified ? "知道了" : "知道了", style: .cancel))
        present(alert, animated: true)
    }

    private func formattedReminderTime() -> String {
        String(format: "%02d:%02d", Prefers.shared.reminderHour, Prefers.shared.reminderMinute)
    }

    // MARK: - Home resume actions

    @objc private func continueOutlineReading() {
        if let target = validatedOutlineResumeTarget() {
            openResumeTarget(target)
            return
        }
        if let firstPath = initialReadableOutlinePath() {
            openResumeTarget(.tree(path: firstPath))
        } else {
            // A degraded corpus can still expose its outline for diagnosis.
            openRootIndex()
        }
    }

    private func openResumeTarget(_ resumeTarget: ReadingResumeTarget) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)

        switch resumeTarget {
        case let .chapter(chapter, offset):
            openChapter(
                chapter: chapter,
                restoreOffset: offset > 0 ? offset : nil,
                restoreCharacterIndex: Prefers.shared.chapterResumeCharacterIndex(for: chapter)
            )
        case let .tree(lastPath):
            // 科判式阅读
            let sutraVC = SutraPurePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            sutraVC.path = lastPath
            sutraVC.hidesBottomBarWhenPushed = true
            sutraVC.onDismiss = { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
            }
            self.navigationController?.pushViewController(sutraVC, animated: true)
        case let .paged(lastPath, savedPageIndex):
            // 按科判节点翻页阅读；恢复时保留用户原先使用的阅读样式。
            let pageVC = SutraPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            pageVC.hidesBottomBarWhenPushed = true
            let pageIndex: Int?
            if let index = Book.shared.index,
               index.indices.contains(savedPageIndex),
               index[savedPageIndex]["path"] == lastPath {
                pageIndex = savedPageIndex
            } else {
                pageIndex = Book.shared.index?.firstIndex(where: { $0["path"] == lastPath })
            }

            if let pageIndex = pageIndex {
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
        if longPressGestureRecognizer.state == UIGestureRecognizer.State.began {
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
        guard let path = item["path"] as? String else { return }
        pageVC.hidesBottomBarWhenPushed = true
        // 查找 path 对应页码，找不到则放弃跳转（深链指向不存在的内容时不崩溃）
        guard let pageIndex = Book.shared.index?.firstIndex(where: { $0["path"] == path }) else { return }
        pageVC.page = pageIndex

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
    
    func openChapter(
        chapter: Int,
        restoreOffset: CGFloat? = nil,
        restoreCharacterIndex: Int? = nil
    ) {
        let content = Book.shared.getSutraAttributeString(text: Book.shared.getChapterSutra(chapter: chapter))
        let title = NSLocalizedString("chapter_\(chapter + 1)", comment: "chapter_name");
        let pageVC = ReaderViewController(
            title: title,
            content: content,
            chapter: chapter,
            restoreOffset: restoreOffset,
            restoreCharacterIndex: restoreCharacterIndex
        )
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

        cell.backgroundColor = backgroundColor
        cell.textLabel?.textColor = primaryTextColor
        // 科判字体同听经列表一样，减小粗重感并偏向衬线雅正
        cell.textLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)
        cell.tintColor = accentColor
        cell.accessoryView?.tintColor = accentColor

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
    
    func treeView(_ treeView:RATreeView,  commit editingStyle:UITableViewCell.EditingStyle, forRowForItem item:Any){
    }
    
    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any] {
        return [Any]()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
