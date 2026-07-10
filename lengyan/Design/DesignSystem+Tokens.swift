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

// MARK: - Color Tokens (Type-Safe Enum) - 禅意色彩哲学
public enum ColorToken: String, CaseIterable {
    // 🌫️ Zen Background Colors - 禅意背景色
    case background          // 禅雾灰 - #f8f9f6 (70%大面积背景)
    case surface             // 禅雾灰 - #f8f9f6 (内容区域)
    case card                // 禅纸白 - #ffffff (纯净载体)
    case overlay             // 禅墨黑 - #1f2937 (遮罩层)

    // 🖋️ Zen Text Colors - 禅意文字色
    case textPrimary         // 禅墨黑 - #1f2937 (主要文本)
    case textSecondary       // 禅石灰 - #6b7280 (次要文本)
    case textTertiary        // 禅石灰 - #6b7280 (提示文本)
    case textOnAccent        // 禅纸白 - #ffffff (强调色上文本)

    // 📜 Sutra-specific Colors - 经文专用色
    case sutraText           // 禅墨黑 - #1f2937 (经文内容)
    case commentaryText      // 禅石灰 - #6b7280 (注释文字)
    case chapterTitle        // 竹绿 - #4a5d3a (章节标题)

    // 🎋 Zen Accent Colors - 禅意强调色
    case primary             // 禅竹绿 - #4a5d3a (主要操作)
    case accent              // 禅空蓝 - #3b82f6 (辅助强调)
    case divider             // 禅雾灰 - #f8f9f6 (分隔线)
    case border              // 禅雾灰 - #f8f9f6 (边框)
    case shadow              // 禅暮紫 - #6b46c1 (阴影)

    // ⭐ Status Colors - 状态色
    case bookmark            // 鎏金 - #B8860B (收藏色)
    case favorite            // 朱砂红 - #DC143C (喜爱色)

    // ✨ Decorative Colors - 装饰色
    case decorativeGold      // 古金微光 - #C4A265 (卡片边缘装饰)
    case sacredGlow          // 佛光柔辉 - #FFE4B5 (选中状态柔光)

    // 🏛️ UI System Colors - 界面系统色
    case navigationBar       // 宣纸暖色 - #FAF8F3 (导航栏)
    case tabBar              // 宣纸米色 - #FAF7F0 (标签栏)
    case separator           // 宣纸纹 - #E8DCC4 (分隔符)
    case bookmarkStar        // 鎏金 - #B8860B (书签星)
}

// MARK: - Theme Protocol
protocol SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor
}

// MARK: - Light Theme Implementation - 禅意色彩哲学
struct LightTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        // 🌅 Sacred Zen Background Colors - 神圣禅意背景色
        case .background: return UIColor(hex: "#FAF8F3") ?? .white       // 传世宣纸 - 温暖如传统宣纸的米色
        case .surface: return UIColor(hex: "#FFF8E7") ?? .white         // 佛光暖黄 - 内容区域，与背景形成微妙温暖对比
        case .card: return UIColor(hex: "#FFFEF9")?.withAlphaComponent(0.98) ?? .white  // 纯净宣纸 - 内容载体
        case .overlay: return UIColor(hex: "#2C1810")?.withAlphaComponent(0.7) ?? .black // 古墨遮罩

        // 🖋️ Sacred Text Colors - 神圣文字色
        case .textPrimary: return UIColor(hex: "#262626") ?? .black        // 传统墨黑 - 主要文本，庄重深邃
        case .textSecondary: return UIColor(hex: "#4A3728") ?? .darkGray   // 古檀褐 - 次要文本，沉稳厚重
        case .textTertiary: return UIColor(hex: "#7E6548") ?? .gray       // 沉香木 - 提示文本，WCAG AA 达标
        case .textOnAccent: return UIColor(hex: "#FFF8E7") ?? .white      // 佛光白 - 强调色上的神圣光辉

        // 📜 Sutra-specific Sacred Colors - 经文专用神圣色
        case .sutraText: return UIColor(hex: "#0D0D0D") ?? .black         // 传世御墨 - 经文内容，传统墨色
        case .commentaryText: return UIColor(hex: "#5C4033") ?? .darkGray // 茶褐 - 注释文字，古朴厚重
        case .chapterTitle: return UIColor(hex: "#B8860B") ?? .systemYellow // 鎏金色 - 章节标题，神圣尊贵

        // 🎋 Vibrant Zen Accent Colors - 生机禅意强调色
        case .primary: return UIColor(hex: "#228B22") ?? .systemGreen      // 竹翠绿 - 主要操作，生机勃勃
        case .accent: return UIColor(hex: "#2E7D32") ?? .systemGreen     // 禅竹翠 - 辅助强调，沉稳生机
        case .divider: return UIColor(hex: "#E8DCC4") ?? .lightGray      // 宣纸纹 - 分隔线，自然纹理
        case .border: return UIColor(hex: "#D4A574") ?? .lightGray        // 古铜色 - 边框，古典雅致
        case .shadow: return UIColor(hex: "#8B4513")?.withAlphaComponent(0.15) ?? .brown // 古木影 - 阴影

        // ⭐ Sacred Status Colors - 神圣状态色
        case .bookmark: return UIColor(hex: "#B8860B") ?? .systemYellow     // 鎏金 - 收藏标记，珍贵如金
        case .favorite: return UIColor(hex: "#DC143C") ?? .systemRed       // 朱砂红 - 喜爱标记，神圣印章

        // ✨ Decorative Colors - 装饰色
        case .decorativeGold: return UIColor(hex: "#C4A265") ?? .systemYellow  // 古金微光 - 卡片边缘装饰
        case .sacredGlow: return UIColor(hex: "#FFE4B5") ?? .systemYellow     // 佛光柔辉 - 选中状态柔光

        // 🏛️ Sacred UI System Colors - 神圣界面系统色
        case .navigationBar: return UIColor(hex: "#FAF8F3") ?? .white      // 同背景色 - 无边界沉浸
        case .tabBar: return UIColor(hex: "#FAF7F0") ?? .white            // 宣纸米色 - 标签栏温润如玉
        case .separator: return UIColor(hex: "#E8DCC4") ?? .lightGray     // 宣纸纹 - 分隔符自然纹理
        case .bookmarkStar: return UIColor(hex: "#B8860B") ?? .systemYellow // 鎏金星 - 书签星如金子般珍贵
        }
    }
}

