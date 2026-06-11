//
//  SutraPageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

protocol SutraPage {
    var pageIndex:Int {get set}
    func updateTheme(_ theme: SutraTheme)
}

func UIColorFromRGB(_ rgbValue: UInt) -> UIColor {
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

class SutraTableViewCell: UITableViewCell {

    var textView: UITextView!
    private let containerView = UIView()
    private var contentType: String = ""
    private var containerLeadingConstraint: NSLayoutConstraint!
    private var containerTrailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupZenCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupZenCell()
    }

    func setupZenCell() {
        selectionStyle = .none

        // Apply design system theme
        applyThemeColors()

        // Setup theme observer for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )

        // 🏛️ Sacred Zen card container - 极致扁平化，宣纸质感
        containerView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        containerView.layer.cornerRadius = 0
        containerView.layer.shadowOpacity = 0
        containerView.layer.borderWidth = 0
        
        // 【视觉锚点】：在宽广的宣纸上，用一根若隐若现的古金细线（左侧边框）托住经文的版心
        let leftBorder = CALayer()
        leftBorder.name = "zenAnchorLine"
        leftBorder.backgroundColor = SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.3).cgColor
        containerView.layer.addSublayer(leftBorder)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // 📜 Sacred text view with divine reading experience
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false

        // 经文篇章留白体系 - 无缝长轴中的段落呼吸感
        textView.layer.shadowColor = UIColor.clear.cgColor  // 移除文本无用阴影
        textView.textContainerInset = UIEdgeInsets(
            top: 12,
            left: 16,
            bottom: 24, // 下留白更大，产生自然的段落间隔
            right: 16
        )

        // 与 ReaderViewController 保持一致，使用系统默认值
        textView.textContainer.lineFragmentPadding = 5.0
        textView.showsVerticalScrollIndicator = false

        containerView.addSubview(textView)

        containerLeadingConstraint = containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        containerTrailingConstraint = containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)

        // Seamless scroll structure - no borders or horizontal gaps
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            containerLeadingConstraint,
            containerTrailingConstraint,
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),

            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    func configureWithZenStyle(content: String, type: String) {
        contentType = type

        // Configure typography using unified design system
        let textStyle: SutraTypographyStyle
        var textColor: UIColor

        switch type {
        case "sutra":
            textStyle = .sutraBody
            textColor = SutraDesignTokens.shared.color(for: .sutraText)
        case "index":
            textStyle = .indexItem
            textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        default: // commentary
            textStyle = .commentary
            textColor = SutraDesignTokens.shared.color(for: .commentaryText)
        }

        let font = SutraTypographyManager.shared.uiFont(for: textStyle, weight: .regular)
        
        // 🖋 高级排版体系 - 恢复古籍呼吸感
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.8  // 古典经卷的舒朗行高
        paragraphStyle.paragraphSpacing = 24     // 段落之间的分明停顿
        
        // Sutra 专属缩进
        if type == "sutra" {
            paragraphStyle.firstLineHeadIndent = font.pointSize * 2.0 // 传统中文首行缩进两字
        } else {
            paragraphStyle.firstLineHeadIndent = 0
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: 1.5 // 增加字间距，让视界更空灵
        ]

        textView.attributedText = NSAttributedString(string: content, attributes: attributes)
        
        // 更新左侧锚定线的显示状态（仅在经文正文时显示）
        if let borderLayer = containerView.layer.sublayers?.first(where: { $0.name == "zenAnchorLine" }) {
            borderLayer.isHidden = (type != "sutra")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let horizontalInset = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: contentView.bounds.width
        )
        containerLeadingConstraint.constant = horizontalInset
        containerTrailingConstraint.constant = -horizontalInset
        
        // 动态调整金线的高度与位置
        if let borderLayer = containerView.layer.sublayers?.first(where: { $0.name == "zenAnchorLine" }) {
            borderLayer.frame = CGRect(x: 4, y: 16, width: 1, height: containerView.bounds.height - 32)
        }
    }

    private func applyTextAttributes() {
        guard let text = textView.text else { return }

        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)

        // Apply base attributes
        attributedString.addAttributes([
            .font: textView.font!,
            .foregroundColor: textView.textColor!
        ], range: range)

        // Apply paragraph styling
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.paragraphSpacing = 6
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

        textView.attributedText = attributedString
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    // MARK: - Theme Support
    public func applyThemeColors() {
        backgroundColor = SutraDesignTokens.shared.color(for: .background) // 细胞底色同样是净色
        containerView.backgroundColor = .clear // 透明度直接露底

        // Refresh text colors based on content type
        if !contentType.isEmpty {
            configureWithZenStyle(content: textView.text, type: contentType)
        }
    }

    @objc public func themeDidChange() {
        applyThemeColors()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textView.text = nil
        textView.attributedText = nil
        contentType = ""
    }
}

class SutraPageContentViewController: UITableViewController, SutraPage{

