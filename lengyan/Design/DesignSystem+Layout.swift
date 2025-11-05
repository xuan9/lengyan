//
//  DesignSystem+Layout.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Grid System
public struct SutraGridSystem {

    // MARK: - Grid Configuration
    public struct Configuration {
        public let columns: Int
        public let gutter: CGFloat
        public let margin: CGFloat
        public let containerWidth: CGFloat

        public init(columns: Int, gutter: CGFloat, margin: CGFloat, containerWidth: CGFloat) {
            self.columns = columns
            self.gutter = gutter
            self.margin = margin
            self.containerWidth = containerWidth
        }
    }

    // MARK: - Responsive Breakpoints
    public struct Breakpoint {
        public static let small: CGFloat = 375   // iPhone SE
        public static let medium: CGFloat = 414  // iPhone Pro
        public static let large: CGFloat = 768   // iPad mini
        public static let xlarge: CGFloat = 1024 // iPad Pro
    }

    // MARK: - Grid Configurations for Different Screen Sizes
    public static let configurations: [CGFloat: Configuration] = [
        Breakpoint.small: Configuration(
            columns: 4,
            gutter: SutraSpacing.Base.sm,
            margin: SutraSpacing.Base.md,
            containerWidth: Breakpoint.small
        ),
        Breakpoint.medium: Configuration(
            columns: 6,
            gutter: SutraSpacing.Base.md,
            margin: SutraSpacing.Base.lg,
            containerWidth: Breakpoint.medium
        ),
        Breakpoint.large: Configuration(
            columns: 8,
            gutter: SutraSpacing.Base.lg,
            margin: SutraSpacing.Component.sm,
            containerWidth: Breakpoint.large
        ),
        Breakpoint.xlarge: Configuration(
            columns: 12,
            gutter: SutraSpacing.Component.sm,
            margin: SutraSpacing.Component.lg,
            containerWidth: Breakpoint.xlarge
        )
    ]

    // MARK: - Grid Calculator
    public static func configuration(for screenWidth: CGFloat) -> Configuration {
        let sortedBreakpoints = configurations.keys.sorted()
        var selectedConfiguration = configurations[Breakpoint.small]!

        for breakpoint in sortedBreakpoints {
            if screenWidth >= breakpoint {
                selectedConfiguration = configurations[breakpoint]!
            } else {
                break
            }
        }

        return selectedConfiguration
    }

    // MARK: - Column Width Calculation
    public static func columnWidth(config: Configuration) -> CGFloat {
        let totalGutterWidth = config.gutter * CGFloat(config.columns - 1)
        let availableWidth = config.containerWidth - (config.margin * 2) - totalGutterWidth
        return availableWidth / CGFloat(config.columns)
    }

    // MARK: - Grid Position Calculator
    public static func frameForColumn(column: Int,
                                     span: Int = 1,
                                     config: Configuration) -> CGRect {
        let columnWidth = self.columnWidth(config: config)
        let x = config.margin + (CGFloat(column) * (columnWidth + config.gutter))
        let width = (CGFloat(span) * columnWidth) + (CGFloat(span - 1) * config.gutter)
        return CGRect(x: x, y: 0, width: width, height: 0)
    }
}

// MARK: - Grid View Manager
public class SutraGridLayoutManager {

    private let config: SutraGridSystem.Configuration
    private var constraints: [NSLayoutConstraint] = []

    public init(config: SutraGridSystem.Configuration) {
        self.config = config
    }

    // MARK: - Layout Methods
    public func layoutViews(_ views: [UIView],
                           in container: UIView,
                           spans: [Int]? = nil) {
        clearConstraints()

        let actualSpans = spans ?? Array(repeating: 1, count: views.count)
        var currentColumn = 0

        for (index, view) in views.enumerated() {
            let span = min(actualSpans[index], config.columns - currentColumn)
            let frame = SutraGridSystem.frameForColumn(column: currentColumn, span: span, config: config)

            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)

            let constraints = [
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: frame.origin.x),
                view.topAnchor.constraint(equalTo: container.topAnchor, constant: SutraSpacing.Base.md),
                view.widthAnchor.constraint(equalToConstant: frame.width),
                view.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ]

            NSLayoutConstraint.activate(constraints)
            self.constraints.append(contentsOf: constraints)

