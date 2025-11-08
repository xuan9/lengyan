//
//  DesignSystem+Typography.swift
//  lengyan
//
//  Typography System - Protocol-based, Golden Ratio scaling
//  Clean architecture with type-safe APIs
//

import SwiftUI
import UIKit

// MARK: - Typography Styles (Type-Safe) - 禅意字体系统
public enum SutraTypographyStyle: String, CaseIterable {
    // 📜 Web Design System Hierarchy - 网页设计系统层级
    case sutraTitle         // 主标题: 32px, 粗体 - 经典标题
    case chapterTitle       // 章节标题: 24px, 中等 - 章节名称
    case sacredText         // 正文: 18px, 常规 - 经文内容
    case auxiliaryText      // 辅助文本: 14px - 说明文字

    // 🏛️ iOS Navigation & Titles - iOS导航与标题
    case navigationTitle
    case sutraLarge

    // 📖 Body Text - 正文文本
    case sutraBody
    case sutraCaption

    // 🎨 UI Elements - 界面元素
    case uiLargeTitle
    case uiTitle
    case uiHeading
    case uiBody
    case uiCaption
    case uiSmall

    // 📚 Index & Menu - 索引与菜单
    case indexItem
    case menuItem

    // ✨ Special - 特殊样式
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

// MARK: - Enhanced Chinese Font Manager
struct ChineseFontManager {
    static func appropriateUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let preferredLanguages = Locale.preferredLanguages

        if preferredLanguages.first?.hasPrefix("zh-Hant") == true {
            // Traditional Chinese - Enhanced font hierarchy
            let traditionalFonts = [
                "PingFangTC-Regular", "PingFangTC-Medium", "PingFangTC-Semibold",
                "Hiragino Sans", "Noto Sans TC", "Source Han Sans TC"
            ]

            for fontName in traditionalFonts {
                if let font = createUIFont(name: fontName, size: size, weight: weight) {
                    return font
                }
            }
        } else if preferredLanguages.first?.hasPrefix("zh-Hans") == true {
            // Simplified Chinese - Enhanced font hierarchy
            let simplifiedFonts = [
                "PingFangSC-Regular", "PingFangSC-Medium", "PingFangSC-Semibold",
                "Hiragino Sans CNS", "Noto Sans SC", "Source Han Sans SC"
            ]

            for fontName in simplifiedFonts {
                if let font = createUIFont(name: fontName, size: size, weight: weight) {
                    return font
                }
            }
        }

        // Best fallback - system font with Chinese support
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    private static func createUIFont(name: String, size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        // Try direct font name first
        if let font = UIFont(name: name, size: size) {
            return font
        }

        // Try with weight suffix
        let weightSuffixes = ["", "-Regular", "-Medium", "-Semibold", "-Bold"]
        for suffix in weightSuffixes {
            if let font = UIFont(name: name + suffix, size: size) {
                return font
            }
        }

        return nil
    }
}

// MARK: - Typography Definition - 禅意字体层级
struct SutraTypographyDefinition {
    // 🌸 Web Design System Sizes - 网页设计系统尺寸 (from 设计系统总结.md)
    static let webSizes = (
        sutraTitle: 32 as CGFloat,    // 主标题: 32px, 粗体 - 经典标题
        chapterTitle: 24 as CGFloat,  // 章节标题: 24px, 中等 - 章节名称
        sacredText: 18 as CGFloat,    // 正文: 18px, 常规 - 经文内容
        auxiliaryText: 14 as CGFloat  // 辅助文本: 14px - 说明文字
    )

    // 📱 iOS-Optimized Sizes - iOS优化尺寸
    static let iOSizes = (
        caption: 15 as CGFloat,   // Increased from 14pt for better legibility
        small: 13 as CGFloat,     // Increased from 12pt
        base: 17 as CGFloat,      // iOS standard body size (was 16pt)
        heading: 22 as CGFloat,   // Increased from 20pt for better hierarchy
        title: 28 as CGFloat,     // Increased from 24pt for prominence
        large: 34 as CGFloat,     // Increased from 28pt
        xl: 40 as CGFloat         // Increased from 34pt for maximum impact
    )

