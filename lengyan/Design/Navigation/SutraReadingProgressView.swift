//
//  SutraReadingProgressView.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Reading Progress Delegate
protocol SutraReadingProgressDelegate: AnyObject {
    func readingProgressView(_ progressView: SutraReadingProgressView, didRequestJumpTo position: CGFloat)
    func readingProgressViewDidRequestBookmark(_ progressView: SutraReadingProgressView)
}

// MARK: - Sacred Reading Progress View
class SutraReadingProgressView: UIView {

    // MARK: - UI Components
    private let backgroundView = UIVisualEffectView()
    private let progressSlider = UISlider()
    private let progressLabel = UILabel()
    private let bookmarkButton = SutraInteractiveButton()
    private let timeLabel = UILabel()
    private let dotsView = UIView()

    // MARK: - Properties
    private var totalContent: CGFloat = 1.0
    private var currentPosition: CGFloat = 0.0
    private var estimatedReadingTime: TimeInterval = 0
    private var currentTheme: SutraTheme = .light
    private var isBookmarked: Bool = false

    weak var delegate: SutraReadingProgressDelegate?

    // MARK: - Configuration
    private let sliderHeight: CGFloat = 4
    private let controlHeight: CGFloat = 44
    private let dotCount = 20
    private var dotLayers: [CALayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupProgressView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProgressView()
    }

    private func setupProgressView() {
        setupBackground()
        setupSlider()
        setupDots()
        setupControls()
        setupConstraints()
        updateAppearance()
    }

    private func setupBackground() {
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = SutraCornerRadius.large
        backgroundView.layer.masksToBounds = true
    }