            currentColumn += span
            if currentColumn >= config.columns {
                currentColumn = 0
            }
        }
    }

    public func layoutSutraContent(_ sutraView: UIView,
                                  in container: UIView) {
        sutraView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sutraView)

        let readingMargin = SutraSpacing.Margins.readingMargin(for: container.frame.width)

        let constraints = [
            sutraView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: readingMargin),
            sutraView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -readingMargin),
            sutraView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: SutraSpacing.Component.sm),
            sutraView.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -SutraSpacing.Component.lg)
        ]

        NSLayoutConstraint.activate(constraints)
        self.constraints.append(contentsOf: constraints)
    }

    private func clearConstraints() {
        NSLayoutConstraint.deactivate(constraints)
        constraints.removeAll()
    }
}

// MARK: - Responsive Stack View
public class ResponsiveStackView: UIStackView {

    public enum ResponsiveDistribution {
        case equal
        case proportional([CGFloat]) // Proportional widths
        case content
    }

    public var responsiveDistribution: ResponsiveDistribution = .equal {
        didSet { updateDistribution() }
    }

    private var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStackView()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupStackView()
    }

    private func setupStackView() {
        axis = .horizontal
        distribution = .fill
        alignment = .center
        spacing = SutraSpacing.Base.sm
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func updateDistribution() {
        guard !arrangedSubviews.isEmpty else { return }

        switch responsiveDistribution {
        case .equal:
            arrangedSubviews.forEach { view in
                view.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0 / CGFloat(arrangedSubviews.count)).isActive = true
            }

        case .proportional(let proportions):
            let total = proportions.reduce(0, +)
            for (index, view) in arrangedSubviews.enumerated() {
                if index < proportions.count {
                    let multiplier = proportions[index] / total
                    view.widthAnchor.constraint(equalTo: widthAnchor, multiplier: multiplier).isActive = true
                }
            }

        case .content:
            distribution = .fillProportionally
        }
    }
}

// MARK: - Reading Layout Manager
public class SutraReadingLayoutManager {

    public enum ReadingMode {
        case standard    // Standard reading with toolbar
        case focused     // Focus mode with minimal UI
        case pure        // Pure text reading
        case presentation // Presentation mode
    }

    private var currentMode: ReadingMode = .standard
    private var containerView: UIView!
    private var contentScrollView: UIScrollView!
    private var contentView: UIView!
    private var toolbar: ReadingToolbar!
    private var textContentView: UITextView!

    public init(containerView: UIView) {
        self.containerView = containerView
        setupReadingLayout()
    }

    private func setupReadingLayout() {
        setupScrollView()
        setupContentView()
        setupTextContentView()
        setupToolbar()
        setupConstraints()
    }

    private func setupScrollView() {
        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.showsHorizontalScrollIndicator = false
        contentScrollView.contentInsetAdjustmentBehavior = .automatic
        containerView.addSubview(contentScrollView)
    }

    private func setupContentView() {
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentView)
    }

    private func setupTextContentView() {
        textContentView = UITextView()
        textContentView.translatesAutoresizingMaskIntoConstraints = false
        textContentView.isEditable = false
        textContentView.isScrollEnabled = false
        textContentView.backgroundColor = UIColor.clear
        textContentView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Component.lg,
                                                          left: 0,
                                                          bottom: SutraSpacing.Component.lg,
                                                          right: 0)
        contentView.addSubview(textContentView)
    }

    private func setupToolbar() {
        toolbar = ReadingToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toolbar)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            contentScrollView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Content view constraints
            contentView.topAnchor.constraint(equalTo: contentScrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),

            // Text content constraints
            textContentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textContentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.Margins.readingMargin(for: containerView.bounds.width)),
            textContentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.Margins.readingMargin(for: containerView.bounds.width)),
            textContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Toolbar constraints
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: SutraSpacing.Base.lg),
            toolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -SutraSpacing.Base.lg),
            toolbar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -SutraSpacing.Base.lg),
            toolbar.heightAnchor.constraint(equalToConstant: SutraSpacing.UIElement.toolbarHeight)
        ])
    }

    // MARK: - Public Methods
    public func setReadingMode(_ mode: ReadingMode, animated: Bool = true) {
        currentMode = mode

        let animations = {
            switch mode {
            case .standard:
                self.toolbar.alpha = 1.0
                self.textContentView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Component.lg,
                                                                       left: 0,
                                                                       bottom: SutraSpacing.Component.lg,
                                                                       right: 0)

            case .focused:
                self.toolbar.alpha = 0.3
                self.textContentView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Component.xl,
                                                                       left: 0,
                                                                       bottom: SutraSpacing.Component.xl,
                                                                       right: 0)

            case .pure:
                self.toolbar.alpha = 0.0
                self.textContentView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Section.sm,
                                                                       left: 0,
                                                                       bottom: SutraSpacing.Section.sm,
                                                                       right: 0)

            case .presentation:
                self.toolbar.alpha = 0.0
                self.textContentView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Section.lg,
                                                                       left: 0,
                                                                       bottom: SutraSpacing.Section.lg,
                                                                       right: 0)
            }
        }

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: animations)
        } else {
            animations()
        }
    }

    public func configureContent(text: String, theme: SutraTheme) {
        let attributedText = NSAttributedString.sutraAttributedText(
            text: text,
            style: SutraTypography.TextStyle.sutraBody,
            color: SutraColors.Semantic.sutraText(theme: theme)
        )
        textContentView.attributedText = attributedText
        toolbar.customTheme = theme
    }

    public func configureToolbar(onPrevious: @escaping () -> Void,
                               onNext: @escaping () -> Void,
                               onBookmark: @escaping () -> Void,
                               onShare: @escaping () -> Void,
                               onPureReading: @escaping () -> Void) {
        toolbar.onPrevious = onPrevious
        toolbar.onNext = onNext
        toolbar.onBookmark = onBookmark
        toolbar.onShare = onShare
        toolbar.onPureReading = onPureReading
    }
}

