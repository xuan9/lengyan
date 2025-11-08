//
//  DesignSystem+Tokens.swift
//  lengyan
//
//  Design Token System - Type-Safe, Clean Architecture
//  Single source of truth for all design tokens
//

import UIKit
import SwiftUI

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue:  CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Theme Definition
public enum SutraTheme: String, CaseIterable {
    case light = "light"
    case sepia = "sepia"
    case dark = "dark"
}

// MARK: - Color Tokens (Type-Safe Enum)
public enum ColorToken: String, CaseIterable {
    // Background
    case background
    case surface
    case card
    case overlay

    // Text
    case textPrimary
    case textSecondary
    case textTertiary
    case textOnAccent

    // Sutra-specific
    case sutraText
    case commentaryText
    case chapterTitle

    // UI Elements
    case primary
    case accent
    case divider
    case border
    case shadow

    // Status
    case bookmark
    case favorite

    // UI System (borrowed from SutraDesignSystem)
    case navigationBar
    case tabBar
    case separator
    case bookmarkStar
}

// MARK: - Theme Protocol
protocol SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor
}

// MARK: - Light Theme Implementation - Enhanced Zen Palette
struct LightTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        // Background - Traditional rice paper colors
        case .background: return UIColor(hex: "#FAF9F6") ?? .white  // Warm rice paper white
        case .surface: return UIColor(hex: "#F5F2ED") ?? .white     // Aged paper surface
        case .card: return UIColor(hex: "#FFFFFF")?.withAlphaComponent(0.8) ?? .white  // Subtle card
        case .overlay: return UIColor.black.withAlphaComponent(0.3)

        // Text - Traditional ink colors with better contrast
        case .textPrimary: return UIColor(hex: "#2C2C2C") ?? .black    // Deep ink black
        case .textSecondary: return UIColor(hex: "#5A5A5A") ?? .darkGray  // Medium ink
        case .textTertiary: return UIColor(hex: "#8A8A8A") ?? .gray  // Light ink
        case .textOnAccent: return .white

        // Sutra-specific - Traditional calligraphy colors
        case .sutraText: return UIColor(hex: "#1A1A1A") ?? .black      // Darkest ink for sutras
        case .commentaryText: return UIColor(hex: "#3A3A3A") ?? .darkGray  // Commentary ink
        case .chapterTitle: return UIColor(hex: "#8B4513") ?? .brown   // Traditional seal ink red-brown

        // UI Elements - Muted Zen palette
        case .primary: return UIColor(hex: "#5A5A5A") ?? .darkGray
        case .accent: return UIColor(hex: "#8B4513") ?? .brown          // Muted traditional red
        case .divider: return UIColor(hex: "#E8E5E0") ?? .lightGray        // Subtle divider
        case .border: return UIColor(hex: "#D0CCC7") ?? .lightGray         // Soft border
        case .shadow: return UIColor.black.withAlphaComponent(0.05)    // Very subtle shadow

        // Status - Traditional auspicious colors
        case .bookmark: return UIColor(hex: "#D4A574") ?? .orange       // Golden brown
        case .favorite: return UIColor(hex: "#C08552") ?? .orange       // Traditional cinnabar

        // UI System - Warmer, more traditional tones
        case .navigationBar: return UIColor(hex: "#F8F6F3") ?? .white     // Warm white
        case .tabBar: return UIColor(hex: "#F8F6F3") ?? .white           // Warm white
        case .separator: return UIColor(hex: "#E0DCD6") ?? .systemGray3  // Muted separator
        case .bookmarkStar: return UIColor(hex: "#D4A574") ?? .systemYellow // Traditional gold
        }
    }
}