    private func setupSlider() {
        addSubview(progressSlider)
        progressSlider.translatesAutoresizingMaskIntoConstraints = false

        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.value = 0

        // Customize slider appearance
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func setupDots() {
        addSubview(dotsView)
        dotsView.translatesAutoresizingMaskIntoConstraints = false

        // Create progress dots
        for i in 0..<dotCount {
            let dotLayer = CALayer()
            dotLayer.cornerRadius = 1
            dotLayer.masksToBounds = true
            dotsView.layer.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
        }
    }

    private func setupControls() {
        addSubview(progressLabel)
        addSubview(bookmarkButton)
        addSubview(timeLabel)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .regular)
        progressLabel.textAlignment = .center

        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        bookmarkButton.interactionStyle = .sacred
        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        bookmarkButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        bookmarkButton.addAction(UIAction { _ in
            self.toggleBookmark()
        }, for: .touchUpInside)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .regular)
        timeLabel.textAlignment = .center
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background constraints
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Dots view constraints
            dotsView.topAnchor.constraint(equalTo: topAnchor, constant: SutraSpacing.Base.md),
            dotsView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SutraSpacing.Base.lg),
            dotsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SutraSpacing.Base.lg),
            dotsView.heightAnchor.constraint(equalToConstant: 20),

            // Slider constraints
            progressSlider.topAnchor.constraint(equalTo: dotsView.bottomAnchor, constant: SutraSpacing.Base.sm),
            progressSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SutraSpacing.Base.lg),
            progressSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SutraSpacing.Base.lg),
            progressSlider.heightAnchor.constraint(equalToConstant: sliderHeight),

            // Controls constraints
            progressLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: SutraSpacing.Base.sm),
            progressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SutraSpacing.Base.lg),
            progressLabel.widthAnchor.constraint(equalToConstant: 60),
            progressLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SutraSpacing.Base.md),

            bookmarkButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            bookmarkButton.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: SutraSpacing.Base.sm),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 32),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 32),
            bookmarkButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SutraSpacing.Base.md),

            timeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: SutraSpacing.Base.sm),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SutraSpacing.Base.lg),
            timeLabel.widthAnchor.constraint(equalToConstant: 60),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SutraSpacing.Base.md)
        ])
    }

    private func updateAppearance() {
        let colors = SutraColors.Semantic.self

        // Update background based on theme
        switch currentTheme {
        case .light:
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        case .sepia:
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = SutraColors.Sepia.surface.withAlphaComponent(0.9)
        case .dark:
            backgroundView.effect = UIBlurEffect(style: .dark)
            backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        }

        progressLabel.textColor = colors.textSecondary(theme: currentTheme)
        timeLabel.textColor = colors.textSecondary(theme: currentTheme)
        bookmarkButton.tintColor = isBookmarked ? SutraColors.Light.bookmark : colors.textSecondary(theme: currentTheme)

        updateSliderAppearance()
        updateDotsAppearance()
    }

    private func updateSliderAppearance() {
        let colors = SutraColors.Semantic.self

        progressSlider.minimumTrackTintColor = colors.accent(theme: currentTheme)
        progressSlider.maximumTrackTintColor = colors.divider(theme: currentTheme)
        progressSlider.thumbTintColor = colors.accent(theme: currentTheme)

        // Set custom thumb image for better appearance
        let thumbImage = createThumbImage(color: colors.accent(theme: currentTheme))
        progressSlider.setThumbImage(thumbImage, for: .normal)
        progressSlider.setThumbImage(thumbImage, for: .highlighted)
    }

    private func createThumbImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    private func updateDotsAppearance() {
        let colors = SutraColors.Semantic.self
        let progress = currentPosition / totalContent

        for (index, dotLayer) in dotLayers.enumerated() {
            let dotProgress = CGFloat(index) / CGFloat(dotLayers.count)
            let isActive = dotProgress <= progress

            dotLayer.backgroundColor = (isActive ? colors.accent(theme: currentTheme) : colors.divider(theme: currentTheme)).cgColor
        }
    }

    private func layoutDots() {
        let dotSpacing = dotsView.bounds.width / CGFloat(dotLayers.count)
        let dotSize: CGFloat = 4

        for (index, dotLayer) in dotLayers.enumerated() {
            let x = CGFloat(index) * dotSpacing + (dotSpacing - dotSize) / 2
            let y = (dotsView.bounds.height - dotSize) / 2

            dotLayer.frame = CGRect(x: x, y: y, width: dotSize, height: dotSize)
        }
    }

    // MARK: - Slider Actions

    @objc private func sliderValueChanged() {
        let newPosition = CGFloat(progressSlider.value) * totalContent
        updateProgress(position: newPosition, animated: false)
        delegate?.readingProgressView(self, didRequestJumpTo: newPosition)
    }

    @objc private func sliderTouchBegan() {
        SutraHapticManager.shared.haptic(.light)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }
    }

    @objc private func sliderTouchEnded() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            self.transform = .identity
        }
    }

    private func toggleBookmark() {
        isBookmarked.toggle()
        bookmarkButton.isBookmark = isBookmarked

        if isBookmarked {
            bookmarkButton.setImage(UIImage(systemName: "bookmark.fill"), for: .normal)
            SutraHapticManager.shared.haptic(.success)
        } else {
            bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
            SutraHapticManager.shared.haptic(.selection)
        }

        updateAppearance()
        delegate?.readingProgressViewDidRequestBookmark(self)
    }

    // MARK: - Public Configuration Methods

    public func configure(
        totalContent: CGFloat,
        currentPosition: CGFloat,
        estimatedReadingTime: TimeInterval,
        isBookmarked: Bool,
        theme: SutraTheme = .light
    ) {
        self.totalContent = totalContent
        self.currentPosition = currentPosition
        self.estimatedReadingTime = estimatedReadingTime
        self.isBookmarked = isBookmarked
        self.currentTheme = theme

        bookmarkButton.isBookmark = isBookmarked
        bookmarkButton.setImage(
            UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark"),
            for: .normal
        )

        updateProgress(position: currentPosition, animated: false)
        updateTimeLabel()
        updateAppearance()
    }

    public func updateProgress(position: CGFloat, animated: Bool = true) {
        currentPosition = max(0, min(position, totalContent))
        let progress = totalContent > 0 ? currentPosition / totalContent : 0

        if animated {
            UIView.animate(withDuration: 0.3) {
                self.progressSlider.value = Float(progress)
            }
        } else {
            progressSlider.value = Float(progress)
        }

        progressLabel.text = "\(Int(progress * 100))%"
        updateDotsAppearance()
    }

    public func updateTheme(_ theme: SutraTheme) {
        currentTheme = theme
        updateAppearance()
    }

    public func updateBookmarkState(_ isBookmarked: Bool) {
        guard self.isBookmarked != isBookmarked else { return }

        self.isBookmarked = isBookmarked
        bookmarkButton.isBookmark = isBookmarked
        bookmarkButton.setImage(
            UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark"),
            for: .normal
        )

        SutraAnimationPresets.bookmarkToggleAnimation(on: bookmarkButton, isBookmarked: isBookmarked)
        updateAppearance()
    }

    private func updateTimeLabel() {
        let remainingTime = estimatedReadingTime * (1.0 - Double(currentPosition / totalContent))
        timeLabel.text = formatTime(remainingTime)
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDots()
    }

    // MARK: - Presentation Methods

    public func present(from parentView: UIView, position: CGFloat = 0) {
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -position),
            heightAnchor.constraint(equalToConstant: 120)
        ])

        // Initial presentation animation
        transform = CGAffineTransform(translationX: 0, y: frame.height)
        alpha = 0

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.alpha = 1
        }

        SutraHapticManager.shared.haptic(.light)
    }

    public func dismiss() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.transform = CGAffineTransform(translationX: 0, y: self.frame.height)
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }

        SutraHapticManager.shared.haptic(.light)
    }
}