// MARK: - Layout Utilities
public struct SutraLayoutUtils {

    // MARK: - Safe Area Calculations
    public static func safeAreaInsets(for view: UIView) -> UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        }
    }

    // MARK: - Reading Frame Calculator
    public static func readingFrame(in container: UIView) -> CGRect {
        let safeArea = safeAreaInsets(for: container)
        let margin = SutraSpacing.Margins.readingMargin(for: container.frame.width)

        return CGRect(
            x: safeArea.left + margin,
            y: safeArea.top,
            width: container.frame.width - safeArea.left - safeArea.right - (margin * 2),
            height: container.frame.height - safeArea.top - safeArea.bottom
        )
    }

    // MARK: - Responsive Height Calculator
    public static func responsiveHeight(for baseHeight: CGFloat,
                                       screenHeight: CGFloat) -> CGFloat {
        switch screenHeight {
        case 0..<667: // iPhone SE, iPhone 8
            return baseHeight * 0.875
        case 667..<736: // iPhone 8 Plus
            return baseHeight
        case 736..<812: // iPhone Plus
            return baseHeight * 1.125
        case 812..<896: // iPhone X, XS, 11 Pro
            return baseHeight * 1.15
        case 896..<CGFloat.greatestFiniteMagnitude: // iPhone XR, XS Max, 11, 11 Pro Max
            return baseHeight * 1.2
        default:
            return baseHeight
        }
    }

    // MARK: - Aspect Ratio Constraints
    public static func constrainAspect(ratio: CGFloat, to view: UIView) -> [NSLayoutConstraint] {
        view.translatesAutoresizingMaskIntoConstraints = false
        return [
            view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: ratio)
        ]
    }

    // MARK: - Centering Constraints
    public static func centerInView(_ subview: UIView, in parentView: UIView) -> [NSLayoutConstraint] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        return [
            subview.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            subview.centerYAnchor.constraint(equalTo: parentView.centerYAnchor)
        ]
    }

    // MARK: - Full Screen Constraints
    public static func fillSuperview(_ view: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        view.translatesAutoresizingMaskIntoConstraints = false
        return [
            view.topAnchor.constraint(equalTo: view.superview!.topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: view.superview!.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: view.superview!.trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: view.superview!.bottomAnchor, constant: -insets.bottom)
        ]
    }
}

// MARK: - Layout Constants
public struct SutraLayoutConstants {
    // Reading layout constants
    public static let optimalReadingWidth: CGFloat = 680  // Maximum width for comfortable reading
    public static let minReadingWidth: CGFloat = 280      // Minimum readable width
    public static let maxReadingWidth: CGFloat = 800      // Maximum width before centering

    // Touch target sizes (Apple HIG compliant)
    public static let minTouchTarget: CGFloat = 44
    public static let preferredTouchTarget: CGFloat = 48

    // Navigation heights
    public static let navigationBarHeight: CGFloat = 44
    public static let statusBarHeight: CGFloat = 20
    public static let homeIndicatorHeight: CGFloat = 34

    // Animation constants
    public static let defaultAnimationDuration: TimeInterval = 0.3
    public static let fastAnimationDuration: TimeInterval = 0.2
    public static let slowAnimationDuration: TimeInterval = 0.5
}