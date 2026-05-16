//
//  DesignSystem+Typography.swift
//  lengyan
//
//  Typography System - Protocol-based, Golden Ratio scaling
//  Clean architecture with type-safe APIs
//

import SwiftUI
import UIKit

// MARK: - Traditional Chinese Typography Principles
/// Traditional Chinese character spacing based on printing standards
public enum TraditionalSpacing {
    case tight        // 紧密 - Classical texts
    case standard     // 标准 - Modern reading
    case comfortable  // 舒适 - Extended reading
    case contemplative // 冥想 - Meditation mode

    var characterSpacing: CGFloat {
        switch self {
        case .tight: return 0.02
        case .standard: return 0.08
        case .comfortable: return 0.12
        case .contemplative: return 0.18
        }
    }

    var lineSpacingMultiplier: CGFloat {
        switch self {
        case .tight: return 1.4
        case .standard: return 1.618  // Golden ratio
        case .comfortable: return 1.8
        case .contemplative: return 2.0
        }
    }

    var paragraphIndent: CGFloat {
        switch self {
        case .tight: return 24.0      // 1.5 characters
        case .standard: return 32.0   // 2 characters (traditional)
        case .comfortable: return 40.0 // 2.5 characters
        case .contemplative: return 48.0 // 3 characters
        }
    }
}

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

    /// UI 骨架样式不跟随字号缩放（同 iOS Dynamic Type 行为）
    var isFixedUI: Bool {
        switch self {
        case .navigationTitle, .uiLargeTitle, .uiTitle, .uiHeading,
             .uiBody, .uiCaption, .uiSmall, .label, .buttonLarge, .buttonMedium:
            return true
        default:
            return false
        }
    }
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
/// 系统字体 PingFang — 细字重 + 大字号 = 典雅通透
/// Light weight at larger sizes: the quieter the font, the louder the content
struct ChineseFontManager {
    /// Font size multiplier based on user preference (0.8x ~ 1.25x)
    static var fontSizeMultiplier: CGFloat {
        switch Prefers.shared.fontSizeLevel {
        case 0: return 0.8
        case 1: return 0.9
        case 2: return 1.0
        case 3: return 1.1
        case 4: return 1.25
        default: return 1.0
        }
    }

    /// Optical Sizing — 字号越大字重越轻，字号越小字重越重
    /// 保证小字号可读性，大字号不笨重
    static func adjustedWeight(_ base: UIFont.Weight) -> UIFont.Weight {
        let weights: [UIFont.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        guard let idx = weights.firstIndex(of: base) else { return base }

        let shift: Int
        switch Prefers.shared.fontSizeLevel {
        case 0: shift = 0      // 特小：基准，字重正好
        case 1: shift = 0      // 小：不变
        case 2: shift = -1     // 中：减轻 1 档
        case 3: shift = -1     // 大：减轻 1 档
        case 4: shift = -2     // 特大：减轻 2 档
        default: shift = 0
        }
        let newIdx = max(0, min(weights.count - 1, idx + shift))
        return weights[newIdx]
    }

    static func appropriateUIFont(size: CGFloat, weight: UIFont.Weight, style: SutraTypographyStyle) -> UIFont {
        // iPad 屏幕大、视距远，且由于排版采用了极宽的 680pt 容器
        // 根据 Apple HIG 建议，在杂志/沉浸阅读类应用中，iPad 的基础字号应做适当等比放大，以维持与 iPhone 相同的主观视觉比例与每行字数
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let padScale: CGFloat = isPad ? 1.15 : 1.0 // 放大 15% 保证 680pt 下每行约 30-40 个中文字符的黄金阅读律
        
        // UI 骨架样式：固定大小和字重
        // 内容样式：跟随字号缩放 + optical sizing 字重调整
        if style.isFixedUI {
            // UI 元素也稍微放大一点点以适应 iPad，但不要像正文放大那么多
            let uiScale: CGFloat = isPad ? 1.1 : 1.0
            return UIFont.systemFont(ofSize: round(size * uiScale), weight: weight)
        } else {
            let finalSize = round(size * fontSizeMultiplier * padScale)
            let finalWeight = Self.adjustedWeight(weight)
            return UIFont.systemFont(ofSize: finalSize, weight: finalWeight)
        }
    }
}

// MARK: - Typography Definition - 禅意字体层级
struct SutraTypographyDefinition {
    // 🌸 Web Design System Sizes — 细字重 + 大字号策略
    static let webSizes = (
        sutraTitle: 34 as CGFloat,    // 32→34, 配 Light 字重
        chapterTitle: 26 as CGFloat,  // 24→26, 配 Light 字重
        sacredText: 22 as CGFloat,    // 20→22, 配 Light 字重
        auxiliaryText: 15 as CGFloat  // 14→15
    )