    // 🎨 Character Spacing - 禅意字符间距
    // Optimized for Chinese reading and Zen aesthetics
    static let characterSpacing: [SutraTypographyStyle: CGFloat] = [
        // 📜 Web Design System Spacing - 网页设计系统间距
        .sutraTitle: 0.6,        // 主标题间距
        .chapterTitle: 0.5,      // 章节标题间距
        .sacredText: 0.8,        // 正文间距 - 经文内容可读性
        .auxiliaryText: 0.3,     // 辅助文本间距

        // 📱 iOS Optimized Spacing - iOS优化间距
        .sutraBody: 0.8,         // Increased spacing for sutra readability
        .sutraLarge: 1.0,        // Maximum spacing for large sutra text
        .sutraCaption: 0.5,      // Subtle spacing for captions
        .commentary: 0.7,        // Good spacing for commentary

        // 🎯 UI Elements Spacing - 界面元素间距
        .navigationTitle: 0.2,   // Slight spacing for navigation
        .uiLargeTitle: 0.3,     // Minimal spacing for UI titles
        .uiTitle: 0.2,          // Minimal spacing for UI titles
        .uiHeading: 0.1,        // Very minimal spacing for headings
        .uiBody: 0.1,           // Very minimal spacing for body
        .uiCaption: 0.0,        // No spacing for small UI text
        .uiSmall: 0.0,          // No spacing for smallest text
        .indexItem: 0.3,        // Slight spacing for index items
        .menuItem: 0.2,         // Slight spacing for menu items
        .buttonLarge: 0.1,      // Minimal spacing for buttons
        .buttonMedium: 0.1,     // Minimal spacing for buttons
        .label: 0.0             // No spacing for labels
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
        let web = SutraTypographyDefinition.webSizes
        let ios = SutraTypographyDefinition.iOSizes

        switch style {
        // 📜 Web Design System Hierarchy - 网页设计系统层级
        case .sutraTitle:
            return (web.sutraTitle, weight == .regular ? .bold : adjustedWeight)    // 主标题: 32px, 粗体
        case .chapterTitle:
            return (web.chapterTitle, weight == .regular ? .medium : adjustedWeight) // 章节标题: 24px, 中等
        case .sacredText:
            return (web.sacredText, adjustedWeight)                               // 正文: 18px, 常规
        case .auxiliaryText:
            return (web.auxiliaryText, adjustedWeight)                              // 辅助文本: 14px

        // 🏛️ iOS Navigation & Titles - iOS导航与标题
        case .navigationTitle:
            return (ios.title, weight == .regular ? .semibold : adjustedWeight)
        case .sutraLarge:
            return (ios.large, adjustedWeight)

        // 📖 Body Text - 正文文本
        case .sutraBody:
            return (ios.heading, adjustedWeight)
        case .sutraCaption:
            return (ios.base, adjustedWeight)

        // 🎨 UI Elements - 界面元素
        case .uiLargeTitle:
            return (ios.large, weight == .regular ? .bold : adjustedWeight)  // 34pt
        case .uiTitle:
            return (ios.title, weight == .regular ? .semibold : adjustedWeight)  // 28pt
        case .uiHeading:
            return (ios.heading, weight == .regular ? .medium : adjustedWeight)  // 22pt
        case .uiBody:
            return (ios.base, adjustedWeight)
        case .uiCaption:
            return (ios.caption, adjustedWeight)
        case .uiSmall:
            return (ios.small, adjustedWeight)

        // 📚 Index & Menu - 索引与菜单
        case .indexItem:
            return (ios.heading, adjustedWeight)
        case .menuItem:
            return (ios.base, adjustedWeight)

        // ✨ Special - 特殊样式
        case .commentary:
            return (ios.heading, adjustedWeight)
        case .buttonLarge:
            return (ios.heading, weight == .regular ? .semibold : adjustedWeight)
        case .buttonMedium:
            return (ios.base, weight == .regular ? .medium : adjustedWeight)
        case .label:
            return (ios.caption, adjustedWeight)
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

// MARK: - SwiftUI Typography Bridge - 禅意字体桥接
@MainActor
public struct SutraTypographyBridge {
    // 📜 Web Design System Styles - 网页设计系统样式
    public static func sutraTitle(weight: Font.Weight = .bold) -> Font {
        SutraTypographyManager.shared.font(for: .sutraTitle, weight: weight)
    }

    public static func chapterTitle(weight: Font.Weight = .medium) -> Font {
        SutraTypographyManager.shared.font(for: .chapterTitle, weight: weight)
    }

    public static func sacredText(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sacredText, weight: weight)
    }

    public static func auxiliaryText(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .auxiliaryText, weight: weight)
    }

    // 📱 iOS Optimized Styles - iOS优化样式
    public static func sutraLarge(weight: Font.Weight = .regular) -> Font {
        SutraTypographyManager.shared.font(for: .sutraLarge, weight: weight)
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