    internal var pageIndex = 0;
    var meta:[String:Any] = [:];
    var contents:[[String:String]] = [];
    var path:String = ""
    weak var parentReader: SutraPageViewController?

    // Zen design properties
    private let zenBackgroundView = UIView()
    private let statusBarOverlay = UIView()
    var sutraFont:UIFont? = nil, comentFont:UIFont? = nil, indexFont:UIFont? = nil;

    // Enhanced properties for SutraEnhancedPageViewController
    var onThemeChange: ((SutraTheme) -> Void)?
    private var fontScale: CGFloat = 1.0

    func adjustFontSize(_ scale: CGFloat) {
        fontScale = scale
        tableView.reloadData()
    }

    // MARK: - SutraPage Protocol Conformance
    func updateTheme(_ theme: SutraTheme) {
        applyThemeColorsToView()
        configureTableViewWithDesignSystem()
        initFontsWithDesignSystem()
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Apply Zen Temple Serenity Design System
        applyZenTempleSerenityDesignSystem()

        // STORYBOARD REMOVAL: Register cell class programmatically
        self.tableView.register(SutraTableViewCell.self, forCellReuseIdentifier: "SutraTableViewCell")

        // SAFE: Check if Book.shared.index exists and pageIndex is valid
        guard let bookIndex = Book.shared.index,
              pageIndex >= 0 && pageIndex < bookIndex.count,
              let pageMeta = bookIndex[pageIndex] as? [String:Any],
              let pagePath = pageMeta["path"] as? String else {
            print("⚠️ ERROR: Failed to get valid page data in viewDidLoad")
            return
        }

        meta = pageMeta
        path = pagePath
        let content = Book.shared.contents?[path];
        if(content != nil){
            contents = content ?? []
            self.tableView.rowHeight = UITableViewAutomaticDimension
        } else {
            meta = Book.shared.itemOfPath(path)
            // SAFE: Check if meta has children and cast safely
            if let children = meta["children"] as? NSArray {
                for child in children {
                    if let childDict = child as? [String:Any],
                       let name = childDict["name"] as? String {
                        contents.append(["type":"index", "content": "• " + name])
                    }
                }
            }
            self.tableView.rowHeight = 60; // Increased for zen styling
        }

        self.tableView.estimatedRowHeight = 120;
    }

    private func applyZenTempleSerenityDesignSystem() {
        print("📖 APPLYING ZEN TEMPLE SERENITY DESIGN SYSTEM TO READING INTERFACE")

        // Apply theme colors and background
        applyThemeColorsToView()
        setupThemeObserverForView()

        // Configure table view with design system
        configureTableViewWithDesignSystem()

        // Initialize fonts with design system
        initFontsWithDesignSystem()

        print("✅ READING INTERFACE DESIGN SYSTEM APPLIED")
    }

    private func applyThemeColorsToView() {
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 视界极致统一
    }

