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
}

// MARK: - Theme Protocol
protocol SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor
}

// MARK: - Light Theme Implementation
struct LightTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        case .background: return UIColor(hex: "#FFFEF7") ?? .black
        case .surface: return .white
        case .card: return .white
        case .overlay: return UIColor.black.withAlphaComponent(0.4)

        case .textPrimary: return UIColor(hex: "#2C3E50") ?? .black
        case .textSecondary: return UIColor(hex: "#5D6D7E") ?? .black
        case .textTertiary: return UIColor(hex: "#7F8C8D") ?? .black
        case .textOnAccent: return .white

        case .sutraText: return UIColor(hex: "#1A252F") ?? .black
        case .commentaryText: return UIColor(hex: "#34495E") ?? .black
        case .chapterTitle: return UIColor(hex: "#C0392B") ?? .black

        case .primary: return UIColor(hex: "#2C3E50") ?? .black
        case .accent: return UIColor(hex: "#C0392B") ?? .black
        case .divider: return UIColor(hex: "#E8E8E8") ?? .black
        case .border: return UIColor(hex: "#D5D8DC") ?? .black
        case .shadow: return UIColor.black.withAlphaComponent(0.08)

        case .bookmark: return UIColor(hex: "#F39C12") ?? .black
        case .favorite: return UIColor(hex: "#E74C3C") ?? .black
        }
    }
}

// MARK: - Sepia Theme Implementation
struct SepiaTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        case .background: return UIColor(hex: "#F5E6D3") ?? .black
        case .surface: return UIColor(hex: "#FAF0E6") ?? .black
        case .card: return .white
        case .overlay: return UIColor.black.withAlphaComponent(0.5)

        case .textPrimary: return UIColor(hex: "#3E2723") ?? .black
        case .textSecondary: return UIColor(hex: "#5D4037") ?? .black
        case .textTertiary: return UIColor(hex: "#795548") ?? .black
        case .textOnAccent: return .white

        case .sutraText: return UIColor(hex: "#2E1A17") ?? .black
        case .commentaryText: return UIColor(hex: "#4A3426") ?? .black
        case .chapterTitle: return UIColor(hex: "#8D6E63") ?? .black

        case .primary: return UIColor(hex: "#4A3426") ?? .black
        case .accent: return UIColor(hex: "#8D6E63") ?? .black
        case .divider: return UIColor(hex: "#D7CCC8") ?? .black
        case .border: return UIColor(hex: "#BCAAA4") ?? .black
        case .shadow: return UIColor.black.withAlphaComponent(0.12)

        case .bookmark: return UIColor(hex: "#FFB74D") ?? .black
        case .favorite: return UIColor(hex: "#8D6E63") ?? .black
        }
    }
}

// MARK: - Dark Theme Implementation
struct DarkTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        case .background: return UIColor(hex: "#1C1C1E") ?? .black
        case .surface: return UIColor(hex: "#2C2C2E") ?? .black
        case .card: return UIColor(hex: "#3A3A3C") ?? .black
        case .overlay: return UIColor.black.withAlphaComponent(0.7)

        case .textPrimary: return .white
        case .textSecondary: return UIColor(hex: "#AEAEB2") ?? .black
        case .textTertiary: return UIColor(hex: "#8E8E93") ?? .black
        case .textOnAccent: return .white

        case .sutraText: return UIColor(hex: "#F5F5F5") ?? .black
        case .commentaryText: return UIColor(hex: "#ECF0F1") ?? .black
        case .chapterTitle: return UIColor(hex: "#3498DB") ?? .black

        case .primary: return UIColor(hex: "#ECF0F1") ?? .black
        case .accent: return UIColor(hex: "#3498DB") ?? .black
        case .divider: return UIColor(hex: "#38383A") ?? .black
        case .border: return UIColor(hex: "#48484A") ?? .black
        case .shadow: return UIColor.black.withAlphaComponent(0.3)

        case .bookmark: return UIColor(hex: "#FFA726") ?? .black
        case .favorite: return UIColor(hex: "#3498DB") ?? .black
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

    private func applyTheme(_ theme: SutraTheme) {
        DispatchQueue.main.async {
            UIApplication.shared.windows.forEach { window in
                window.overrideUserInterfaceStyle = self.interfaceStyle(for: theme)
            }
        }
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
