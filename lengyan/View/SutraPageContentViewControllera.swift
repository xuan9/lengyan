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
        backgroundColor = UIColorFromRGB(0xFAF9F6) // Zen rice paper background

        // Zen card container
        containerView.backgroundColor = UIColorFromRGB(0xFFFEFB) // Pure meditation surface
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.08
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Enhanced text view with zen styling
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor.clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        textView.showsVerticalScrollIndicator = false

        containerView.addSubview(textView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    func configureWithZenStyle(content: String, type: String) {
        contentType = type

        // Configure typography based on content type
        switch type {
        case "sutra":
            // Sutra text - primary zen styling
            textView.font = UIFont(name: "PingFangTC-Medium", size: 18) ??
                          UIFont.systemFont(ofSize: 18, weight: .medium)
            textView.textColor = UIColorFromRGB(0x1A1A1A) // Deep sutra ink
            paragraphStyle(lineHeight: 1.8, letterSpacing: 0.5)

        case "index":
            // Index text - lighter zen styling
            textView.font = UIFont(name: "PingFangTC-Light", size: 16) ??
                          UIFont.systemFont(ofSize: 16, weight: .light)
            textView.textColor = UIColorFromRGB(0x5D6D7E) // Secondary zen ink
            paragraphStyle(lineHeight: 1.6, letterSpacing: 0.3)

        default: // commentary
            // Commentary text - medium zen styling
            textView.font = UIFont(name: "PingFangTC-Regular", size: 17) ??
                          UIFont.systemFont(ofSize: 17, weight: .regular)
            textView.textColor = UIColorFromRGB(0x34495E) // Commentary zen ink
            paragraphStyle(lineHeight: 1.7, letterSpacing: 0.4)
        }

        textView.text = content
        applyTextAttributes()
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

    override func prepareForReuse() {
        super.prepareForReuse()
        textView.text = nil
        textView.attributedText = nil
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupZenDesignSystem()

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
        self.initZenFonts();
    }

    private func setupZenDesignSystem() {
        // Zen background with gradient
        zenBackgroundView.frame = view.bounds
        zenBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = zenBackgroundView.bounds
        gradientLayer.colors = [
            UIColorFromRGB(0xFAF9F6).cgColor, // Zen rice paper
            UIColorFromRGB(0xFFFEFB).cgColor  // Pure meditation surface
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        zenBackgroundView.layer.addSublayer(gradientLayer)

        view.insertSubview(zenBackgroundView, at: 0)

        // Enhanced table view styling
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 40, right: 0)

        // Status bar overlay for immersive reading
        statusBarOverlay.backgroundColor = UIColorFromRGB(0xFAF9F6)
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

    private func initZenFonts(){
        // Enhanced zen typography system
        sutraFont = UIFont(name: "PingFangTC-Medium", size: 20) ??
                    UIFont.systemFont(ofSize: 20, weight: .medium)

        comentFont = UIFont(name: "PingFangTC-Regular", size: 17) ??
                     UIFont.systemFont(ofSize: 17, weight: .regular)

        indexFont = UIFont(name: "PingFangTC-Light", size: 16) ??
                    UIFont.systemFont(ofSize: 16, weight: .light)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
        animateStatusBarIn()
        configureZenNavigationBar()
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
        navigationController.navigationBar.backgroundColor = UIColorFromRGB(0xFFFEFB)
        navigationController.navigationBar.shadowImage = UIImage()
        navigationController.navigationBar.isTranslucent = true

        // Enhanced navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColorFromRGB(0xFFFEFB)
        appearance.shadowColor = UIColorFromRGB(0xE0E0E0)
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [
            .font: UIFont(name: "PingFangTC-Medium", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: UIColorFromRGB(0x1C2A39)
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
        cell.backgroundColor = UIColorFromRGB(0xFAF9F6)
        cell.selectionStyle = .none

        // Zen card container for action buttons
        let actionContainer = UIView()
        actionContainer.backgroundColor = UIColorFromRGB(0xFFFEFB)
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
        containerView.backgroundColor = UIColorFromRGB(0xFAF9F6)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColorFromRGB(0xE0E0E0).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColorFromRGB(0x8B4513) // Sacred temple wood
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont(name: "PingFangTC-Medium", size: 12) ??
                        UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColorFromRGB(0x8B4513)
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
