//
//  SutraChapterNavigator.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Chapter Selection Delegate
protocol SutraChapterNavigatorDelegate: AnyObject {
    func chapterNavigator(_ navigator: SutraChapterNavigator, didSelectChapter chapter: Int)
    func chapterNavigator(_ navigator: SutraChapterNavigator, didRequestBookmarkForChapter chapter: Int)
    func chapterNavigatorDidRequestThemeToggle(_ navigator: SutraChapterNavigator)
}

// MARK: - Sacred Chapter Navigator
class SutraChapterNavigator: UIView {

    // MARK: - UI Components
    private let backgroundView = UIVisualEffectView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = SutraInteractiveButton()
    private let chaptersCollectionView: UICollectionView
    private let progressView = UIProgressView()
    private let bookmarkIndicatorView = UIView()

    // MARK: - Properties
    private var chapters: [String] = []
    private var currentChapter: Int = 0
    private var bookmarkedChapters: Set<Int> = []
    private var currentTheme: SutraTheme = .light

    weak var delegate: SutraChapterNavigatorDelegate?

    // MARK: - Layout Configuration
    private let cellHeight: CGFloat = 60
    private let headerHeight: CGFloat = 80
    private let bottomPadding: CGFloat = 20

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        chaptersCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)
        setupChapterNavigator()
    }

    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        chaptersCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(coder: coder)
        setupChapterNavigator()
    }

    private func setupChapterNavigator() {
        setupBackground()
        setupHeader()
        setupCollectionView()
        setupProgressView()
        setupBookmarkIndicator()
        setupConstraints()
        setupGestureRecognizers()
        updateAppearance()
    }

    private func setupBackground() {
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = SutraCornerRadius.large
        backgroundView.layer.masksToBounds = true
    }

    private func setupHeader() {
        addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)
        titleLabel.textAlignment = .center

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.interactionStyle = .subtle
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        if #available(iOS 14.0, *) {
            closeButton.addAction(UIAction { _ in self.dismiss() }, for: .touchUpInside)
        } else {
            // Fallback for iOS 13
            closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: SutraSpacing.Base.sm),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 44),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -44),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -SutraSpacing.Base.sm),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -SutraSpacing.Base.md),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupCollectionView() {
        addSubview(chaptersCollectionView)
        chaptersCollectionView.translatesAutoresizingMaskIntoConstraints = false

        chaptersCollectionView.backgroundColor = UIColor.clear
        chaptersCollectionView.delegate = self
        chaptersCollectionView.dataSource = self
        chaptersCollectionView.showsVerticalScrollIndicator = false
        chaptersCollectionView.isPagingEnabled = false

        chaptersCollectionView.register(ChapterCell.self, forCellWithReuseIdentifier: ChapterCell.identifier)
    }

    private func setupProgressView() {
        addSubview(progressView)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = SutraColors.Light.accent
        progressView.trackTintColor = SutraColors.Light.divider
        progressView.layer.cornerRadius = 2
        progressView.layer.masksToBounds = true
    }

    private func setupBookmarkIndicator() {
        addSubview(bookmarkIndicatorView)
        bookmarkIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        bookmarkIndicatorView.layer.cornerRadius = 3
        bookmarkIndicatorView.layer.masksToBounds = true
        bookmarkIndicatorView.backgroundColor = SutraColors.Light.bookmark
        bookmarkIndicatorView.isHidden = true
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background constraints
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Header constraints
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            // Collection view constraints
            chaptersCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            chaptersCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chaptersCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chaptersCollectionView.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -SutraSpacing.Base.sm),

            // Progress view constraints
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SutraSpacing.Base.lg),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SutraSpacing.Base.lg),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomPadding),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            // Bookmark indicator constraints
            bookmarkIndicatorView.topAnchor.constraint(equalTo: progressView.topAnchor, constant: -2),
            bookmarkIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            bookmarkIndicatorView.heightAnchor.constraint(equalToConstant: 8),
            bookmarkIndicatorView.centerXAnchor.constraint(equalTo: progressView.leadingAnchor, constant: 0)
        ])
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        backgroundView.addGestureRecognizer(tapGesture)

        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(dismiss))
        swipeDownGesture.direction = .down
        addGestureRecognizer(swipeDownGesture)
    }

    @objc private func handleBackgroundTap() {
        // Handle taps on background outside content
    }

    @objc private func dismiss() {
        animateDismiss()
        SutraHapticManager.shared.haptic(.light)
    }

    // MARK: - Public Configuration Methods

    public func configure(chapters: [String], currentChapter: Int, bookmarkedChapters: Set<Int> = [], theme: SutraTheme = .light) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.bookmarkedChapters = bookmarkedChapters
        self.currentTheme = theme

        titleLabel.text = NSLocalizedString("Chapters", comment: "Chapter selection title")
        updateProgress()
        updateBookmarkIndicator()
        updateAppearance()
        chaptersCollectionView.reloadData()

        // Scroll to current chapter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollToCurrentChapter()
        }
    }

    public func updateCurrentChapter(_ chapter: Int) {
        let previousChapter = currentChapter
        currentChapter = chapter

        if previousChapter != chapter {
            updateProgress()
            updateBookmarkIndicator()

            // Animate the change
            chaptersCollectionView.reloadItems(at: [
                IndexPath(item: previousChapter, section: 0),
                IndexPath(item: chapter, section: 0)
            ])

            scrollToCurrentChapter()
        }
    }

    public func updateBookmarkedChapters(_ bookmarkedChapters: Set<Int>) {
        self.bookmarkedChapters = bookmarkedChapters
        updateBookmarkIndicator()
        chaptersCollectionView.reloadData()
    }

    public func updateTheme(_ theme: SutraTheme) {
        currentTheme = theme
        updateAppearance()
        chaptersCollectionView.reloadData()
    }

    private func updateProgress() {
        let progress = Float(currentChapter + 1) / Float(chapters.count)
        progressView.setProgress(progress, animated: true)

        // Update bookmark indicator position
        let indicatorX = progressView.frame.width * CGFloat(progress)
        bookmarkIndicatorView.transform = CGAffineTransform(translationX: indicatorX, y: 0)
    }

    private func updateBookmarkIndicator() {
        bookmarkIndicatorView.isHidden = !bookmarkedChapters.contains(currentChapter)
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

        titleLabel.textColor = colors.primary(theme: currentTheme)
        closeButton.tintColor = colors.textSecondary(theme: currentTheme)
        progressView.progressTintColor = colors.accent(theme: currentTheme)
        progressView.trackTintColor = colors.divider(theme: currentTheme)
        bookmarkIndicatorView.backgroundColor = SutraColors.Light.bookmark

        chaptersCollectionView.reloadData()
    }

    private func scrollToCurrentChapter() {
        let indexPath = IndexPath(item: currentChapter, section: 0)
        chaptersCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
    }

    // MARK: - Presentation Methods

    public func present(from parentView: UIView) {
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            heightAnchor.constraint(equalToConstant: 500)
        ])

        // Initial presentation animation
        transform = CGAffineTransform(translationX: 0, y: frame.height)
        alpha = 0

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.alpha = 1
        }

        SutraHapticManager.shared.haptic(.sacred)
    }

    private func animateDismiss() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.transform = CGAffineTransform(translationX: 0, y: self.frame.height)
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SutraChapterNavigator: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return chapters.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChapterCell.identifier, for: indexPath) as! ChapterCell

        let chapter = chapters[indexPath.item]
        let isCurrentChapter = indexPath.item == currentChapter
        let isBookmarked = bookmarkedChapters.contains(indexPath.item)

        cell.configure(
            title: chapter,
            chapterNumber: indexPath.item + 1,
            isCurrent: isCurrentChapter,
            isBookmarked: isBookmarked,
            theme: currentTheme
        )

        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SutraChapterNavigator: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        SutraHapticManager.shared.haptic(.selection)

        let chapter = indexPath.item
        if chapter == currentChapter {
            dismiss()
            return
        }

        // Update current chapter with animation
        let previousChapter = currentChapter
        currentChapter = chapter

        updateProgress()
        updateBookmarkIndicator()

        // Reload cells for animation
        collectionView.reloadItems(at: [
            IndexPath(item: previousChapter, section: 0),
            IndexPath(item: chapter, section: 0)
        ])

        delegate?.chapterNavigator(self, didSelectChapter: chapter)

        // Auto dismiss after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismiss()
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return indexPath.item != currentChapter
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SutraChapterNavigator: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width - 32, height: cellHeight)
    }
}

