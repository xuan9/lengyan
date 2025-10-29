//
//  DesignSystem+Components.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Component States
public enum ComponentState {
    case normal
    case highlighted
    case disabled
    case focused
    case selected
}

// MARK: - Component Variants
public enum ButtonVariant {
    case primary
    case secondary
    case tertiary
    case sacred
    case bookmark
}

public enum CardVariant {
    case sutra
    case commentary
    case index
    case chapter
}

// MARK: - Sacred Button Component
public class SutraButton: UIButton {

    public var variant: ButtonVariant = .primary {
        didSet { updateAppearance() }
    }

    public var customTheme: SutraTheme? {
        didSet { updateAppearance() }
    }

    private var currentTheme: SutraTheme {
        return customTheme ?? .light // This should be replaced with actual theme manager
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        layer.cornerRadius = SutraCornerRadius.medium
        layer.masksToBounds = true

        // Add subtle shadow for elevated appearance
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
        addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)

        updateAppearance()
    }

    private func updateAppearance() {
        let theme = currentTheme
        let colors = SutraColors.Semantic.self

        switch variant {
        case .primary:
            backgroundColor = colors.accent(theme: theme)
            setTitleColor(colors.textOnAccent(theme: theme), for: .normal)
            setTitleColor(colors.textOnAccent(theme: theme).withAlphaComponent(0.7), for: .highlighted)

        case .secondary:
            backgroundColor = colors.surface(theme: theme)
            setTitleColor(colors.primary(theme: theme), for: .normal)
            layer.borderWidth = 1
            layer.borderColor = colors.border(theme: theme).cgColor

        case .tertiary:
            backgroundColor = UIColor.clear
            setTitleColor(colors.primary(theme: theme), for: .normal)

        case .sacred:
            // Special sacred styling with gradient
            let gradient = CAGradientLayer()
            gradient.colors = [
                colors.accent(theme: theme).cgColor,
                colors.accent(theme: theme).lighter(by: 0.1).cgColor
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.frame = bounds
            gradient.cornerRadius = SutraCornerRadius.medium
            layer.insertSublayer(gradient, at: 0)
            setTitleColor(colors.textOnAccent(theme: theme), for: .normal)

        case .bookmark:
            backgroundColor = colors.surface(theme: theme)
            setTitleColor(SutraColors.Light.bookmark, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = SutraColors.Light.bookmark.cgColor
        }

        updateTypography()
    }

    private func updateTypography() {
        let textStyle: SutraTextStyle = frame.height > 44 ? .buttonLarge : .buttonMedium
        titleLabel?.font = UIFont.sutraFont(style: textStyle)
    }

    @objc private func touchDown() {
        animatePress()
    }

    @objc private func touchUpInside() {
        animateRelease()
    }

    @objc private func touchUpOutside() {
        animateRelease()
    }

    private func animatePress() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        })
    }

    private func animateRelease() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform.identity
            self.alpha = 1.0
        })
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update gradient frame if needed
        if variant == .sacred, let gradient = layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = bounds
        }
    }
}

// MARK: - Sutra Card Component
public class SutraCard: UIView {

    public var variant: CardVariant = .sutra {
        didSet { updateAppearance() }
    }

    public var customTheme: SutraTheme? {
        didSet { updateAppearance() }
    }

    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let iconImageView = UIImageView()

    private var currentTheme: SutraTheme {
        return customTheme ?? .light
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }

    private func setupCard() {
        setupContentView()
        setupLabels()
        setupIcon()
        setupConstraints()
        updateAppearance()

        // Add gesture recognizer for tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tapGesture)
    }

    private func setupContentView() {
        addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerRadius = SutraCornerRadius.medium
        contentView.layer.masksToBounds = true
    }

    private func setupLabels() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(detailLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.numberOfLines = 0
        subtitleLabel.numberOfLines = 0
        detailLabel.numberOfLines = 0
    }

    private func setupIcon() {
        contentView.addSubview(iconImageView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Icon constraints
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.Base.md),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SutraSpacing.Base.md),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: SutraSpacing.Base.md),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.Base.md),

            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: SutraSpacing.Micro.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Detail constraints
            detailLabel.topAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.bottomAnchor, constant: SutraSpacing.Micro.xs),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SutraSpacing.Base.md)
        ])
    }

    private func updateAppearance() {
        let theme = currentTheme
        let colors = SutraColors.Semantic.self

        contentView.backgroundColor = colors.card(theme: theme)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.08

        switch variant {
        case .sutra:
            titleLabel.font = UIFont.sutraFont(style: .sectionTitle)
            titleLabel.textColor = colors.sutraText(theme: theme)
            subtitleLabel.font = UIFont.sutraFont(style: .commentary)
            subtitleLabel.textColor = colors.commentaryText(theme: theme)
            detailLabel.font = UIFont.sutraFont(style: .caption)
            detailLabel.textColor = colors.textSecondary(theme: theme)

        case .commentary:
            titleLabel.font = UIFont.sutraFont(style: .indexItem)
            titleLabel.textColor = colors.commentaryText(theme: theme)
            subtitleLabel.font = UIFont.sutraFont(style: .caption)
            subtitleLabel.textColor = colors.textTertiary(theme: theme)
            detailLabel.isHidden = true

        case .index:
            titleLabel.font = UIFont.sutraFont(style: .indexItem)
            titleLabel.textColor = colors.primary(theme: theme)
            subtitleLabel.font = UIFont.sutraFont(style: .caption)
            subtitleLabel.textColor = colors.textSecondary(theme: theme)
            detailLabel.isHidden = true

        case .chapter:
            titleLabel.font = UIFont.sutraFont(style: .chapterTitle)
            titleLabel.textColor = colors.chapterTitle(theme: theme)
            subtitleLabel.font = UIFont.sutraFont(style: .label)
            subtitleLabel.textColor = colors.textSecondary(theme: theme)
            detailLabel.font = UIFont.sutraFont(style: .caption)
            detailLabel.textColor = colors.textTertiary(theme: theme)
        }
    }

    public func configure(title: String, subtitle: String? = nil, detail: String? = nil, icon: UIImage? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil
        iconImageView.image = icon
        iconImageView.isHidden = icon == nil
    }

    @objc private func cardTapped() {
        animateSelection()
    }

    private func animateSelection() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform.identity
            }
        }
    }
}

