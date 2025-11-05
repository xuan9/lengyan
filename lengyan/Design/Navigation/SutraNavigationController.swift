//
//  SutraNavigationController.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Sacred Navigation Controller
class SutraNavigationController: UINavigationController {

    private var statusBarStyle: UIStatusBarStyle = .default
    private var isNavigationBarHiddenState = false
    private var hideNavigationBarGesture: UITapGestureRecognizer?

    public var onThemeChange: ((SutraTheme) -> Void)?
    public var onBookmarkToggle: ((Bool) -> Void)?

    // Closure properties for iOS 13 fallback
    private var bookmarkAction: (() -> Void)?
    private var shareAction: (() -> Void)?
    private var themeToggleAction: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSacredNavigation()
    }

    private func setupSacredNavigation() {
        // Configure navigation bar for sacred content
        configureNavigationBar()
        setupGestureRecognizers()
        applyTheme(.light) // Default theme
    }

    private func configureNavigationBar() {
        let navigationBar = self.navigationBar

        // Remove shadow for cleaner appearance
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)

        // Configure appearance
        navigationBar.isTranslucent = false
        navigationBar.prefersLargeTitles = false

        // Back button appearance
        navigationBar.backIndicatorImage = UIImage(systemName: "chevron.left")?.withTintColor(
            SutraColors.Light.primary,
            renderingMode: .alwaysTemplate
        )
        navigationBar.backIndicatorTransitionMaskImage = navigationBar.backIndicatorImage

        // Configure custom appearance
        updateNavigationBarAppearance(for: .light)
    }

    private func setupGestureRecognizers() {
        hideNavigationBarGesture = UITapGestureRecognizer(target: self, action: #selector(toggleNavigationBar))
        view.addGestureRecognizer(hideNavigationBarGesture!)
    }

    @objc private func toggleNavigationBar() {
        let shouldHide = !isNavigationBarHiddenState

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.setNavigationBarHidden(shouldHide, animated: false)
            self.isNavigationBarHiddenState = shouldHide
        }

        SutraHapticManager.shared.haptic(.light)
    }

    public func applyTheme(_ theme: SutraTheme) {
        updateNavigationBarAppearance(for: theme)
        updateStatusBarStyle(for: theme)
        onThemeChange?(theme)
    }

    private func updateNavigationBarAppearance(for theme: SutraTheme) {
        let colors = SutraColors.Semantic.self

        let appearance = UINavigationBarAppearance()

        // Configure appearance based on theme
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.surface(theme: theme)
        appearance.titleTextAttributes = [
            .font: UIFont.sutraFont(style: SutraTypography.TextStyle.navigationTitle),
            .foregroundColor: colors.primary(theme: theme)
        ]

        // Configure large title appearance if needed
        appearance.largeTitleTextAttributes = [
            .font: UIFont.sutraFont(style: SutraTypography.TextStyle.sectionTitle),
            .foregroundColor: colors.primary(theme: theme)
        ]

        // Configure button appearance
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .font: UIFont.sutraFont(style: SutraTypography.TextStyle.buttonMedium),
            .foregroundColor: colors.primary(theme: theme)
        ]

        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance

        // Apply appearance
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance

        // Update tintColor for system icons
        navigationBar.tintColor = colors.primary(theme: theme)
    }

    private func updateStatusBarStyle(for theme: SutraTheme) {
        switch theme {
        case .light, .sepia:
            statusBarStyle = .default
        case .dark:
            statusBarStyle = .lightContent
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }

    public func configureSacredBarButtons(
        isBookmarked: Bool,
        onBookmark: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onThemeToggle: @escaping () -> Void
    ) {
        guard let topViewController = topViewController else { return }

        // Store closures for iOS 13 fallback
        bookmarkAction = onBookmark
        shareAction = onShare
        themeToggleAction = onThemeToggle

        // Create bookmark button with sacred interaction
        let bookmarkButton = SutraInteractiveButton(type: .custom)
        bookmarkButton.interactionStyle = .sacred
        bookmarkButton.isBookmark = isBookmarked
        bookmarkButton.setImage(
            UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark"),
            for: .normal
        )
        bookmarkButton.tintColor = isBookmarked ? SutraColors.Light.bookmark : SutraColors.Light.primary
        bookmarkButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)

        if #available(iOS 14.0, *) {
            bookmarkButton.addAction(UIAction { _ in
                onBookmark()
                self.onBookmarkToggle?(!isBookmarked)
            }, for: .touchUpInside)
        } else {
            // Fallback for iOS 13
            bookmarkButton.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        }

        // Create share button
        let shareButton = SutraInteractiveButton(type: .custom)
        shareButton.interactionStyle = .standard
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = SutraColors.Light.primary
        shareButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        if #available(iOS 14.0, *) {
            shareButton.addAction(UIAction { _ in onShare() }, for: .touchUpInside)
        } else {
            shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        }

        // Create theme toggle button
        let themeButton = SutraInteractiveButton(type: .custom)
        themeButton.interactionStyle = .subtle
        themeButton.setImage(UIImage(systemName: "paintbrush"), for: .normal)
        themeButton.tintColor = SutraColors.Light.primary
        themeButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        if #available(iOS 14.0, *) {
            themeButton.addAction(UIAction { _ in onThemeToggle() }, for: .touchUpInside)
        } else {
            themeButton.addTarget(self, action: #selector(themeTapped), for: .touchUpInside)
        }

        // Configure bar button items
        let bookmarkBarButtonItem = UIBarButtonItem(customView: bookmarkButton)
        let shareBarButtonItem = UIBarButtonItem(customView: shareButton)
        let themeBarButtonItem = UIBarButtonItem(customView: themeButton)

        topViewController.navigationItem.rightBarButtonItems = [
            themeBarButtonItem,
            shareBarButtonItem,
            bookmarkBarButtonItem
        ]
    }

    public func updateBookmarkState(_ isBookmarked: Bool) {
        guard let topViewController = topViewController,
              let rightBarButtonItems = topViewController.navigationItem.rightBarButtonItems,
              let bookmarkButton = rightBarButtonItems.last?.customView as? SutraInteractiveButton else {
            return
        }

        bookmarkButton.isBookmark = isBookmarked
        bookmarkButton.setImage(
            UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark"),
            for: .normal
        )
        bookmarkButton.tintColor = isBookmarked ? SutraColors.Light.bookmark : SutraColors.Light.primary

        // Animate the bookmark change
        SutraAnimationPresets.bookmarkToggleAnimation(on: bookmarkButton, isBookmarked: isBookmarked)
    }

    // MARK: - Enhanced Push/Pop with Sacred Animations

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if animated {
            viewController.view.alpha = 0
            viewController.view.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        }

        super.pushViewController(viewController, animated: false)

        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                viewController.view.alpha = 1
                viewController.view.transform = .identity
            }

            SutraHapticManager.shared.haptic(.light)
        }
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        guard let viewController = topViewController else { return nil }

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                viewController.view.alpha = 0
                viewController.view.transform = CGAffineTransform(translationX: self.view.bounds.width, y: 0)
            }

            SutraHapticManager.shared.haptic(.light)
        }

        return super.popViewController(animated: false)
    }

    // MARK: - iOS 13 Fallback Target Actions
    @objc private func bookmarkTapped() {
        bookmarkAction?()
    }

    @objc private func shareTapped() {
        shareAction?()
    }

    @objc private func themeTapped() {
        themeToggleAction?()
    }
}