// MARK: - Sepia Theme Implementation — 古籍
/// 灵感：百年经卷的温暖茶色，泛黄而不脏，如秋日古寺
struct SepiaTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        // 背景 — 温暖茶色，如翻开的古卷
        case .background: return UIColor(hex: "#F2E8D5") ?? .white
        case .surface: return UIColor(hex: "#F7F0E2") ?? .white
        case .card: return UIColor(hex: "#EDE3D0") ?? .white
        case .overlay: return UIColor(hex: "#3E2723")?.withAlphaComponent(0.6) ?? .black

        // 文字 — 深褐清晰，不偏红不偏灰
        case .textPrimary: return UIColor(hex: "#33231A") ?? .black
        case .textSecondary: return UIColor(hex: "#5C4A3A") ?? .darkGray
        case .textTertiary: return UIColor(hex: "#8B7B6B") ?? .gray
        case .textOnAccent: return UIColor(hex: "#FBF6ED") ?? .white

        // 经文 — 浓墨深褐，如古卷上的墨迹
        case .sutraText: return UIColor(hex: "#1A100A") ?? .black
        case .commentaryText: return UIColor(hex: "#5C4A3A") ?? .darkGray
        case .chapterTitle: return UIColor(hex: "#8B6914") ?? .brown

        // 强调 — 温暖竹绿，与茶色和谐
        case .primary: return UIColor(hex: "#5B7A4A") ?? .systemGreen
        case .accent: return UIColor(hex: "#6B8E5A") ?? .systemGreen
        case .divider: return UIColor(hex: "#D9CEBC") ?? .lightGray
        case .border: return UIColor(hex: "#C9BCA8") ?? .lightGray
        case .shadow: return UIColor(hex: "#5C4A3A")?.withAlphaComponent(0.10) ?? .brown

        case .bookmark: return UIColor(hex: "#B8860B") ?? .systemYellow
        case .favorite: return UIColor(hex: "#A0522D") ?? .brown

        // 装饰 — 温暖古金
        case .decorativeGold: return UIColor(hex: "#B8976A") ?? .systemYellow
        case .sacredGlow: return UIColor(hex: "#F2E8D5") ?? .systemYellow

        // UI — 与背景协调的暖色
        case .navigationBar: return UIColor(hex: "#F2E8D5") ?? .white
        case .tabBar: return UIColor(hex: "#EDE4D3") ?? .white
        case .separator: return UIColor(hex: "#D9CEBC") ?? .lightGray
        case .bookmarkStar: return UIColor(hex: "#B8860B") ?? .systemYellow
        }
    }
}