// MARK: - Chapter Cell
class ChapterCell: UICollectionViewCell {

    static let identifier = "ChapterCell"

    private let containerView = UIView()
    private let chapterNumberLabel = UILabel()
    private let titleLabel = UILabel()
    private let bookmarkIcon = UIImageView()
    private let currentIndicator = UIView()

    private var currentTheme: SutraTheme = .light

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.addSubview(containerView)
        containerView.addSubview(chapterNumberLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(bookmarkIcon)
        containerView.addSubview(currentIndicator)

        setupCellAppearance()
        setupCellConstraints()
    }

    private func setupCellAppearance() {
        containerView.layer.cornerRadius = SutraCornerRadius.medium
        containerView.layer.masksToBounds = true

        chapterNumberLabel.font = SutraTypographyManager.shared.uiFont(for: .buttonLarge, weight: .medium)
        chapterNumberLabel.textAlignment = .center

        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
        titleLabel.numberOfLines = 0

        bookmarkIcon.image = UIImage(systemName: "bookmark.fill")
        bookmarkIcon.tintColor = SutraColors.Light.bookmark
        bookmarkIcon.contentMode = .scaleAspectFit

        currentIndicator.backgroundColor = SutraColors.Light.accent
        currentIndicator.layer.cornerRadius = 2
        currentIndicator.layer.masksToBounds = true
    }

