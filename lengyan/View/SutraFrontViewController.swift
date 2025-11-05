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

        // Apply Zen Temple Serenity Design System FIRST
        applyZenTempleSerenityDesignSystem()

        let bounds:CGRect = self.view.bounds;
        treeView = RATreeView(frame: CGRect(
            origin: CGPoint(x:bounds.origin.x - 5 ,y:bounds.origin.y + 0),
            size:   CGSize(width: bounds.size.width + 8 , height:bounds.size.height - 0 )));

        treeView.delegate = self
        treeView.dataSource = self
        treeView.rowHeight = 50; // Enhanced for better zen spacing
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        self.treeView.addGestureRecognizer(longPressRecognizer)
        view.addSubview(treeView)

        self.setupHeaderView(self.view.bounds.size)
        self.showList()
        self.setupFooterView(self.view.bounds.size)

        let title = self.makeSutraIndexButton("", frame: CGRect(x: 3, y: 0, width: self.view.bounds.width - 3, height: 40));
        self.navigationItem.titleView = title;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Refresh design system on appearance
        applyZenTempleSerenityDesignSystem()

        // Apply design system to navigation bar
        navigationController?.navigationBar.applySutraDesignSystem()

        // Configure navigation bar behavior
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.hidesBarsOnSwipe = false

        // Add theme switching button
        addThemeSwitchingButton()
    }

    private func addThemeSwitchingButton() {
        let themeButton = UIButton(type: .system)
        themeButton.setImage(UIImage(systemName: "paintbrush"), for: .normal)
        themeButton.tintColor = SutraThemeManager.shared.accentColor()
        themeButton.backgroundColor = SutraThemeManager.shared.surfaceColor()
        themeButton.layer.cornerRadius = 20
        themeButton.layer.borderWidth = 1
        themeButton.layer.borderColor = SutraThemeManager.shared.primaryColor().withAlphaComponent(0.3).cgColor

        themeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeButton)

        NSLayoutConstraint.activate([
            themeButton.widthAnchor.constraint(equalToConstant: 40),
            themeButton.heightAnchor.constraint(equalToConstant: 40),
            themeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            themeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        themeButton.addTarget(self, action: #selector(themeButtonTapped), for: .touchUpInside)
    }

    @objc private func themeButtonTapped() {
        SutraThemeManager.shared.toggleTheme()

        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Refresh the UI
        applyZenTempleSerenityDesignSystem()
        enhanceChapterButtons()
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
        let theme = SutraThemeManager.shared.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: theme)
    }

    private func setupThemeObserverForView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChangeForFrontViewController),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChangeForFrontViewController() {
        applyThemeColorsToView()
        configureTreeViewWithDesignSystem()
        enhanceChapterButtons()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTreeViewWithDesignSystem() {
        let theme = SutraThemeManager.shared.currentTheme

        // Apply design system colors to tree view
        // Guard against treeView not being initialized yet (can happen during early notification calls)
        guard let treeView = treeView else { return }

        treeView.backgroundColor = .clear
        view.backgroundColor = SutraColors.Semantic.background(theme: theme)

        // Enhanced spacing for zen reading experience
        treeView.rowHeight = 50
        treeView.separatorStyle = RATreeViewCellSeparatorStyleNone
    }

    private func setupZenBackgroundGradient() {
        // Remove any existing background views
        for subview in view.subviews {
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }

        // Create zen gradient background
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.tag = 999
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = backgroundView.bounds
        gradientLayer.colors = [
            UIColorFromRGB(0xFAF9F6).cgColor, // Zen rice paper
            UIColorFromRGB(0xFFFEFB).cgColor,  // Pure meditation surface
            UIColorFromRGB(0xF8F7F4).cgColor   // Subtle zen texture
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
        let theme = SutraThemeManager.shared.currentTheme

        // Enhanced zen styling using design system
        if buttonText.contains("卷") || buttonText.contains("品") {
            // Chapter button - sacred temple styling with design system
            button.backgroundColor = SutraColors.Semantic.surface(theme: theme)
            button.setTitleColor(SutraColors.Semantic.chapterTitle(theme: theme), for: .normal)
            button.titleLabel?.font = UIFont.sutraFont(style: SutraTypography.TextStyle.sectionTitle)

            // Design system corner radius and shadows
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 2
            button.layer.borderColor = SutraColors.Light.bookmark.cgColor // Golden sacred border
            button.layer.applyToken(shadow: SutraDesignTokens.ShadowTokens.shadowSubtle)

            // Add subtle gradient background
            addZenGradientToButton(button)

        } else if buttonText.contains("楞嚴經") || buttonText.contains("首楞嚴經") {
            // Main title - enhanced zen styling with design system
            button.backgroundColor = .clear
            button.setTitleColor(SutraColors.Semantic.primary(theme: theme), for: .normal)
            button.titleLabel?.font = UIFont.sutraFont(style: SutraTypography.TextStyle.chapterTitle)
            button.titleLabel?.textAlignment = .center

        } else {
            // Other buttons - subtle zen styling with design system
            button.backgroundColor = SutraColors.Semantic.background(theme: theme)
            button.setTitleColor(SutraColors.Semantic.primary(theme: theme), for: .normal)
            button.titleLabel?.font = UIFont.sutraFont(style: SutraTypography.TextStyle.buttonMedium)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = SutraColors.Semantic.divider(theme: theme).cgColor
            button.layer.applyToken(shadow: SutraDesignTokens.ShadowTokens.shadowSubtle)
        }

        // Enhanced touch feedback for all buttons
        enhanceButtonTouchFeedback(button)
    }

    private func addZenGradientToButton(_ button: UIButton) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = button.bounds
        gradientLayer.colors = [
            UIColorFromRGB(0xFFFEFB).cgColor,
            UIColorFromRGB(0xFAF9F6).cgColor
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
        // Remove existing touch targets
        button.removeTarget(self, action: nil, for: .allEvents)

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
        // Use Zen Temple Serenity colors
        return (
            background: UIColorFromRGB(0xFAF9F6),
            accent: UIColorFromRGB(0x8B4513),
            primaryText: UIColorFromRGB(0x1C2A39)
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupHeaderView(size)
        setupFooterView(size)
    }
    
    func setupHeaderView(_ size:CGSize) {
        let width = size.width
        let colors = currentColors

        print("🎨 Setting up header with theme: \(currentTheme)")

        let header:UIView = UIView(frame: CGRect(x: 0, y:0, width: width, height: 18 + 90 + 10))
        header.backgroundColor = colors.background

        let indexes = UIView(frame: CGRect(x: 0, y: 20, width: width, height: 88));
        let chapterButtonWidth=(width - 20)/5;
        for i in 1...10 {
            let btn = self.makeSutraChapterButton(i - 1, frame: CGRect(x: Int(10 + Float(chapterButtonWidth) * Float((i>5 ? i - 5 : i) - 1)), y: i<6 ? 0 : 44, width: Int(chapterButtonWidth), height: 44));

            // Enhanced styling for chapter buttons - make them more visible
            btn.backgroundColor = colors.chapterButton
            btn.setTitleColor(colors.primaryText, for: .normal)
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth = 2  // Thicker border for visibility
            btn.layer.borderColor = colors.accent.cgColor  // Use accent color for border

            // Add shadow for better visibility
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 4
            btn.layer.shadowOpacity = 0.2

            indexes.addSubview(btn);
        }
        let subTitle = UIButton.init(type: .custom);
        subTitle.frame = CGRect(x: 12, y: 5, width: width-10, height: 15);
        let subTitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subTitle.setTitle(subTitleText, for: UIControlState())
        subTitle.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subTitle.titleLabel!.adjustsFontSizeToFitWidth = true;
        subTitle.setTitleColor(colors.secondaryText, for: UIControlState())
        subTitle.addTarget(self, action: #selector(self.openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)
        header.addSubview(indexes)


        let px = 1 / UIScreen.main.scale
        let frame = CGRect(x: 0, y: header.frame.height - px, width: self.treeView.frame.size.width, height: px)
        let line: UIView = UIView(frame: frame)
        line.backgroundColor = colors.separator
        header.addSubview(line)
        self.treeView.treeHeaderView = header
    }
    
    func setupFooterView(_ size:CGSize) {
        let width = size.width
        let colors = currentColors

        let footerSeperator = UIView(frame: CGRect(x: 0, y: 2, width: width - 10, height: 1))
        footerSeperator.backgroundColor = colors.separator

        let footerText1 = NSLocalizedString("footer_txt_1", comment: "南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩")
        let footerText2 = NSLocalizedString("footer_txt_2", comment: "經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站")
        let footerText3 = NSLocalizedString("footer_txt_3", comment: "感恩法界佛教總會！本屏中列出部分關鍵科判以方便檢索，可點擊經名打開完整科判。")
        let footerLabel = UILabel(frame: CGRect(x: 20, y: 10, width: width - 20, height: 60))
        footerLabel.text = footerText1
        footerLabel.numberOfLines = 3
        footerLabel.textAlignment = .center
        footerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        footerLabel.textColor = colors.primaryText
        footerLabel.adjustsFontSizeToFitWidth = true;

        let linkButton = UIButton(frame: CGRect(x: 10, y: 70, width: width - 30, height: 20))
        linkButton.setTitle(footerText2, for: .normal)
        linkButton.contentHorizontalAlignment = .center
        linkButton.setImage(UIImage.init(named: "ic_link")?.withRenderingMode(.alwaysTemplate), for: .normal)
        linkButton.addTarget(self, action: #selector(self.openDrbaLink(_:)), for: .touchUpInside)
        linkButton.semanticContentAttribute = .forceRightToLeft
        linkButton.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        linkButton.titleLabel?.adjustsFontSizeToFitWidth = true;
        linkButton.setTitleColor(colors.accent, for: .normal)
        linkButton.backgroundColor = colors.background
        linkButton.tintColor = colors.accent

        let footerLabel2 = UILabel(frame: CGRect(x: 10, y: 85, width: width - 20, height: 40))
        footerLabel2.text = footerText3
        footerLabel2.textAlignment = .center
        footerLabel2.numberOfLines = 3
        footerLabel2.font = UIFont.systemFont(ofSize: 10)
        footerLabel2.textColor = colors.secondaryText
        footerLabel2.adjustsFontSizeToFitWidth = true;

        let footer:UIView = UIView(frame: CGRect(x: 5, y: 2, width: width - 20, height: 140))
        footer.backgroundColor = colors.background
        footer.addSubview(footerSeperator)
        footer.addSubview(footerLabel)
        footer.addSubview(linkButton)
        footer.addSubview(footerLabel2)
        self.treeView.treeFooterView = footer
    }
    func makeSutraChapterButton(_ chapter:Int, frame:CGRect?) ->UIButton {
        let btn = UIButton.init(type: .custom);
        if(frame != nil) {
            btn.frame = frame!
        }
        btn.setTitle(NSLocalizedString("chapter_\(chapter+1)", comment: "chapter_name"), for: UIControlState())
        btn.addTarget(self, action: #selector(onSutraChapterButtonTouchUp(_:)), for: .touchUpInside)
        btn.tag = chapter
        btn.titleLabel?.adjustsFontSizeToFitWidth = true;
        btn.setTitleColor(UIColor.black, for: UIControlState())
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return btn;
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
        btn.setTitleColor(UIColor.black, for: UIControlState())
        btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
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
        self.tree = Book.shared.getKeyItems();
        self.treeView.reloadData()
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
            return self.tree?.count ?? 0
        } else {
            return 0
        }
    }
    
    public func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        var newCell = treeView.dequeueReusableCell(withIdentifier: "indexCell") as? UITableViewCell;

        if (newCell == nil) {
            newCell = UITableViewCell.init(style:.value1,reuseIdentifier:"indexCell");
            newCell!.textLabel?.adjustsFontSizeToFitWidth = true;
            let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote);
            newCell!.textLabel?.font = UIFont .systemFont(ofSize: font.pointSize + 2, weight: UIFont.Weight.regular);
        }
        let cell = newCell!;
        let item = item as! [String];
        let name = item[1];
        cell.textLabel?.text =  name

        // Apply enhanced design system styling
        let colors = currentColors
        cell.backgroundColor = colors.background
        cell.textLabel?.textColor = colors.primaryText
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        cell.tintColor = colors.accent
        cell.accessoryView?.tintColor = colors.accent

        // Add enhanced selection background
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = colors.chapterButton
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
    private var currentTheme: Theme = .light

    enum Theme {
        case light, sepia, dark
    }

    private func setupEnhancedDesign() {
        print("🎨 Applying enhanced design")

        // Apply enhanced colors immediately
        let colors = currentColors
        view.backgroundColor = colors.background
        treeView.backgroundColor = colors.background
        treeView.separatorColor = colors.separator

        // Enhanced navigation bar styling
        navigationController?.navigationBar.backgroundColor = colors.navigationBar
        navigationController?.navigationBar.barTintColor = colors.navigationBar
        navigationController?.navigationBar.tintColor = colors.primaryText

        // Apply enhanced typography to existing title
        if let titleButton = navigationItem.titleView as? UIButton {
            titleButton.setTitleColor(colors.primaryText, for: .normal)
            titleButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        }

        print("✅ Enhanced design applied successfully")
    }

    private var currentColors: (background: UIColor, primaryText: UIColor, secondaryText: UIColor, accent: UIColor, chapterButton: UIColor, navigationBar: UIColor, separator: UIColor) {
        switch currentTheme {
        case .light:
            return (
                background: UIColor.white,
                primaryText: UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0),
                secondaryText: UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),
                accent: UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0),
                chapterButton: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
                navigationBar: UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0),
                separator: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
            )
        case .sepia:
            return (
                background: UIColor(red: 0.95, green: 0.88, blue: 0.75, alpha: 1.0), // More noticeable sepia
                primaryText: UIColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1.0),
                secondaryText: UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0),
                accent: UIColor(red: 0.75, green: 0.55, blue: 0.30, alpha: 1.0),
                chapterButton: UIColor(red: 0.88, green: 0.80, blue: 0.65, alpha: 1.0), // More visible
                navigationBar: UIColor(red: 0.92, green: 0.85, blue: 0.72, alpha: 1.0),
                separator: UIColor(red: 0.65, green: 0.55, blue: 0.45, alpha: 1.0) // More visible separator
            )
        case .dark:
            return (
                background: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
                primaryText: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
                secondaryText: UIColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0),
                accent: UIColor(red: 0.60, green: 0.75, blue: 0.85, alpha: 1.0),
                chapterButton: UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1.0),
                navigationBar: UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0),
                separator: UIColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 1.0)
            )
        }
    }

}