// MARK: - Sepia Theme Implementation
struct SepiaTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        case .background: return UIColor(hex: "#F5E6D3") ?? UIColor(red: 0.96, green: 0.90, blue: 0.83, alpha: 1.0)
        case .surface: return UIColor(hex: "#FAF0E6") ?? UIColor(red: 0.98, green: 0.94, blue: 0.90, alpha: 1.0)
        case .card: return .white
        case .overlay: return UIColor.black.withAlphaComponent(0.5)

        case .textPrimary: return UIColor(hex: "#3E2723") ?? .black
        case .textSecondary: return UIColor(hex: "#5D4037") ?? .darkGray
        case .textTertiary: return UIColor(hex: "#795548") ?? .gray
        case .textOnAccent: return .white

        case .sutraText: return UIColor(hex: "#2E1A17") ?? .black
        case .commentaryText: return UIColor(hex: "#4A3426") ?? .darkGray
        case .chapterTitle: return UIColor(hex: "#8D6E63") ?? .brown

        case .primary: return UIColor(hex: "#4A3426") ?? .darkGray
        case .accent: return UIColor(hex: "#8D6E63") ?? .brown
        case .divider: return UIColor(hex: "#D7CCC8") ?? .lightGray
        case .border: return UIColor(hex: "#BCAAA4") ?? .lightGray
        case .shadow: return UIColor.black.withAlphaComponent(0.12)

        case .bookmark: return UIColor(hex: "#FFB74D") ?? .orange
        case .favorite: return UIColor(hex: "#8D6E63") ?? .brown

        // UI System colors - WHITE for MAXIMUM CONTRAST
        case .navigationBar: return .white        // WHITE navbar
        case .tabBar: return .white              // WHITE tabbar
        case .separator: return UIColor(hex: "#D0C4BC") ?? .systemGray3     // Separator
        case .bookmarkStar: return UIColor(hex: "#D4A017") ?? .systemYellow // Golden brown
        }
    }
}

// MARK: - Dark Theme Implementation
struct DarkTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        case .background: return UIColor(hex: "#1C1C1E") ?? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        case .surface: return UIColor(hex: "#2C2C2E") ?? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        case .card: return UIColor(hex: "#3A3A3C") ?? UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1.0)
        case .overlay: return UIColor.black.withAlphaComponent(0.7)

        case .textPrimary: return .white
        case .textSecondary: return UIColor(hex: "#AEAEB2") ?? .lightGray
        case .textTertiary: return UIColor(hex: "#8E8E93") ?? .gray
        case .textOnAccent: return .white

        case .sutraText: return UIColor(hex: "#F5F5F5") ?? .white
        case .commentaryText: return UIColor(hex: "#ECF0F1") ?? .lightGray
        case .chapterTitle: return UIColor(hex: "#3498DB") ?? .systemBlue

        case .primary: return UIColor(hex: "#ECF0F1") ?? .lightGray
        case .accent: return UIColor(hex: "#3498DB") ?? .systemBlue
        case .divider: return UIColor(hex: "#38383A") ?? .darkGray
        case .border: return UIColor(hex: "#48484A") ?? .darkGray
        case .shadow: return UIColor.black.withAlphaComponent(0.3)

        case .bookmark: return UIColor(hex: "#FFA726") ?? .orange
        case .favorite: return UIColor(hex: "#3498DB") ?? .systemBlue

        // UI System colors - DARK GRAY for contrast in dark theme
        case .navigationBar: return UIColor(hex: "#1C1C1E") ?? .systemGray2  // Dark gray navbar
        case .tabBar: return UIColor(hex: "#1C1C1E") ?? .systemGray2         // Dark gray tabbar
        case .separator: return UIColor(hex: "#3A3A3E") ?? .systemGray4     // Separator
        case .bookmarkStar: return UIColor(hex: "#FFD54F") ?? .systemYellow // Bright golden
        }
    }
}

// MARK: - Shape & Motion Tokens
public enum ShapeToken: Int, CaseIterable {
    case cornerRadiusXSmall = 2
    case cornerRadiusSmall = 4
    case cornerRadiusMedium = 8
    case cornerRadiusLarge = 12
    case cornerRadiusXLarge = 16
    case cornerRadiusRound = 999
}

public enum MotionToken: Double, CaseIterable {
    case durationInstant = 0.0
    case durationFast = 0.2
    case durationNormal = 0.3
    case durationSlow = 0.5
    case durationSlower = 0.8
}

// MARK: - Design Tokens Manager
public final class SutraDesignTokens {