// MARK: - Reading Toolbar Component
public class ReadingToolbar: UIView {

    private let backgroundView = UIVisualEffectView()
    private let stackView = UIStackView()
    private let previousButton = SutraButton()
    private let bookmarkButton = SutraButton()
    private let shareButton = SutraButton()
    private let pureReadingButton = SutraButton()
    private let nextButton = SutraButton()

    public var customTheme: SutraTheme? {
        didSet { updateAppearance() }
    }

    private var currentTheme: SutraTheme {
        return customTheme ?? .light
    }

    public var onPrevious: (() -> Void)?
    public var onNext: (() -> Void)?
    public var onBookmark: (() -> Void)?
    public var onShare: (() -> Void)?
    public var onPureReading: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }

    private func setupToolbar() {
        setupBackground()
        setupStackView()
        setupButtons()
        setupConstraints()
        updateAppearance()
    }

    private func setupBackground() {
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = SutraCornerRadius.medium
        backgroundView.layer.masksToBounds = true
    }

    private func setupStackView() {
        backgroundView.contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = SutraSpacing.Micro.xs
    }

    private func setupButtons() {
        let buttons = [previousButton, bookmarkButton, shareButton, pureReadingButton, nextButton]

        buttons.forEach { button in
            button.variant = .tertiary
            stackView.addArrangedSubview(button)
        }

        // Configure button icons
        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        pureReadingButton.setImage(UIImage(systemName: "book.circle"), for: .normal)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)

        // Add button actions
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        pureReadingButton.addTarget(self, action: #selector(pureReadingTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: SutraSpacing.Base.sm),
            stackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: SutraSpacing.Base.sm),
            stackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -SutraSpacing.Base.sm),
            stackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -SutraSpacing.Base.sm)
        ])
    }

    private func updateAppearance() {
        let theme = currentTheme

        if theme == .dark {
            backgroundView.effect = UIBlurEffect(style: .dark)
        } else if theme == .sepia {
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = SutraColors.Sepia.background.withAlphaComponent(0.8)
        } else {
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = SutraColors.Light.background.withAlphaComponent(0.8)
        }

        let buttons = [previousButton, bookmarkButton, shareButton, pureReadingButton, nextButton]
        buttons.forEach { $0.customTheme = theme }
    }

    public func setBookmarkState(_ isBookmarked: Bool) {
        bookmarkButton.tintColor = isBookmarked ? SutraColors.Light.bookmark : nil
    }

    @objc private func previousTapped() {
        onPrevious?()
    }

    @objc private func nextTapped() {
        onNext?()
    }

    @objc private func bookmarkTapped() {
        onBookmark?()
    }

    @objc private func shareTapped() {
        onShare?()
    }

    @objc private func pureReadingTapped() {
        onPureReading?()
    }
}

// MARK: - Corner Radius Constants
public struct SutraCornerRadius {
    public static let xSmall: CGFloat = 4
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 8
    public static let large: CGFloat = 12
    public static let xLarge: CGFloat = 16
    public static let round: CGFloat = 999 // For fully rounded elements
}

// MARK: - Shadow System
public struct SutraShadow {
    public static let subtle = NSShadow()
    public static let medium = NSShadow()
    public static let strong = NSShadow()

    static init() {
        // Subtle shadow for cards and buttons
        subtle.shadowColor = UIColor.black.withAlphaComponent(0.08)
        subtle.shadowOffset = CGSize(width: 0, height: 2)
        subtle.shadowBlurRadius = 4

        // Medium shadow for floating elements
        medium.shadowColor = UIColor.black.withAlphaComponent(0.12)
        medium.shadowOffset = CGSize(width: 0, height: 4)
        medium.shadowBlurRadius = 8

        // Strong shadow for modals and overlays
        strong.shadowColor = UIColor.black.withAlphaComponent(0.2)
        strong.shadowOffset = CGSize(width: 0, height: 8)
        strong.shadowBlurRadius = 16
    }
}

// MARK: - Component Extensions
extension UIView {
    public func applyCardShadow() {
        layer.shadowColor = SutraShadow.subtle.shadowColor?.cgColor
        layer.shadowOffset = SutraShadow.subtle.shadowOffset
        layer.shadowRadius = SutraShadow.subtle.shadowBlurRadius
        layer.shadowOpacity = 0.08
    }

    public func applyFloatingShadow() {
        layer.shadowColor = SutraShadow.medium.shadowColor?.cgColor
        layer.shadowOffset = SutraShadow.medium.shadowOffset
        layer.shadowRadius = SutraShadow.medium.shadowBlurRadius
        layer.shadowOpacity = 0.12
    }

    public func applyModalShadow() {
        layer.shadowColor = SutraShadow.strong.shadowColor?.cgColor
        layer.shadowOffset = SutraShadow.strong.shadowOffset
        layer.shadowRadius = SutraShadow.strong.shadowBlurRadius
        layer.shadowOpacity = 0.2
    }
}