    private func setupThemeObserverForView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChangeForViewController),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChangeForViewController() {
        UIView.transition(with: self.view, duration: 0.4, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
            self.applyThemeColorsToView()
            self.configureTableViewWithDesignSystem()
            self.tableView.reloadData()
        }, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTableViewWithDesignSystem() {
        // Apply unified color system colors
        tableView.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 满屏宣纸
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)

        // Enhanced zen styling
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false

        // Design system spacing
        tableView.contentInset = UIEdgeInsets(
            top: 24,
            left: 0,
            bottom: 40,
            right: 0
        )

        // Status bar overlay for immersive reading
        statusBarOverlay.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        statusBarOverlay.alpha = 0
        statusBarOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBarOverlay)

        NSLayoutConstraint.activate([
            statusBarOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarOverlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }

    private func initFontsWithDesignSystem(){
        // Enhanced zen typography system using unified SutraTypography
        sutraFont = SutraTypographyManager.shared.uiFont(for: .sutraLarge, weight: .regular)
        comentFont = SutraTypographyManager.shared.uiFont(for: .commentary, weight: .regular)
        indexFont = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
        animateStatusBarIn()

        // Refresh design system on appearance
        applyZenTempleSerenityDesignSystem()

        // Apply design system to navigation bar
        let targetNavController = self.navigationController ?? self.parentReader?.navigationController ?? self.parent?.navigationController
        let wasNavBarHidden = targetNavController?.isNavigationBarHidden ?? false
        if wasNavBarHidden {
            targetNavController?.setNavigationBarHidden(true, animated: false)
        } else {
            targetNavController?.setNavigationBarHidden(false, animated: animated)
        }
        configureZenNavigationBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Keep contentInset left and right at 0 to prevent horizontal scrolling/floating
        tableView.contentInset = UIEdgeInsets(
            top: 24,
            left: 0,
            bottom: 40,
            right: 0
        )
        
        // Scroll indicators should match the content layout
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(
            top: 24,
            left: 0,
            bottom: 40,
            right: 0
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.scrollsToTop = false
        animateStatusBarOut()
    }

    private func animateStatusBarIn() {
        UIView.animate(withDuration: 0.4, delay: 0.3, options: .curveEaseOut) {
            self.statusBarOverlay.alpha = 1.0
        }
    }

    private func animateStatusBarOut() {
        UIView.animate(withDuration: 0.2) {
            self.statusBarOverlay.alpha = 0.0
        }
    }

    private func configureZenNavigationBar() {
        guard let navigationController = navigationController else { return }

        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.navigationBar.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        navigationController.navigationBar.shadowImage = UIImage()
        navigationController.navigationBar.isTranslucent = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = SutraDesignTokens.shared.color(for: .background)

        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        appearance.titleTextAttributes = [
            .foregroundColor: SutraDesignTokens.shared.color(for: .sutraText),
            .font: SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .semibold)
        ]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
    }

    // MARK: - Sacred Shadow Creation - 神圣阴影创建
    private func createSacredShadowImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(SutraDesignTokens.shared.color(for: .bookmark).withAlphaComponent(0.1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return image
    }

    private func createSolidColorImage(_ color: UIColor) -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
  
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath as NSIndexPath).row == contents.count {
            return 100;
        }else{
            return UITableViewAutomaticDimension;
        }
        
    }
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return contents.count + 1
    }
    
    func paragraphOf(text:String, font:UIFont?) -> NSAttributedString{
    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = 1.8
    paragraphStyle.maximumLineHeight = 80.0
    paragraphStyle.minimumLineHeight = 10.0
    
    let attributes = font == nil ? [NSAttributedStringKey.paragraphStyle: paragraphStyle]
        :  [NSAttributedStringKey.font: font!, NSAttributedStringKey.paragraphStyle: paragraphStyle]
        
   return NSAttributedString(string:text, attributes: attributes)
    
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath as NSIndexPath).row == contents.count {
            return self.zenActionRow();
        }

        // SAFE: Use optional binding instead of forced cast
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SutraTableViewCell", for: indexPath) as? SutraTableViewCell else {
            print("⚠️ ERROR: Failed to dequeue SutraTableViewCell")
            return UITableViewCell()
        }

        let row = (indexPath as NSIndexPath).row
        guard row < contents.count,
              let content = contents[row] as? [String:String],
              let contentType = content["type"],
              let textContent = content["content"] else {
            print("⚠️ ERROR: Failed to get content at row \(row)")
            return cell
        }

        // Apply comprehensive zen styling
        cell.configureWithZenStyle(content: textContent, type: contentType)

        // 含蓄的禅意入场动画
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.35, delay: Double(row) * 0.03, options: .curveEaseOut) {
            cell.alpha = 1
            cell.transform = .identity
        }

        return cell
    }
    
    func zenActionRow() -> UITableViewCell{
        let cell = UITableViewCell()
        cell.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        cell.selectionStyle = .none
        return cell
    }

    private func createZenActionButton(iconName: String, action: Selector, title: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear // 极简透明背景
        containerView.layer.cornerRadius = 0
        containerView.layer.borderWidth = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = SutraDesignTokens.shared.color(for: .textSecondary)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        // Use unified SutraTypography design system for consistent button titles
        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        titleLabel.textColor = SutraDesignTokens.shared.color(for: .textSecondary)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Button for touch handling
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Add touch feedback
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            // Icon constraints
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),

            // Button constraints (full touch area)
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Container height
            containerView.heightAnchor.constraint(equalToConstant: 60)
        ])

        return containerView
    }

    @objc private func buttonTouchDown(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.superview?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            button.superview?.alpha = 0.8
        }
    }

    @objc private func buttonTouchUp(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.superview?.transform = .identity
            button.superview?.alpha = 1.0
        }
    }
    
    @objc func pureSutra(){
        
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.scroll, navigationOrientation:.horizontal, options: .none)
        sutraVC.path = path;
        
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    
    @objc func share(sender:UIBarButtonItem) {
        var shareContents = [String]()
        let bookTitle = NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》")
        if meta["children"] == nil {
            var hasTitlePrefix:Bool = false;
            for c in contents {
                if c["type"] == "sutra" {
                    if !hasTitlePrefix {
                        shareContents.append(bookTitle)
                        hasTitlePrefix = true;
                    }
                    shareContents.append(c["content"]!)
                }
            }
        } else {
            // SAFE: Check if meta has name
            if let metaName = meta["name"] as? String {
                shareContents.append(bookTitle + "之「" + metaName + "」")
                shareContents.append(Book.shared.getSutra(meta))
            }
        }
        
        let activityViewController = UIActivityViewController(activityItems:[shareContents.joined(separator: "\n")], applicationActivities: nil)
        if let presenter = activityViewController.popoverPresentationController {
            presenter.barButtonItem = sender;
        }
        present(activityViewController, animated: true, completion: {})
    }
}