    // 📱 iOS-Optimized Sizes — 细字重需稍大字号补偿视觉重量
    static let iOSizes = (
        caption: 16 as CGFloat,   // 15→16
        small: 14 as CGFloat,     // 13→14
        base: 18 as CGFloat,      // 17→18, 核心阅读尺寸
        heading: 24 as CGFloat,   // 22→24
        title: 30 as CGFloat,     // 28→30
        large: 36 as CGFloat,     // 34→36
        xl: 42 as CGFloat         // 40→42
    )

    // 🎨 Character Spacing - 禅意字符间距
    // Optimized for Chinese reading and Zen aesthetics
    static let characterSpacing: [SutraTypographyStyle: CGFloat] = [
        // 📜 经文 — PingFang 字宽充足，微收字距更紧凑雅致
        .sutraTitle: 0.4,
        .chapterTitle: 0.3,
        .sacredText: 0.5,          // 1.2→0.5
        .auxiliaryText: 0.2,

        // 📖 正文
        .sutraBody: 0.5,           // 1.2→0.5
        .sutraLarge: 0.5,          // 1.2→0.5
        .sutraCaption: 0.3,
        .commentary: 0.4,          // 0.7→0.4

        // 🎯 UI — 层次靠字号，字距最小化
        .navigationTitle: 0.1,
        .uiLargeTitle: 0.2,
        .uiTitle: 0.1,
        .uiHeading: 0.0,
        .uiBody: 0.0,
        .uiCaption: 0.0,
        .uiSmall: 0.0,
        .indexItem: 0.2,
        .menuItem: 0.1,
        .buttonLarge: 0.0,
        .buttonMedium: 0.0,
        .label: 0.0
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
        return ChineseFontManager.appropriateUIFont(size: size, weight: fontWeight, style: style)
    }

    func lineHeight(for style: SutraTypographyStyle) -> CGFloat {
        let (size, _) = sizeAndWeight(for: style, weight: .regular)
        return size * 1.8  // 细字重需更多行间呼吸
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
        // 📜 经文层级 — 细字大号，如宣纸淡墨
        case .sutraTitle:
            return (web.sutraTitle, weight == .regular ? .regular : adjustedWeight)
        case .chapterTitle:
            return (web.chapterTitle, weight == .regular ? .light : adjustedWeight)
        case .sacredText:
            return (web.sacredText, weight == .regular ? .light : adjustedWeight)
        case .auxiliaryText:
            return (web.auxiliaryText, weight == .regular ? .light : adjustedWeight)

        // 🏛️ 导航标题 — Regular 足矣，大号即有分量
        case .navigationTitle:
            return (ios.title, weight == .regular ? .regular : adjustedWeight)
        case .sutraLarge:
            return (ios.large, weight == .regular ? .light : adjustedWeight)

        // 📖 正文 — Regular 通透且清晰
        case .sutraBody:
            return (ios.heading, weight == .regular ? .regular : adjustedWeight)
        case .sutraCaption:
            return (ios.base, weight == .regular ? .regular : adjustedWeight)

        // 🎨 UI 元素 — 层次靠字号而非字重
        case .uiLargeTitle:
            return (ios.large, weight == .regular ? .regular : adjustedWeight)
        case .uiTitle:
            return (ios.title, weight == .regular ? .regular : adjustedWeight)
        case .uiHeading:
            return (ios.heading, weight == .regular ? .regular : adjustedWeight)
        case .uiBody:
            return (ios.base, weight == .regular ? .regular : adjustedWeight)
        case .uiCaption:
            return (ios.caption, weight == .regular ? .regular : adjustedWeight)
        case .uiSmall:
            return (ios.small, weight == .regular ? .regular : adjustedWeight)

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
