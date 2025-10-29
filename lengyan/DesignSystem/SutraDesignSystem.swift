//
//  SutraDesignSystem.swift
//  lengyan
//
//  Created by Claude on 2025/10/28.
//  Copyright © 2025年 xuan. All rights reserved.
//

import UIKit

// MARK: - Sacred Color System
struct SutraColors {

    // MARK: - Light Theme (Clarity & Purity)
    struct Light {
        static let background = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)      // Pure White
        static let cardBackground = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)  // Warm White
        static let primaryText = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)    // Deep Charcoal
        static let secondaryText = UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)   // Medium Gray
        static let accent = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)          // Saffron Gold
        static let chapterButton = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)   // Light Gray
        static let navigationBar = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)   // Near White
        static let tabBar = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)         // Warm White
        static let separator = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)       // Light Gray
        static let bookmarkStar = UIColor(red: 0.94, green: 0.78, blue: 0.33, alpha: 1.0)    // Golden
    }

    // MARK: - Sepia Theme (Tradition & Warmth)
    struct Sepia {
        static let background = UIColor(red: 0.98, green: 0.95, blue: 0.92, alpha: 1.0)      // Cream
        static let cardBackground = UIColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1.0)  // Warm Cream
        static let primaryText = UIColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1.0)     // Dark Brown
        static let secondaryText = UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0)   // Medium Brown
        static let accent = UIColor(red: 0.75, green: 0.55, blue: 0.30, alpha: 1.0)          // Rich Brown
        static let chapterButton = UIColor(red: 0.92, green: 0.88, blue: 0.82, alpha: 1.0)   // Light Brown
        static let navigationBar = UIColor(red: 0.94, green: 0.91, blue: 0.87, alpha: 1.0)   // Beige
        static let tabBar = UIColor(red: 0.93, green: 0.90, blue: 0.86, alpha: 1.0)         // Light Beige
        static let separator = UIColor(red: 0.75, green: 0.70, blue: 0.65, alpha: 1.0)       // Brownish
        static let bookmarkStar = UIColor(red: 0.80, green: 0.60, blue: 0.35, alpha: 1.0)    // Sepia Gold
    }

    // MARK: - Dark Theme (Focus & Serenity)
    struct Dark {
        static let background = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)      // Dark Blue-Black
        static let cardBackground = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)  // Dark Gray
        static let primaryText = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)     // Near White
        static let secondaryText = UIColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0)   // Light Gray
        static let accent = UIColor(red: 0.60, green: 0.75, blue: 0.85, alpha: 1.0)          // Cool Blue
        static let chapterButton = UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1.0)   // Dark Blue-Gray
        static let navigationBar = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)   // Dark Blue
        static let tabBar = UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1.0)         // Very Dark
        static let separator = UIColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 1.0)       // Dark Gray
        static let bookmarkStar = UIColor(red: 0.75, green: 0.70, blue: 0.50, alpha: 1.0)    // Soft Gold
    }

    // MARK: - Current Theme
    private static var currentTheme: Theme = .light

    enum Theme {
        case light, sepia, dark
    }

    static func setTheme(_ theme: Theme) {
        currentTheme = theme
        applyThemeToApp()
    }

    static func getCurrentTheme() -> Theme {
        return currentTheme
    }

    private static func applyThemeToApp() {
        let colors = currentColors

        // Update appearance proxies for global styling
        UINavigationBar.appearance().backgroundColor = colors.navigationBar
        UINavigationBar.appearance().barTintColor = colors.navigationBar
        UINavigationBar.appearance().tintColor = colors.primaryText
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: colors.primaryText,
            .font: UIFont.systemFont(ofSize: 17, weight: .medium)
        ]

        UITabBar.appearance().backgroundColor = colors.tabBar
        UITabBar.appearance().barTintColor = colors.tabBar
        UITabBar.appearance().tintColor = colors.accent

        UIView.appearance().backgroundColor = colors.background
    }

    static var currentColors: (background: UIColor, cardBackground: UIColor, primaryText: UIColor,
                              secondaryText: UIColor, accent: UIColor, chapterButton: UIColor,
                              navigationBar: UIColor, tabBar: UIColor, separator: UIColor,
                              bookmarkStar: UIColor) {
        switch currentTheme {
        case .light:
            return (Light.background, Light.cardBackground, Light.primaryText, Light.secondaryText,
                   Light.accent, Light.chapterButton, Light.navigationBar, Light.tabBar,
                   Light.separator, Light.bookmarkStar)
        case .sepia:
            return (Sepia.background, Sepia.cardBackground, Sepia.primaryText, Sepia.secondaryText,
                   Sepia.accent, Sepia.chapterButton, Sepia.navigationBar, Sepia.tabBar,
                   Sepia.separator, Sepia.bookmarkStar)
        case .dark:
            return (Dark.background, Dark.cardBackground, Dark.primaryText, Dark.secondaryText,
                   Dark.accent, Dark.chapterButton, Dark.navigationBar, Dark.tabBar,
                   Dark.separator, Dark.bookmarkStar)
        }
    }
}

