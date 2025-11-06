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

        // Zen card container with unified color system
        containerView.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.15
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Enhanced text view with design system styling
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor.clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(
            top: SutraSpacing.Base.md,
            left: SutraSpacing.Base.md,
            bottom: SutraSpacing.Base.md,
            right: SutraSpacing.Base.md
        )
        textView.showsVerticalScrollIndicator = false

        containerView.addSubview(textView)

        // Design system spacing
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SutraSpacing.Base.sm),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.Base.md),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.Base.md),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SutraSpacing.Base.sm),

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

        switch type {
        case "sutra":
            // Sutra text - primary zen styling
            textStyle = .sutraBody
            textView.textColor = SutraDesignTokens.shared.color(for: .sutraText)

        case "index":
            // Index text - lighter zen styling
            textStyle = .indexItem
            textView.textColor = SutraDesignTokens.shared.color(for: .textPrimary)

        default: // commentary
            // Commentary text - medium zen styling
            textStyle = .commentary
            textView.textColor = SutraDesignTokens.shared.color(for: .commentaryText)
        }

        // Apply unified SutraTypography
        textView.font = SutraTypographyManager.shared.uiFont(for: textStyle, weight: .regular)

        // Set text directly - font and color already applied above
        textView.text = content
    }

    private func paragraphStyle(lineHeight: CGFloat, letterSpacing: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = (textView.font!.lineHeight * lineHeight) - textView.font!.lineHeight
        style.paragraphSpacing = 8
        style.firstLineHeadIndent = 0

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style,
            .kern: letterSpacing
        ]

        if let attributedText = textView.attributedText {
            textView.attributedText = NSAttributedString(string: attributedText.string, attributes: attributes)
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
        backgroundColor = SutraDesignTokens.shared.color(for: .background)
        containerView.backgroundColor = SutraDesignTokens.shared.color(for: .surface)

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
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
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
        applyThemeColorsToView()
        configureTableViewWithDesignSystem()

        // Reload table to update cells
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTableViewWithDesignSystem() {
        // Apply unified color system colors
        tableView.backgroundColor = .clear
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
        statusBarOverlay.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
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
        navigationController.navigationBar.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        navigationController.navigationBar.shadowImage = UIImage()
        navigationController.navigationBar.isTranslucent = true

        // Enhanced navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        appearance.shadowColor = SutraDesignTokens.shared.color(for: .divider)
        appearance.shadowImage = UIImage()
        // Use unified SutraTypography design system for consistent navigation titles
        appearance.titleTextAttributes = [
            .font: SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .semibold),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary)
        ]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
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
    paragraphStyle.lineHeightMultiple = 1.6
    paragraphStyle.maximumLineHeight = 40.0
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

        // Add subtle entrance animation
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.4, delay: Double(row) * 0.05, options: .curveEaseOut) {
            cell.alpha = 1
            cell.transform = .identity
        }

        return cell
    }
    
    func zenActionRow() -> UITableViewCell{
        if (navigationController?.isNavigationBarHidden ?? true){
            return UITableViewCell()
        }

        let cell = UITableViewCell()
        cell.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        cell.selectionStyle = .none

        // Zen card container for action buttons
        let actionContainer = UIView()
        actionContainer.backgroundColor = SutraDesignTokens.shared.color(for: .surface)
        actionContainer.layer.cornerRadius = 20
        actionContainer.layer.shadowColor = UIColor.black.cgColor
        actionContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        actionContainer.layer.shadowRadius = 16
        actionContainer.layer.shadowOpacity = 0.12
        actionContainer.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(actionContainer)

        // Create zen-styled action buttons
        let shareButton = createZenActionButton(
            iconName: "square.and.arrow.up",
            action: #selector(share(sender:)),
            title: "分享"
        )

        let pureSutraButton = createZenActionButton(
            iconName: "book",
            action: #selector(SutraPageContentViewController.pureSutra),
            title: "原文"
        )

        let bookmarkButton = createZenActionButton(
            iconName: Prefers.shared.isLike(path) ? "heart.fill" : "heart",
            action: #selector(toggleLike),
            title: "收藏"
        )

        // Stack view for button arrangement
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.alignment = .center
        buttonStack.spacing = 20
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        if meta["children"] != nil {
            buttonStack.addArrangedSubview(shareButton)
            buttonStack.addArrangedSubview(pureSutraButton)
            buttonStack.addArrangedSubview(bookmarkButton)
        } else {
            buttonStack.addArrangedSubview(shareButton)
            buttonStack.addArrangedSubview(bookmarkButton)
        }

        actionContainer.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            // Action container constraints
            actionContainer.topAnchor.constraint(equalTo: cell.topAnchor, constant: 16),
            actionContainer.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 20),
            actionContainer.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20),
            actionContainer.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -16),

            // Button stack constraints
            buttonStack.topAnchor.constraint(equalTo: actionContainer.topAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor, constant: -20),

            // Button size constraints
            shareButton.heightAnchor.constraint(equalToConstant: 60),
            pureSutraButton.heightAnchor.constraint(equalToConstant: 60),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        return cell
    }

    private func createZenActionButton(iconName: String, action: Selector, title: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = SutraDesignTokens.shared.color(for: .divider).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = SutraDesignTokens.shared.color(for: .accent)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        // Use unified SutraTypography design system for consistent button titles
        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        titleLabel.textColor = SutraDesignTokens.shared.color(for: .accent)
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
    
    @objc func toggleLike() {
        if Prefers.shared.isLike(path) {
            Prefers.shared.unlike(path)
            navigationController?.navigationBar.tintColor = UIColor.lightGray
        } else {
            Prefers.shared.like(path)
            navigationController?.navigationBar.tintColor = view.tintColor
        }
    }
    
    @objc func pureSutra(){
        
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
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