    private func setupCellConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        chapterNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bookmarkIcon.translatesAutoresizingMaskIntoConstraints = false
        currentIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container constraints
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Current indicator constraints
            currentIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            currentIndicator.topAnchor.constraint(equalTo: containerView.topAnchor),
            currentIndicator.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            currentIndicator.widthAnchor.constraint(equalToConstant: 4),

            // Chapter number constraints
            chapterNumberLabel.leadingAnchor.constraint(equalTo: currentIndicator.trailingAnchor, constant: SutraSpacing.Base.md),
            chapterNumberLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chapterNumberLabel.widthAnchor.constraint(equalToConstant: 40),

            // Title constraints
            titleLabel.leadingAnchor.constraint(equalTo: chapterNumberLabel.trailingAnchor, constant: SutraSpacing.Base.md),
            titleLabel.trailingAnchor.constraint(equalTo: bookmarkIcon.leadingAnchor, constant: -SutraSpacing.Base.md),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            // Bookmark icon constraints
            bookmarkIcon.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -SutraSpacing.Base.md),
            bookmarkIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            bookmarkIcon.widthAnchor.constraint(equalToConstant: 20),
            bookmarkIcon.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    public func configure(title: String, chapterNumber: Int, isCurrent: Bool, isBookmarked: Bool, theme: SutraTheme) {
        currentTheme = theme
        titleLabel.text = title
        chapterNumberLabel.text = "\(chapterNumber)"
        bookmarkIcon.isHidden = !isBookmarked
        currentIndicator.isHidden = !isCurrent

        updateCellAppearance(isCurrent: isCurrent)
    }

    private func updateCellAppearance(isCurrent: Bool) {
        let colors = SutraColors.Semantic.self

        if isCurrent {
            containerView.backgroundColor = colors.accent(theme: currentTheme).withAlphaComponent(0.1)
            chapterNumberLabel.textColor = colors.accent(theme: currentTheme)
            titleLabel.textColor = colors.accent(theme: currentTheme)
            titleLabel.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)
            containerView.applyCardShadow()
        } else {
            containerView.backgroundColor = colors.surface(theme: currentTheme)
            chapterNumberLabel.textColor = colors.textSecondary(theme: currentTheme)
            titleLabel.textColor = colors.primary(theme: currentTheme)
            titleLabel.font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
            containerView.layer.shadowOpacity = 0
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1) {
                    self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                    self.alpha = 0.8
                }
            } else {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
                    self.transform = .identity
                    self.alpha = 1.0
                }
            }
        }
    }
}

// MARK: - Target-Action Methods
extension SutraChapterNavigator {
    @objc private func closeButtonTapped() {
        dismiss()
    }
}