// MARK: - Dark Theme — 月下禅房
/// 灵感：深夜禅房，烛光映壁，深檀木色中透出温暖
struct DarkTheme: SutraThemeProtocol {
    func color(for token: ColorToken) -> UIColor {
        switch token {
        // 背景 — 深檀木，不纯黑，有温度
        case .background: return UIColor(hex: "#1C1814") ?? .black
        case .surface: return UIColor(hex: "#2C241E") ?? .black
        case .card: return UIColor(hex: "#38302A") ?? .darkGray
        case .overlay: return UIColor(hex: "#0A0908")?.withAlphaComponent(0.8) ?? .black

        // 文字 — 暖白而非冷白，如烛光映纸
        case .textPrimary: return UIColor(hex: "#E8DFD0") ?? .white
        case .textSecondary: return UIColor(hex: "#C4B8A4") ?? .lightGray
        case .textTertiary: return UIColor(hex: "#9A8E7E") ?? .gray
        case .textOnAccent: return UIColor(hex: "#1C1814") ?? .black

        // 经文 — 暖白柔和，长时间阅读不刺眼
        case .sutraText: return UIColor(hex: "#E8DFD0") ?? .white
        case .commentaryText: return UIColor(hex: "#C4B8A4") ?? .lightGray
        case .chapterTitle: return UIColor(hex: "#D4A84B") ?? .systemYellow

        // 强调 — 暖色系，不使用荧光色
        case .primary: return UIColor(hex: "#7A9B68") ?? .systemGreen
        case .accent: return UIColor(hex: "#C49A4A") ?? .systemOrange
        case .divider: return UIColor(hex: "#4A403A") ?? .darkGray
        case .border: return UIColor(hex: "#5A504A") ?? .darkGray
        case .shadow: return UIColor(hex: "#000000")?.withAlphaComponent(0.35) ?? .black

        case .bookmark: return UIColor(hex: "#D4A84B") ?? .systemYellow
        case .favorite: return UIColor(hex: "#C47070") ?? .systemRed

        // 装饰 — 暗金色，不耀眼
        case .decorativeGold: return UIColor(hex: "#B89860") ?? .systemYellow
        case .sacredGlow: return UIColor(hex: "#D4A84B")?.withAlphaComponent(0.15) ?? .systemYellow

        // UI — 与暗色背景协调
        case .navigationBar: return UIColor(hex: "#2C241E") ?? .black
        case .tabBar: return UIColor(hex: "#1C1814") ?? .black
        case .separator: return UIColor(hex: "#4A403A") ?? .darkGray
        case .bookmarkStar: return UIColor(hex: "#D4A84B") ?? .systemYellow
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
    public var currentTheme: SutraTheme = .sepia {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            applyTheme(currentTheme)
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
            // 同步主题到 Widget（Widget 从 SharedVerseData 读取主题）
            DailyVerseProvider.shared.syncWidgetData()
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

        // Force immediate theme application
        applyThemeToApp()

        // Post notification to ensure all views update
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    private func determineAutoTheme() -> SutraTheme {
        return .sepia
    }

    // MARK: - Theme Management
    public func setTheme(_ theme: SutraTheme) {
        currentTheme = theme
    }

    public func toggleTheme() {
        switch currentTheme {
        case .light: setTheme(.sepia)
        case .sepia: setTheme(.light)
        case .dark: setTheme(.light)
        }
    }

    /// Cycle to the next theme with animation
    public func cycleToNextTheme() {
        let nextTheme: SutraTheme

        switch currentTheme {
        case .light:
            nextTheme = .sepia
        case .sepia:
            nextTheme = .light
        case .dark:
            nextTheme = .light
        }

        setTheme(nextTheme)

        // Animate theme transition with cross-dissolve
        if let window = applicationWindows().first {
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
            self.applicationWindows().forEach { window in
                let backgroundColor = self.color(for: .background)
                window.backgroundColor = backgroundColor
                window.rootViewController?.view.backgroundColor = backgroundColor
                window.overrideUserInterfaceStyle = self.interfaceStyle(for: theme)
            }
        }
    }

    private func applicationWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
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

            // 按钮背景透明 — 沉浸感，无色块感
            let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
            buttonAppearance.normal.backgroundImage = UIImage()
            buttonAppearance.normal.titleTextAttributes = [.foregroundColor: self.color(for: .textSecondary)]
            buttonAppearance.highlighted.backgroundImage = UIImage()
            buttonAppearance.disabled.backgroundImage = UIImage()
            buttonAppearance.focused.backgroundImage = UIImage()
            navBarAppearance.buttonAppearance = buttonAppearance
            navBarAppearance.doneButtonAppearance = buttonAppearance

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

        // Readable iOS tab bar styling with stable contrast across themes
        if #available(iOS 13.0, *) {
            let tabBarAppearance = makeTabBarAppearance()

            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            UITabBar.appearance().tintColor = self.color(for: .primary)
            UITabBar.appearance().unselectedItemTintColor = self.color(for: .textSecondary)
            UITabBar.appearance().barTintColor = colors.tabBar
            UITabBar.appearance().backgroundColor = colors.tabBar
            UITabBar.appearance().isTranslucent = false
        } else {
            UITabBar.appearance().backgroundColor = colors.tabBar
            UITabBar.appearance().barTintColor = colors.tabBar
            UITabBar.appearance().tintColor = self.color(for: .primary)
            UITabBar.appearance().unselectedItemTintColor = self.color(for: .textSecondary)
        }

        // NOTE: Removed UIView.appearance().backgroundColor - too aggressive
        // Individual views should set their own backgrounds using SutraDesignTokens
    }

    public func makeTabBarAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = color(for: .tabBar)
        appearance.shadowColor = color(for: .separator)

        let normalTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color(for: .textSecondary)
        ]

