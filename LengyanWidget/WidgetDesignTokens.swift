//
//  WidgetDesignTokens.swift
//  LengyanWidget
//
//  Widget 主题感知设计令牌
//  三套色彩：Light / Sepia / Dark，与主 App 保持一致
//  通过 App Group UserDefaults 读取用户当前主题
//

import SwiftUI

/// Widget 主题枚举，与主 App SutraTheme 同步
enum WidgetTheme: String {
    case light
    case sepia
    case dark
}

/// Widget 专用设计令牌 — 主题感知
enum WidgetTokens {

    // MARK: - Theme Resolution

    static var currentTheme: WidgetTheme = .sepia

    /// 从 SharedVerseData 的主题字段解析
    static func resolveTheme(from themeString: String?) {
        if let str = themeString,
           let theme = WidgetTheme(rawValue: str) {
            currentTheme = theme
        } else {
            currentTheme = .sepia
        }
    }

    // MARK: - Colors (computed per theme)

    /// 背景色
    static var background: Color {
        switch currentTheme {
        case .light:  return Color(red: 250/255, green: 248/255, blue: 243/255)
        case .sepia:  return Color(red: 242/255, green: 232/255, blue: 213/255)
        case .dark:   return Color(red: 28/255, green: 24/255, blue: 20/255)
        }
    }

    /// 内容区域色
    static var surface: Color {
        switch currentTheme {
        case .light:  return Color(red: 255/255, green: 248/255, blue: 231/255)
        case .sepia:  return Color(red: 247/255, green: 240/255, blue: 226/255)
        case .dark:   return Color(red: 44/255, green: 36/255, blue: 30/255)
        }
    }

    /// 主要文字色
    static var textPrimary: Color {
        switch currentTheme {
        case .light:  return Color(red: 38/255, green: 38/255, blue: 38/255)
        case .sepia:  return Color(red: 51/255, green: 35/255, blue: 26/255)
        case .dark:   return Color(red: 232/255, green: 223/255, blue: 208/255)
        }
    }

    /// 次要文字色
    static var textSecondary: Color {
        switch currentTheme {
        case .light:  return Color(red: 74/255, green: 55/255, blue: 40/255)
        case .sepia:  return Color(red: 92/255, green: 74/255, blue: 58/255)
        case .dark:   return Color(red: 196/255, green: 184/255, blue: 164/255)
        }
    }

    /// 提示文字色 — WCAG AA ≥4.5:1
    /// light: ~5.0:1  sepia: ~4.6:1（自 3.4:1 提升）  dark: ~5.4:1
    static var textTertiary: Color {
        switch currentTheme {
        case .light:  return Color(red: 126/255, green: 101/255, blue: 72/255)
        case .sepia:  return Color(red: 118/255, green: 99/255, blue: 78/255)
        case .dark:   return Color(red: 154/255, green: 142/255, blue: 126/255)
        }
    }

    /// 经文正文色
    static var sutraText: Color {
        switch currentTheme {
        case .light:  return Color(red: 13/255, green: 13/255, blue: 13/255)
        case .sepia:  return Color(red: 26/255, green: 16/255, blue: 10/255)
        case .dark:   return Color(red: 232/255, green: 223/255, blue: 208/255)
        }
    }

    /// 竹绿强调色
    static var primary: Color {
        switch currentTheme {
        case .light:  return Color(red: 34/255, green: 139/255, blue: 34/255)
        case .sepia:  return Color(red: 91/255, green: 122/255, blue: 74/255)
        case .dark:   return Color(red: 122/255, green: 155/255, blue: 104/255)
        }
    }

    /// 古金装饰色
    static var decorativeGold: Color {
        switch currentTheme {
        case .light:  return Color(red: 196/255, green: 162/255, blue: 101/255)
        case .sepia:  return Color(red: 184/255, green: 151/255, blue: 106/255)
        case .dark:   return Color(red: 184/255, green: 152/255, blue: 96/255)
        }
    }

    /// 分隔线色
    static var divider: Color {
        switch currentTheme {
        case .light:  return Color(red: 232/255, green: 220/255, blue: 196/255)
        case .sepia:  return Color(red: 217/255, green: 206/255, blue: 188/255)
        case .dark:   return Color(red: 74/255, green: 64/255, blue: 58/255)
        }
    }

    /// 鎏金收藏色
    static var bookmark: Color {
        switch currentTheme {
        case .light:  return Color(red: 184/255, green: 134/255, blue: 11/255)
        case .sepia:  return Color(red: 184/255, green: 134/255, blue: 11/255)
        case .dark:   return Color(red: 212/255, green: 168/255, blue: 75/255)
        }
    }

    // MARK: - Typography

    /// 经文楷体字体
    static func sutraFont(size: CGFloat) -> Font {
        return .custom("STKaiti", size: size)
    }

    /// 标准 UI 字体
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }
}
