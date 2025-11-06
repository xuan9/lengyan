//
//  DesignSystem+Typography.swift
//  lengyan
//
//  Typography System - Protocol-based, Golden Ratio scaling
//  Clean architecture with type-safe APIs
//

import SwiftUI
import UIKit

// MARK: - Typography Styles (Type-Safe)
public enum SutraTypographyStyle: String, CaseIterable {
    // Navigation & Titles
    case navigationTitle
    case sutraLarge
    case sutraTitle

    // Body Text
    case sutraBody
    case sutraCaption

    // UI Elements
    case uiLargeTitle
    case uiTitle
    case uiHeading
    case uiBody
    case uiCaption
    case uiSmall

    // Index & Menu
    case indexItem
    case menuItem

    // Special
    case commentary
    case buttonLarge
    case buttonMedium
    case label
}

// MARK: - Typography Protocol
protocol SutraTypography {
    func font(for style: SutraTypographyStyle, weight: Font.Weight) -> Font
    func uiFont(for style: SutraTypographyStyle, weight: UIFont.Weight) -> UIFont
    func lineHeight(for style: SutraTypographyStyle) -> CGFloat
    func characterSpacing(for style: SutraTypographyStyle) -> CGFloat
}

// MARK: - Golden Ratio Typography Scale
struct GoldenRatioTypography {
    static let baseSize: CGFloat = 16.0
    static let goldenRatio: CGFloat = 1.618

    static func size(level: Int) -> CGFloat {
        let raw = baseSize * pow(goldenRatio, Double(level))
        return round(raw / 2) * 2
    }

    static func lineHeight(base: CGFloat) -> CGFloat {
        base * goldenRatio
    }

    // Preset levels
    static let level0: CGFloat = baseSize     // 16pt
    static let level1: CGFloat = size(level: 1)  // 26pt
    static let level2: CGFloat = size(level: 2)  // 42pt
    static let level3: CGFloat = size(level: 3)  // 68pt
    static let level4: CGFloat = size(level: 4)  // 110pt
}

// MARK: - Font Weight Conversion
extension UIFont.Weight {
    static func from(fontWeight: Font.Weight) -> UIFont.Weight {
        switch fontWeight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

// MARK: - Chinese Font Manager
struct ChineseFontManager {
    static func appropriateUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        // Auto-detect Chinese font based on locale
        let preferredLanguages = Locale.preferredLanguages

        if preferredLanguages.first?.hasPrefix("zh-Hant") == true {
            // Traditional Chinese
            if let font = UIFont(name: "PingFangTC", size: size) {
                return font
            }
        } else if preferredLanguages.first?.hasPrefix("zh-Hans") == true {
            // Simplified Chinese
            if let font = UIFont(name: "PingFangSC", size: size) {
                return font
            }
        }

        // Fallback to system font
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Typography Definition
struct SutraTypographyDefinition {
    // Size definitions using Golden Ratio
    static let sizes = (
        caption: 14 as CGFloat,
        small: 12 as CGFloat,
        base: GoldenRatioTypography.level0,
        heading: GoldenRatioTypography.level1,
        title: GoldenRatioTypography.level2,
        large: GoldenRatioTypography.level3,
        xl: GoldenRatioTypography.level4
    )

    // Character spacing configuration
    static let characterSpacing: [SutraTypographyStyle: CGFloat] = [
        .sutraBody: 0.5,
        .sutraLarge: 0.5,
        .sutraTitle: 0.5,
        .commentary: 0.5,
        .navigationTitle: 0,
        .uiLargeTitle: 0,
        .uiTitle: 0,
        .uiHeading: 0,
        .uiBody: 0,
        .uiCaption: 0,
        .uiSmall: 0,
        .indexItem: 0,
        .menuItem: 0,
        .sutraCaption: 0,
        .buttonLarge: 0,
        .buttonMedium: 0,
        .label: 0
    ]
}

// MARK: - Typography System Implementation
struct SutraTypographySystem: SutraTypography {
    func font(for style: SutraTypographyStyle, weight: Font.Weight = .regular) -> Font {
        let uiFontWeight = UIFont.Weight.from(fontWeight: weight)
        let uiFont = uiFont(for: style, weight: uiFontWeight)
        return Font(uiFont)
    }

    func uiFont(for style: SutraTypographyStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let (size, fontWeight) = sizeAndWeight(for: style, weight: weight)
        return ChineseFontManager.appropriateUIFont(size: size, weight: fontWeight)
    }

    func lineHeight(for style: SutraTypographyStyle) -> CGFloat {
        let (size, _) = sizeAndWeight(for: style, weight: .regular)
        return GoldenRatioTypography.lineHeight(base: size)
    }

    func characterSpacing(for style: SutraTypographyStyle) -> CGFloat {
        SutraTypographyDefinition.characterSpacing[style] ?? 0
    }

    private func sizeAndWeight(for style: SutraTypographyStyle, weight: UIFont.Weight) -> (CGFloat, UIFont.Weight) {
        // Default weight handling
        let adjustedWeight: UIFont.Weight = (weight == .regular) ? weight : weight
        let s = SutraTypographyDefinition.sizes

        switch style {
        // Navigation & Titles
        case .navigationTitle:
            return (s.title, weight == .regular ? .semibold : adjustedWeight)
        case .sutraLarge:
            return (s.large, adjustedWeight)
        case .sutraTitle:
            return (s.title, weight == .regular ? .medium : adjustedWeight)

        // Body Text
        case .sutraBody:
            return (s.heading, adjustedWeight)
        case .sutraCaption:
            return (s.base, adjustedWeight)

        // UI Elements
        case .uiLargeTitle:
            return (s.xl, weight == .regular ? .bold : adjustedWeight)
        case .uiTitle:
            return (s.title, weight == .regular ? .semibold : adjustedWeight)
        case .uiHeading:
            return (s.heading, weight == .regular ? .medium : adjustedWeight)
        case .uiBody:
            return (s.base, adjustedWeight)
        case .uiCaption:
            return (s.caption, adjustedWeight)
        case .uiSmall:
            return (s.small, adjustedWeight)

        // Index & Menu
        case .indexItem:
            return (s.heading, adjustedWeight)
        case .menuItem:
            return (s.base, adjustedWeight)

        // Special
        case .commentary:
            return (s.heading, adjustedWeight)
        case .buttonLarge:
            return (s.heading, weight == .regular ? .semibold : adjustedWeight)
        case .buttonMedium:
            return (s.base, weight == .regular ? .medium : adjustedWeight)
        case .label:
            return (s.caption, adjustedWeight)
        }
    }
}

// MARK: - Typography Manager
@MainActor
public final class SutraTypographyManager {
    public static let shared = SutraTypographyManager()
    private init() {}

    private let system = SutraTypographySystem()

    // MARK: - Public API
    public func font(for style: SutraTypographyStyle, weight: Font.Weight = .regular) -> Font {
        system.font(for: style, weight: weight)
    }

    public func uiFont(for style: SutraTypographyStyle, weight: UIFont.Weight = .regular) -> UIFont {
        system.uiFont(for: style, weight: weight)
    }

    public func lineHeight(for style: SutraTypographyStyle) -> CGFloat {
        system.lineHeight(for: style)
    }

    public func characterSpacing(for style: SutraTypographyStyle) -> CGFloat {
        system.characterSpacing(for: style)
    }
}

// MARK: - SwiftUI Typography Bridge
@MainActor
public struct SutraTypographyBridge {
    // Sutra text styles
    public static func sutraLarge(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sutraLarge, weight: weight)
    }

    public static func sutraTitle(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sutraTitle, weight: weight)
    }

    public static func sutraBody(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sutraBody, weight: weight)
    }