// MARK: - Enhanced Reading Toolbar with Progress
class SutraEnhancedReadingToolbar: UIView {

    private let backgroundView = UIVisualEffectView()
    private let progressIndicator = SutraReadingProgressView()
    private let quickActionsStackView = UIStackView()

    public var customTheme: SutraTheme? {
        didSet { updateAppearance() }
    }

    private var currentTheme: SutraTheme {
        return customTheme ?? .light
    }

    public var onProgressChange: ((CGFloat) -> Void)?
    public var onBookmark: (() -> Void)?
    public var onShare: (() -> Void)?
    public var onThemeToggle: (() -> Void)?
    public var onChapterNavigator: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEnhancedToolbar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEnhancedToolbar()
    }

    private func setupEnhancedToolbar() {
        setupBackground()
        setupProgressIndicator()
        setupQuickActions()
        setupConstraints()
        updateAppearance()
    }

    private func setupBackground() {
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = SutraCornerRadius.large
        backgroundView.layer.masksToBounds = true
    }

    private func setupProgressIndicator() {
        addSubview(progressIndicator)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.delegate = self
    }

    private func setupQuickActions() {
        addSubview(quickActionsStackView)
        quickActionsStackView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsStackView.axis = .horizontal
        quickActionsStackView.distribution = .fillEqually
        quickActionsStackView.spacing = SutraSpacing.Base.sm

        let chapterButton = createQuickActionButton(
            icon: "list.bullet",
            action: { [weak self] in
                self?.onChapterNavigator?()
            }
        )

        let shareButton = createQuickActionButton(
            icon: "square.and.arrow.up",
            action: { [weak self] in
                self?.onShare?()
            }
        )

        let themeButton = createQuickActionButton(
            icon: "paintbrush",
            action: { [weak self] in
                self?.onThemeToggle?()
            }
        )

        quickActionsStackView.addArrangedSubview(chapterButton)
        quickActionsStackView.addArrangedSubview(shareButton)
        quickActionsStackView.addArrangedSubview(themeButton)
    }

    private func createQuickActionButton(icon: String, action: @escaping () -> Void) -> SutraInteractiveButton {
        let button = SutraInteractiveButton(type: .custom)
        button.interactionStyle = .subtle
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background constraints
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Progress indicator constraints
            progressIndicator.topAnchor.constraint(equalTo: topAnchor),
            progressIndicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Quick actions constraints
            quickActionsStackView.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor),
            quickActionsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SutraSpacing.Base.lg),
            quickActionsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SutraSpacing.Base.lg),
            quickActionsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SutraSpacing.Base.sm),
            quickActionsStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func updateAppearance() {
        let theme = currentTheme

        switch theme {
        case .light:
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        case .sepia:
            backgroundView.effect = UIBlurEffect(style: .light)
            backgroundView.backgroundColor = SutraColors.Sepia.surface.withAlphaComponent(0.9)
        case .dark:
            backgroundView.effect = UIBlurEffect(style: .dark)
            backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        }

        progressIndicator.updateTheme(theme)

        // Update quick action buttons
        for case let button as SutraInteractiveButton in quickActionsStackView.arrangedSubviews {
            button.tintColor = SutraColors.Semantic.textSecondary(theme: theme)
        }
    }

    public func configure(
        totalContent: CGFloat,
        currentPosition: CGFloat,
        estimatedReadingTime: TimeInterval,
        isBookmarked: Bool
    ) {
        progressIndicator.configure(
            totalContent: totalContent,
            currentPosition: currentPosition,
            estimatedReadingTime: estimatedReadingTime,
            isBookmarked: isBookmarked,
            theme: currentTheme
        )
    }

    public func updateProgress(position: CGFloat) {
        progressIndicator.updateProgress(position: position)
    }

    public func updateBookmarkState(_ isBookmarked: Bool) {
        progressIndicator.updateBookmarkState(isBookmarked)
    }
}

// MARK: - SutraReadingProgressDelegate
extension SutraEnhancedReadingToolbar: SutraReadingProgressDelegate {
    func readingProgressView(_ progressView: SutraReadingProgressView, didRequestJumpTo position: CGFloat) {
        onProgressChange?(position)
    }

    func readingProgressViewDidRequestBookmark(_ progressView: SutraReadingProgressView) {
        onBookmark?()
    }
}