        let selectedTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color(for: .textPrimary)
        ]

        let disabledTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color(for: .textTertiary)
        ]

        configureTabBarItemAppearance(
            appearance.stackedLayoutAppearance,
            normalTitleAttributes: normalTitleAttributes,
            selectedTitleAttributes: selectedTitleAttributes,
            disabledTitleAttributes: disabledTitleAttributes,
            titlePositionAdjustment: UIOffset(horizontal: 0, vertical: 2)
        )

        configureTabBarItemAppearance(
            appearance.compactInlineLayoutAppearance,
            normalTitleAttributes: normalTitleAttributes,
            selectedTitleAttributes: selectedTitleAttributes,
            disabledTitleAttributes: disabledTitleAttributes,
            titlePositionAdjustment: .zero
        )

        if #available(iOS 15.0, *) {
            configureTabBarItemAppearance(
                appearance.inlineLayoutAppearance,
                normalTitleAttributes: normalTitleAttributes,
                selectedTitleAttributes: selectedTitleAttributes,
                disabledTitleAttributes: disabledTitleAttributes,
                titlePositionAdjustment: .zero
            )
        }

        return appearance
    }

    private func configureTabBarItemAppearance(
        _ itemAppearance: UITabBarItemAppearance,
        normalTitleAttributes: [NSAttributedString.Key: Any],
        selectedTitleAttributes: [NSAttributedString.Key: Any],
        disabledTitleAttributes: [NSAttributedString.Key: Any],
        titlePositionAdjustment: UIOffset
    ) {
        itemAppearance.normal.titleTextAttributes = normalTitleAttributes
        itemAppearance.normal.iconColor = color(for: .textSecondary)

        itemAppearance.selected.titleTextAttributes = selectedTitleAttributes
        itemAppearance.selected.iconColor = color(for: .primary)

        itemAppearance.disabled.titleTextAttributes = disabledTitleAttributes
        itemAppearance.disabled.iconColor = color(for: .textTertiary)

        itemAppearance.focused.titleTextAttributes = selectedTitleAttributes
        itemAppearance.focused.iconColor = color(for: .primary)

        itemAppearance.normal.titlePositionAdjustment = titlePositionAdjustment
        itemAppearance.selected.titlePositionAdjustment = titlePositionAdjustment
        itemAppearance.disabled.titlePositionAdjustment = titlePositionAdjustment
        itemAppearance.focused.titlePositionAdjustment = titlePositionAdjustment
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

    // MARK: - Responsive Spacing — 5档手动调校
    /// 根据用户字号档位缩放间距，每档人工验证过视觉平衡
    /// - Parameter base: 基准间距值（中等字号时的值）
    /// - Returns: 缩放后的间距值
    public func responsiveSpacing(_ base: CGFloat) -> CGFloat {
        let scale: CGFloat
        switch Prefers.shared.fontSizeLevel {
        case 0: scale = 0.88   // 特小
        case 1: scale = 0.94   // 小
        case 2: scale = 1.0    // 中（基准）
        case 3: scale = 1.08   // 大
        case 4: scale = 1.15   // 特大
        default: scale = 1.0
        }
        return round(base * scale)
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
