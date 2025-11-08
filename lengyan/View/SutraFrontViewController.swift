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
        themeButton.layer.shadowColor = UIColor.black.cgColor
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
        // NotificationCenter.default.addObserver(self, selector: #selector(themeDidChangeForFrontViewController), name: .themeDidChange, object: nil)
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
        let theme = SutraDesignTokens.shared.currentTheme
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
            if let treeView = subview as? RATreeView {
                for cellSubview in treeView.subviews {
                    if let headerView = cellSubview as? UIView {
                        enhanceButtonsInView(headerView)
                    }
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

        // Enhanced zen styling using unified design tokens
        if buttonText.contains("卷") || buttonText.contains("品") {
            // Chapter button - sacred temple styling with unified color system
            // TODO: Use design tokens - button.backgroundColor = UIColor.white
            button.setTitleColor(UIColor.systemGray, for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .semibold)

            // Design system corner radius and shadows
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.systemGray.cgColor
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.2

            // Add subtle gradient background
            addZenGradientToButton(button)

        } else if buttonText.contains("楞嚴經") || buttonText.contains("首楞嚴經") {
            // Main title - enhanced zen styling with unified color system
            button.backgroundColor = .clear
            button.setTitleColor(UIColor.systemGray, for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .uiTitle, weight: .bold)
            button.titleLabel?.textAlignment = .center

        } else {
            // Other buttons - subtle zen styling with unified color system
            button.backgroundColor = UIColor.white
            button.setTitleColor(UIColor.systemGray, for: .normal)
            button.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemGray.cgColor
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.2
        }

        // Enhanced touch feedback for all buttons
        enhanceButtonTouchFeedback(button)
    }

    private func addZenGradientToButton(_ button: UIButton) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = button.bounds

        // Use unified color system for gradient
        let surfaceColor = UIColor.white
        let cardColor = SutraDesignTokens.shared.color(for: .card)

        gradientLayer.colors = [
            surfaceColor.withAlphaComponent(0.9).cgColor,
            cardColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
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
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
            button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            button.alpha = 0.8
        }
    }

    @objc private func zenButtonTouchUp(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
            button.transform = .identity
            button.alpha = 1.0
        }
    }

    @objc private func zenButtonTapped(_ button: UIButton) {
        // Add subtle haptic feedback if available
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func getCurrentColors() -> (background: UIColor, accent: UIColor, primaryText: UIColor) {
        // Unified with SutraDesignTokens for consistency
        return (
            background: SutraDesignTokens.shared.color(for: .background),
            accent: SutraDesignTokens.shared.color(for: .accent),
            primaryText: SutraDesignTokens.shared.color(for: .textPrimary)
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupHeaderView(size)
        setupFooterView(size)
    }
    
    func setupHeaderView(_ size:CGSize) {
        let width = size.width
        let theme = SutraDesignTokens.shared.currentTheme
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let primaryTextColor = SutraDesignTokens.shared.color(for: .textPrimary)
        let accentColor = SutraDesignTokens.shared.color(for: .accent)
        let dividerColor = SutraDesignTokens.shared.color(for: .divider)

        print("🎨 Setting up header with theme: \(theme)")

        // World-class header height: 20 + 28 + 12 + 120 + 20 = 200pt
        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: 200))
        header.backgroundColor = backgroundColor

        // Elegant subtitle with proper typography (開經偈)
        let subTitle = UIButton.init(type: .custom);
        subTitle.frame = CGRect(x: 16, y: 20, width: width - 32, height: 28);
        let subTitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subTitle.setTitle(subTitleText, for: UIControlState())
        subTitle.titleLabel?.font = SutraTypographySystem().uiFont(for: .uiCaption, weight: .regular)
        subTitle.titleLabel?.numberOfLines = 2
        subTitle.titleLabel?.lineBreakMode = .byCharWrapping
        subTitle.setTitleColor(primaryTextColor.withAlphaComponent(0.65), for: UIControlState())
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)

        // World-class chapter button grid with proper spacing
        let horizontalPadding: CGFloat = 16
        let buttonSpacing: CGFloat = 8
        let totalSpacing = horizontalPadding * 2 + buttonSpacing * 4  // 4 gaps between 5 buttons
        let chapterButtonWidth = (width - totalSpacing) / 5
        let buttonHeight: CGFloat = 52  // Increased from 44pt
        let verticalSpacing: CGFloat = 8

        let indexes = UIView(frame: CGRect(x: 0, y: 68, width: width, height: buttonHeight * 2 + verticalSpacing))

        for i in 1...10 {
            let row = (i - 1) / 5  // 0 or 1
            let col = (i - 1) % 5  // 0 to 4
            let x = horizontalPadding + (chapterButtonWidth + buttonSpacing) * CGFloat(col)
            let y = (buttonHeight + verticalSpacing) * CGFloat(row)

            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: x, y: y, width: chapterButtonWidth, height: buttonHeight))

            // World-class button styling
            btn.layer.cornerRadius = 12  // More refined radius
            btn.layer.borderWidth = 1.5  // Subtle border
            btn.layer.borderColor = accentColor.withAlphaComponent(0.3).cgColor

            // Elegant shadow
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.1
            btn.layer.masksToBounds = false

            indexes.addSubview(btn);
        }
        header.addSubview(indexes)

        // Subtle divider line
        let px = 1 / UIScreen.main.scale
        let frame = CGRect(x: 16, y: header.frame.height - px, width: self.treeView.frame.size.width - 32, height: px)
        let line: UIView = UIView(frame: frame)
        line.backgroundColor = dividerColor.withAlphaComponent(0.5)
        header.addSubview(line)

        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let primaryTextColor = SutraDesignTokens.shared.color(for: .textPrimary)
        let dividerColor = SutraDesignTokens.shared.color(for: .divider)
        let secondaryTextColor = SutraDesignTokens.shared.color(for: .textSecondary)

        // World-class footer height: ~200pt for better breathing room
        let footer:UIView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 200))
        footer.backgroundColor = backgroundColor

        // Subtle top divider with proper spacing
        let footerSeperator = UIView(frame: CGRect(x: 16, y: 20, width: width - 32, height: 1))
        footerSeperator.backgroundColor = dividerColor.withAlphaComponent(0.3)
        footer.addSubview(footerSeperator)

        let footerText1 = NSLocalizedString("footer_txt_1", comment: "南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩")
        let footerText2 = NSLocalizedString("footer_txt_2", comment: "經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站")
        let footerText3 = NSLocalizedString("footer_txt_3", comment: "感恩法界佛教總會！本屏中列出部分關鍵科判以方便檢索，可點擊經名打開完整科判。")

        // Main footer label with better typography (南無楞嚴會上佛菩薩)
        let footerLabel = UILabel(frame: CGRect(x: 24, y: 36, width: width - 48, height: 70))
        footerLabel.text = footerText1
        footerLabel.numberOfLines = 3
        footerLabel.textAlignment = .center
        footerLabel.font = SutraTypographySystem().uiFont(for: .uiBody, weight: .regular)  // Larger font
        footerLabel.textColor = primaryTextColor
        footerLabel.lineBreakMode = .byWordWrapping
        footer.addSubview(footerLabel)

        // Link button with proper styling
        let linkButton = UIButton(frame: CGRect(x: 20, y: 114, width: width - 40, height: 32))
        linkButton.setTitle(footerText2, for: .normal)
        linkButton.contentHorizontalAlignment = .center
        linkButton.setImage(UIImage.init(named: "ic_link")?.withRenderingMode(.alwaysTemplate), for: .normal)
        linkButton.addTarget(self, action: #selector(self.openDrbaLink(_:)), for: .touchUpInside)
        linkButton.semanticContentAttribute = .forceRightToLeft
        linkButton.titleLabel?.font = SutraTypographySystem().uiFont(for: .uiCaption, weight: .medium)
        linkButton.titleLabel?.numberOfLines = 2
        linkButton.titleLabel?.lineBreakMode = .byCharWrapping
        linkButton.setTitleColor(SutraDesignTokens.shared.color(for: .accent), for: .normal)  // Use accent color
        linkButton.backgroundColor = backgroundColor
        linkButton.tintColor = SutraDesignTokens.shared.color(for: .accent)
        footer.addSubview(linkButton)

        // Secondary footer label with generous spacing
        let footerLabel2 = UILabel(frame: CGRect(x: 24, y: 154, width: width - 48, height: 42))
        footerLabel2.text = footerText3
        footerLabel2.textAlignment = .center
        footerLabel2.numberOfLines = 2
        footerLabel2.font = SutraTypographySystem().uiFont(for: .uiCaption, weight: .regular)
        footerLabel2.textColor = secondaryTextColor.withAlphaComponent(0.8)
        footerLabel2.lineBreakMode = .byCharWrapping
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

        // Enhanced Zen chapter button styling with better touch targets
        btn.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        btn.setTitleColor(SutraDesignTokens.shared.color(for: .textPrimary), for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .buttonMedium, weight: .medium)
        btn.layer.cornerRadius = 12  // More refined for Zen aesthetic
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.06  // More subtle
        btn.layer.shadowRadius = 3

        return btn
    }
    
    func makeSutraIndexButton(_ path:String, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        btn.setTitle(Book.shared.itemOfPath(path)["name"] as! String?, for: UIControlState())
        btn.addTarget(self, action: #selector(onSutraIndexButtonTouchUp(_:)), for: .touchUpInside)
        let count = sutraIndexButtons.count;
        btn.tag = count
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;

        // Use semantic text color instead of hardcoded black
        btn.setTitleColor(SutraDesignTokens.shared.color(for: .textPrimary), for: .normal)
        btn.titleLabel?.font = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .semibold)
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
        UIApplication.shared.openURL(URL.init(string: "http://www.drbachinese.org/online_reading/sutra_explanation/Shu/contents.htm")!)
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
        cell.textLabel?.text =  name

        // Apply enhanced design system styling
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        let primaryTextColor = SutraDesignTokens.shared.color(for: .textPrimary)
        let accentColor = SutraDesignTokens.shared.color(for: .accent)
        let cardColor = SutraDesignTokens.shared.color(for: .card)

        cell.backgroundColor = backgroundColor
        cell.textLabel?.textColor = primaryTextColor
        cell.textLabel?.font = SutraTypographySystem().uiFont(for: .indexItem, weight: .regular)
        cell.tintColor = accentColor
        cell.accessoryView?.tintColor = accentColor

        // Add world-class card styling with subtle elevation
        cell.layer.cornerRadius = 12
        cell.layer.shadowColor = UIColor.black.cgColor
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

        // Apply enhanced colors using design tokens
        view.backgroundColor = UIColor.white
        treeView.backgroundColor = UIColor.white

        // Enhanced navigation bar styling
        navigationController?.navigationBar.backgroundColor = UIColor.white
        navigationController?.navigationBar.barTintColor = UIColor.white
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
            // TODO: Use design tokens - return ColorConfig(background: .white, primaryText: .black, secondaryText: .gray, accent: .red, chapterButton: .white, navigationBar: .white, separator: .gray)
        // Color configuration will use design tokens
        }
    }

