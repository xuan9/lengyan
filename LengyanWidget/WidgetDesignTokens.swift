//
//  WidgetDesignTokens.swift
//  LengyanWidget
//
//  Widget 独立设计令牌 — 不依赖主 App 的 DesignSystem+Tokens
//  精简版禅意色彩，与主 App 保持一致的视觉语言
//

import SwiftUI

/// Widget 专用设计令牌
enum WidgetTokens {

    // MARK: - Colors

    /// 宣纸暖白背景
    static let background = Color(red: 250/255, green: 248/255, blue: 243/255)

    /// 内容区域（佛光暖黄）
    static let surface = Color(red: 255/255, green: 248/255, blue: 231/255)

    /// 卡片白（纯净宣纸）
    static let card = Color(red: 255/255, green: 254/255, blue: 249/255)

    /// 主要文字（传统墨黑）
    static let textPrimary = Color(red: 38/255, green: 38/255, blue: 38/255)

    /// 次要文字（古檀褐）
    static let textSecondary = Color(red: 74/255, green: 55/255, blue: 40/255)

    /// 提示文字（沉香木）
    static let textTertiary = Color(red: 139/255, green: 115/255, blue: 85/255)

    /// 经文正文（传世御墨）
    static let sutraText = Color(red: 13/255, green: 13/255, blue: 13/255)

    /// 古金装饰
    static let decorativeGold = Color(red: 196/255, green: 162/255, blue: 101/255)

    /// 分隔线（宣纸纹）
    static let separator = Color(red: 232/255, green: 220/255, blue: 196/255)

    // MARK: - Typography

    /// 经文楷体字体
    static func sutraFont(size: CGFloat) -> Font {
        // 尝试系统内置楷体
        return .custom("STKaiti", size: size)
    }

    /// 标准 UI 字体
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }
}