// MARK: - Sacred Title View
class SacredTitleView: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()

    private var currentTheme: SutraTheme = .light {
        didSet { updateAppearance() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTitleView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTitleView()
    }

    private func setupTitleView() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        setupConstraints()
        updateAppearance()
    }

    private func setupConstraints() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Icon constraints
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            // Title constraints
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),

            // Subtitle constraints
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateAppearance() {
        let colors = SutraColors.Semantic.self

        backgroundColor = UIColor.clear

        titleLabel.font = UIFont.sutraFont(style: SutraTypography.TextStyle.navigationTitle)
        titleLabel.textColor = colors.primary(theme: currentTheme)
        titleLabel.textAlignment = .center

        subtitleLabel.font = UIFont.sutraFont(style: SutraTypography.TextStyle.caption)
        subtitleLabel.textColor = colors.textSecondary(theme: currentTheme)
        subtitleLabel.textAlignment = .center

        iconImageView.tintColor = colors.accent(theme: currentTheme)
        iconImageView.contentMode = .scaleAspectFit
    }

    public func configure(title: String, subtitle: String? = nil, icon: UIImage? = nil, theme: SutraTheme = .light) {
        currentTheme = theme
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        iconImageView.image = icon
        iconImageView.isHidden = icon == nil

        updateAppearance()
    }

    public func updateTheme(_ theme: SutraTheme) {
        currentTheme = theme
        updateAppearance()
    }

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        let subtitleSize = subtitleLabel.isHidden ? .zero : subtitleLabel.intrinsicContentSize

        let width = max(titleSize.width, subtitleSize.width) + (iconImageView.isHidden ? 0 : 32)
        let height = titleSize.height + subtitleSize.height

        return CGSize(width: max(width, 100), height: max(height, 44))
    }
}