    // MARK: - Spacing Tokens
    public enum SpacingTokens: String, CaseIterable {
        case spacingXXS = "xxs"
        case spacingXS = "xs"
        case spacingSM = "sm"
        case spacingMD = "md"
        case spacingLG = "lg"
        case spacingXL = "xl"
        case spacingXXL = "xxl"
        case spacingComponentSM = "component_sm"
        case spacingComponentMD = "component_md"
        case spacingComponentLG = "component_lg"
        case spacingComponentXL = "component_xl"
        case spacingComponentXXL = "component_xxl"
    }

    // MARK: - Shared Instance
    public static let shared = SutraDesignTokens()
    private init() {}

    // MARK: - Current Theme
    public var currentTheme: SutraTheme = .light {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            applyTheme(currentTheme)
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
        }
    }

    // MARK: - Theme Persistence
    public func loadSavedTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = SutraTheme(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            currentTheme = determineAutoTheme()
        }
    }

    private func determineAutoTheme() -> SutraTheme {
        if #available(iOS 13.0, *) {
            switch UITraitCollection.current.userInterfaceStyle {
            case .dark: return .dark
            case .light: return .light
            default: return .light
            }
        } else {
            return .light
        }
    }

    // MARK: - Theme Management
    public func setTheme(_ theme: SutraTheme) {
        currentTheme = theme
    }

    public func toggleTheme() {
        switch currentTheme {
        case .light: setTheme(.sepia)
        case .sepia: setTheme(.dark)
        case .dark: setTheme(.light)
        }
    }

    /// Cycle to the next theme with animation (borrowed from SutraThemeManager)
    public func cycleToNextTheme() {
        let nextTheme: SutraTheme

        switch currentTheme {
        case .light:
            nextTheme = .sepia
        case .sepia:
            nextTheme = .dark
        case .dark:
            nextTheme = .light
        }

        setTheme(nextTheme)

        // Animate theme transition with cross-dissolve
        if let window = UIApplication.shared.windows.first {
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: {
                // Force UI update
            })
        }
    }

    private func applyTheme(_ theme: SutraTheme) {
        DispatchQueue.main.async {
            // Update global UIKit appearance proxies (borrowed from SutraDesignSystem)
            self.applyThemeToApp()

            // Also update interface style for views that don't use appearance proxies
            UIApplication.shared.windows.forEach { window in
                window.overrideUserInterfaceStyle = self.interfaceStyle(for: theme)
            }
        }
    }

    // MARK: - Global Theme Application (borrowed from SutraDesignSystem)
    /// Applies the current theme to ALL UIKit appearance proxies
    /// This makes theme changes GLOBAL and AUTOMATIC
    public func applyThemeToApp() {
        let colors = (
            navigationBar: self.color(for: .navigationBar),
            tabBar: self.color(for: .tabBar),
            separator: self.color(for: .separator),
            bookmarkStar: self.color(for: .bookmarkStar),
            textPrimary: self.color(for: .textPrimary),
            accent: self.color(for: .accent),
            background: self.color(for: .background)
        )

        // World-class navigation bar styling with modern iOS appearance
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = colors.navigationBar
            navBarAppearance.titleTextAttributes = [
                .foregroundColor: colors.textPrimary,
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold)  // Larger, bolder titles
            ]
            navBarAppearance.largeTitleTextAttributes = [
                .foregroundColor: colors.textPrimary,
                .font: UIFont.systemFont(ofSize: 34, weight: .bold)
            ]

            // Subtle shadow for depth
            navBarAppearance.shadowColor = colors.textPrimary.withAlphaComponent(0.1)

            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            UINavigationBar.appearance().compactAppearance = navBarAppearance
            UINavigationBar.appearance().tintColor = colors.textPrimary
        } else {
            // Fallback for older iOS versions
            UINavigationBar.appearance().backgroundColor = colors.navigationBar
            UINavigationBar.appearance().barTintColor = colors.navigationBar
            UINavigationBar.appearance().tintColor = colors.textPrimary
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: colors.textPrimary,
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
            ]
        }

        // World-class tab bar styling with proper icons
        if #available(iOS 13.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = colors.tabBar

            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            UITabBar.appearance().tintColor = colors.accent
        } else {
            UITabBar.appearance().backgroundColor = colors.tabBar
            UITabBar.appearance().barTintColor = colors.tabBar
            UITabBar.appearance().tintColor = colors.accent
        }

        // NOTE: Removed UIView.appearance().backgroundColor - too aggressive
        // Individual views should set their own backgrounds using SutraDesignTokens
    }

    private func interfaceStyle(for theme: SutraTheme) -> UIUserInterfaceStyle {
        switch theme {
        case .light, .sepia: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Color Access
    public func color(for token: ColorToken) -> UIColor {
        let theme = themeProtocol(for: currentTheme)
        return theme.color(for: token)
    }

    public func color(_ token: ColorToken) -> Color {
        Color(color(for: token))
    }

    // MARK: - Spacing Access
    public func spacing(for token: SpacingTokens) -> CGFloat {
        switch token {
        case .spacingXXS, .spacingXS, .spacingSM, .spacingComponentSM:
            return SutraSpacing.Base.sm
        case .spacingMD, .spacingComponentMD:
            return SutraSpacing.Base.md
        case .spacingLG, .spacingXL, .spacingXXL, .spacingComponentLG, .spacingComponentXL, .spacingComponentXXL:
            return SutraSpacing.Base.lg
        }
    }

    // MARK: - Shape Access
    public func shape(for token: ShapeToken) -> CGFloat {
        CGFloat(token.rawValue)
    }

    // MARK: - Motion Access
    public func motionDuration(for token: MotionToken) -> TimeInterval {
        TimeInterval(token.rawValue)
    }

    // MARK: - Internal
    private func themeProtocol(for theme: SutraTheme) -> SutraThemeProtocol {
        switch theme {
        case .light: return LightTheme()
        case .sepia: return SepiaTheme()
        case .dark: return DarkTheme()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let themeDidChange = Notification.Name("SutraThemeDidChangeNotification")
}

// MARK: - SwiftUI Bridge
public struct SutraDesignSystem {
    // Colors
    public static func color(_ token: ColorToken) -> Color {
        Color(SutraDesignTokens.shared.color(for: token))
    }

    // Semantic colors
    public static func sutraTextColor() -> Color {
        SutraDesignSystem.color(.sutraText)
    }

    public static func primaryTextColor() -> Color {
        SutraDesignSystem.color(.textPrimary)
    }

    public static func secondaryTextColor() -> Color {
        SutraDesignSystem.color(.textSecondary)
    }

    public static func backgroundColor() -> Color {
        SutraDesignSystem.color(.background)
    }

    public static func accentColor() -> Color {
        SutraDesignSystem.color(.accent)
    }

    // UI System colors (borrowed from SutraDesignSystem)
    public static func navigationBarColor() -> Color {
        SutraDesignSystem.color(.navigationBar)
    }

    public static func tabBarColor() -> Color {
        SutraDesignSystem.color(.tabBar)
    }

    public static func separatorColor() -> Color {
        SutraDesignSystem.color(.separator)
    }

    public static func bookmarkStarColor() -> Color {
        SutraDesignSystem.color(.bookmarkStar)
    }

    // Shapes
    public static func cornerRadius(_ token: ShapeToken) -> CGFloat {
        SutraDesignTokens.shared.shape(for: token)
    }

    // Motion
    public static func motionDuration(_ token: MotionToken) -> TimeInterval {
        SutraDesignTokens.shared.motionDuration(for: token)
    }
}

// MARK: - UIKit Extensions
extension UILabel {
    public func applySutraColor(_ token: ColorToken) {
        self.textColor = SutraDesignTokens.shared.color(for: token)
    }
}

extension UIView {
    public func applySutraBackground(_ token: ColorToken) {
        self.backgroundColor = SutraDesignTokens.shared.color(for: token)
    }
}

extension UIButton {
    public func applySutraTint(_ token: ColorToken) {
        self.tintColor = SutraDesignTokens.shared.color(for: token)
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    public func sutraBackground(_ token: ColorToken) -> some View {
        self.background(SutraDesignSystem.color(token))
    }

    public func sutraForeground(_ token: ColorToken) -> some View {
        self.foregroundColor(SutraDesignSystem.color(token))
    }

    public func sutraCornerRadius(_ token: ShapeToken) -> some View {
        self.cornerRadius(SutraDesignSystem.cornerRadius(token))
    }
}