    public static func sutraCaption(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sutraCaption, weight: weight)
    }

    public static func uiSmall(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .uiSmall, weight: weight)
    }

    // UI text styles
    public static func uiLargeTitle(weight: Font.Weight = .bold) -> Font {
        SutraTypographyManager.shared.font(for: .uiLargeTitle, weight: weight)
    }

    public static func uiTitle(weight: Font.Weight = .bold) -> Font {
        SutraTypographyManager.shared.font(for: .uiTitle, weight: weight)
    }

    public static func uiHeading(weight: Font.Weight = .semibold) -> Font {
        SutraTypographyManager.shared.font(for: .uiHeading, weight: weight)
    }

    public static func uiBody(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .uiBody, weight: weight)
    }

    public static func uiCaption(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .uiCaption, weight: weight)
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    public func sutraTypography(_ style: SutraTypographyStyle, weight: Font.Weight = .regular) -> some View {
        self.font(SutraTypographyManager.shared.font(for: style, weight: weight))
    }

    public func sutraLineHeight(_ style: SutraTypographyStyle) -> some View {
        let lineHeight = SutraTypographyManager.shared.lineHeight(for: style)
        let fontLineHeight = SutraTypographySystem().uiFont(for: style).lineHeight
        return self.lineSpacing(lineHeight - fontLineHeight)
    }
}

// MARK: - UIKit Extensions
extension UILabel {
    public func applySutraTypography(_ style: SutraTypographyStyle, weight: UIFont.Weight = .regular) {
        font = SutraTypographyManager.shared.uiFont(for: style, weight: weight)
    }
}

extension UIButton {
    public func applySutraTypography(_ style: SutraTypographyStyle, weight: UIFont.Weight = .regular) {
        titleLabel?.font = SutraTypographyManager.shared.uiFont(for: style, weight: weight)
    }
}

extension UITextView {
    public func applySutraTypography(_ style: SutraTypographyStyle, weight: UIFont.Weight = .regular) {
        font = SutraTypographyManager.shared.uiFont(for: style, weight: weight)
    }
}

extension UINavigationBar {
    public func applySutraTypography(_ style: SutraTypographyStyle = .navigationTitle, weight: UIFont.Weight = .semibold) {
        let font = SutraTypographyManager.shared.uiFont(for: style, weight: weight)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .font: font,
            .foregroundColor: UIColor.label
        ]

        standardAppearance = appearance
        compactAppearance = appearance
        scrollEdgeAppearance = appearance
    }
}