// MARK: - Sacred Typography System
struct SutraTypography {

    // Chinese-optimized font hierarchy
    struct FontSizes {
        static let largeTitle: CGFloat = 28
        static let title1: CGFloat = 24
        static let title2: CGFloat = 20
        static let title3: CGFloat = 18
        static let headline: CGFloat = 17
        static let body: CGFloat = 16
        static let callout: CGFloat = 15
        static let subheadline: CGFloat = 14
        static let footnote: CGFloat = 12
        static let caption1: CGFloat = 11
        static let caption2: CGFloat = 10
    }

    // Golden ratio line heights for optimal readability
    struct LineHeights {
        static let sutraText: CGFloat = 1.618
        static let commentary: CGFloat = 1.4
        static let navigation: CGFloat = 1.2
        static let body: CGFloat = 1.5
    }

    // Font families optimized for Chinese text
    static func primaryFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func sutraFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func commentaryFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func navigationFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .medium)
    }
}

// MARK: - Enhanced UI Components
class SutraEnhancedButton: UIButton {

    enum Style {
        case chapter, sacred, navigation, bookmark
    }

    private var buttonStyle: Style = .chapter

    init(style: Style) {
        super.init(frame: .zero)
        self.buttonStyle = style
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        layer.cornerRadius = 8
        layer.masksToBounds = true

        let colors = SutraColors.currentColors

        switch buttonStyle {
        case .chapter:
            backgroundColor = colors.chapterButton
            setTitleColor(colors.primaryText, for: .normal)
            titleLabel?.font = SutraTypography.sutraFont(size: 16)

        case .sacred:
            backgroundColor = colors.accent
            setTitleColor(.white, for: .normal)
            titleLabel?.font = SutraTypography.primaryFont(size: 16, weight: .medium)

        case .navigation:
            backgroundColor = .clear
            setTitleColor(colors.primaryText, for: .normal)
            titleLabel?.font = SutraTypography.navigationFont(size: 17)

        case .bookmark:
            backgroundColor = .clear
            setTitleColor(colors.bookmarkStar, for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        }

        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 2
        layer.masksToBounds = false

        // Add haptic feedback
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc private func buttonTapped() {
        // Provide gentle haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}

// MARK: - Theme Manager
class SutraThemeManager: NSObject {

    static let shared = SutraThemeManager()

    private override init() {}

    func cycleTheme() {
        let currentTheme = SutraColors.getCurrentTheme()
        let nextTheme: SutraColors.Theme

        switch currentTheme {
        case .light:
            nextTheme = .sepia
        case .sepia:
            nextTheme = .dark
        case .dark:
            nextTheme = .light
        }

        SutraColors.setTheme(nextTheme)

        // Animate theme transition
        UIView.transition(with: UIApplication.shared.windows.first ?? UIView(),
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: {
            // Force UI update
        })
    }

    func setTheme(_ theme: SutraColors.Theme) {
        SutraColors.setTheme(theme)
    }
}

// MARK: - Accessibility Helper
struct SutraAccessibility {

    static func configureButton(_ button: UIButton, title: String, hint: String = "") {
        button.accessibilityLabel = title
        button.accessibilityHint = hint.isEmpty ? NSLocalizedString("Double tap to activate", comment: "") : hint
        button.isAccessibilityElement = true
    }

    static func configureNavigationItem(_ item: UINavigationItem, title: String) {
        item.accessibilityLabel = title
        item.isAccessibilityElement = true
    }
}