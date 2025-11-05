//
//  SwiftUIDesignSystem.swift
//  Lengyan
//
//  SwiftUI-first design system
//  Integrates with modern SwiftUI views
//

import SwiftUI

// MARK: - Color System
extension Color {
    // Light Theme
    static let sutraLightBackground = Color(.sRGBLinear, red: 1.0, green: 1.0, blue: 1.0)
    static let sutraLightCardBackground = Color(.sRGBLinear, red: 0.98, green: 0.98, blue: 0.98)
    static let sutraLightPrimaryText = Color(.sRGBLinear, red: 0.13, green: 0.13, blue: 0.13)
    static let sutraLightSecondaryText = Color(.sRGBLinear, red: 0.40, green: 0.40, blue: 0.40)
    static let sutraLightAccent = Color(.sRGBLinear, red: 0.85, green: 0.75, blue: 0.55)
    static let sutraLightSeparator = Color(.sRGBLinear, red: 0.85, green: 0.85, blue: 0.85)

    // Sepia Theme
    static let sutraSepiaBackground = Color(.sRGBLinear, red: 0.98, green: 0.95, blue: 0.92)
    static let sutraSepiaCardBackground = Color(.sRGBLinear, red: 0.95, green: 0.92, blue: 0.88)
    static let sutraSepiaPrimaryText = Color(.sRGBLinear, red: 0.25, green: 0.15, blue: 0.08)
    static let sutraSepiaSecondaryText = Color(.sRGBLinear, red: 0.45, green: 0.35, blue: 0.25)
    static let sutraSepiaAccent = Color(.sRGBLinear, red: 0.75, green: 0.55, blue: 0.30)
    static let sutraSepiaSeparator = Color(.sRGBLinear, red: 0.75, green: 0.70, blue: 0.65)

    // Dark Theme
    static let sutraDarkBackground = Color(.sRGBLinear, red: 0.08, green: 0.08, blue: 0.10)
    static let sutraDarkCardBackground = Color(.sRGBLinear, red: 0.15, green: 0.15, blue: 0.18)
    static let sutraDarkPrimaryText = Color(.sRGBLinear, red: 0.95, green: 0.95, blue: 0.95)
    static let sutraDarkSecondaryText = Color(.sRGBLinear, red: 0.70, green: 0.70, blue: 0.70)
    static let sutraDarkAccent = Color(.sRGBLinear, red: 0.60, green: 0.75, blue: 0.85)
    static let sutraDarkSeparator = Color(.sRGBLinear, red: 0.30, green: 0.30, blue: 0.35)

    // Semantic Colors
    static let sutraBackground: Color {
        switch theme {
        case .light: return .sutraLightBackground
        case .sepia: return .sutraSepiaBackground
        case .dark: return .sutraDarkBackground
        }
    }

    static let sutraCardBackground: Color {
        switch theme {
        case .light: return .sutraLightCardBackground
        case .sepia: return .sutraSepiaCardBackground
        case .dark: return .sutraDarkCardBackground
        }
    }

    static let sutraPrimaryText: Color {
        switch theme {
        case .light: return .sutraLightPrimaryText
        case .sepia: return .sutraSepiaPrimaryText
        case .dark: return .sutraDarkPrimaryText
        }
    }

    static let sutraSecondaryText: Color {
        switch theme {
        case .light: return .sutraLightSecondaryText
        case .sepia: return .sutraSepiaSecondaryText
        case .dark: return .sutraDarkSecondaryText
        }
    }

    static let sutraAccent: Color {
        switch theme {
        case .light: return .sutraLightAccent
        case .sepia: return .sutraSepiaAccent
        case .dark: return .sutraDarkAccent
        }
    }

    static let sutraSeparator: Color {
        switch theme {
        case .light: return .sutraLightSeparator
        case .sepia: return .sutraSepiaSeparator
        case .dark: return .sutraDarkSeparator
        }
    }
}

// MARK: - Font System
extension Font {
    // Large Titles
    static let sutraLargeTitle = Font.system(size: 28, weight: .bold, design: .serif)
    static let sutraTitle1 = Font.system(size: 24, weight: .bold, design: .serif)
    static let sutraTitle2 = Font.system(size: 20, weight: .semibold, design: .serif)
    static let sutraTitle3 = Font.system(size: 18, weight: .semibold, design: .serif)

    // Body Text
    static let sutraHeadline = Font.system(size: 17, weight: .semibold, design: .serif)
    static let sutraBody = Font.system(size: 16, weight: .regular, design: .serif)
    static let sutraCallout = Font.system(size: 15, weight: .regular, design: .serif)
    static let sutraSubheadline = Font.system(size: 14, weight: .medium, design: .serif)

    // Small Text
    static let sutraFootnote = Font.system(size: 12, weight: .regular, design: .serif)
    static let sutraCaption1 = Font.system(size: 11, weight: .regular, design: .serif)
    static let sutraCaption2 = Font.system(size: 10, weight: .regular, design: .serif)

    // Navigation
    static let sutraNavigationLargeTitle = Font.system(size: 34, weight: .bold, design: .serif)
    static let sutraNavigationTitle = Font.system(size: 17, weight: .semibold, design: .serif)

    // Sutra Specific
    static let sutraText = Font.system(size: 16, weight: .regular, design: .serif)
    static let sutraTextLarge = Font.system(size: 18, weight: .regular, design: .serif)
}

// MARK: - Theme Management
enum SutraTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case sepia = "sepia"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .sepia: return "Sepia"
        case .dark: return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max"
        case .sepia: return "book"
        case .dark: return "moon"
        }
    }
}

// Global Theme State
var theme: SutraTheme {
    get { UserDefaults.standard.sutraTheme }
    set { UserDefaults.standard.sutraTheme = newValue }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    var sutraTheme: SutraTheme {
        get {
            if let stringValue = string(forKey: "sutraTheme"),
               let theme = SutraTheme(rawValue: stringValue) {
                return theme
            }
            return .light
        }
        set {
            set(newValue.rawValue, forKey: "sutraTheme")
            NotificationCenter.default.post(name: .sutraThemeDidChange, object: nil)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let sutraThemeDidChange = Notification.Name("sutraThemeDidChange")
}

// MARK: - Design System View Modifiers
struct SutraThemeModifier: ViewModifier {
    let theme: SutraTheme

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(
                theme == .light ? .light :
                theme == .dark ? .dark : nil
            )
    }
}

extension View {
    func sutraTheme(_ theme: SutraTheme) -> some View {
        self.modifier(SutraThemeModifier(theme: theme))
    }
}

// MARK: - Typography Modifiers
struct SutraFontModifier: ViewModifier {
    enum Style {
        case largeTitle
        case title1
        case title2
        case title3
        case headline
        case body
        case callout
        case subheadline
        case footnote
        case caption1
        case caption2
        case navigationLargeTitle
        case navigationTitle
        case sutraText
        case sutraTextLarge
    }

    let style: Style

    func body(content: Content) -> some View {
        content.font(font)
    }

    private var font: Font {
        switch style {
        case .largeTitle: return .sutraLargeTitle
        case .title1: return .sutraTitle1
        case .title2: return .sutraTitle2
        case .title3: return .sutraTitle3
        case .headline: return .sutraHeadline
        case .body: return .sutraBody
        case .callout: return .sutraCallout
        case .subheadline: return .sutraSubheadline
        case .footnote: return .sutraFootnote
        case .caption1: return .sutraCaption1
        case .caption2: return .sutraCaption2
        case .navigationLargeTitle: return .sutraNavigationLargeTitle
        case .navigationTitle: return .sutraNavigationTitle
        case .sutraText: return .sutraText
        case .sutraTextLarge: return .sutraTextLarge
        }
    }
}

extension View {
    func sutraFont(style: SutraFontModifier.Style) -> some View {
        self.modifier(SutraFontModifier(style: style))
    }
}

// MARK: - Color Modifiers
struct SutraColorModifier: ViewModifier {
    enum Style {
        case background
        case cardBackground
        case primaryText
        case secondaryText
        case accent
        case separator
    }

    let style: Style

    func body(content: Content) -> some View {
        content.foregroundColor(foregroundColor)
    }

    private var foregroundColor: Color {
        switch style {
        case .background: return .sutraBackground
        case .cardBackground: return .sutraCardBackground
        case .primaryText: return .sutraPrimaryText
        case .secondaryText: return .sutraSecondaryText
        case .accent: return .sutraAccent
        case .separator: return .sutraSeparator
        }
    }
}

extension View {
    func sutraColor(_ style: SutraColorModifier.Style) -> some View {
        self.modifier(SutraColorModifier(style: style))
    }
}

// MARK: - Card Style Modifier
struct SutraCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.sutraCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func sutraCard() -> some View {
        self.modifier(SutraCardStyle())
    }
}

// MARK: - Button Style Modifier
struct SutraButtonStyle: ViewModifier {
    enum Variant {
        case primary
        case secondary
        case accent
    }

    let variant: Variant

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return Color.sutraCardBackground
        case .secondary: return Color.clear
        case .accent: return Color.sutraAccent
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return Color.sutraPrimaryText
        case .secondary: return Color.sutraPrimaryText
        case .accent: return Color.white
        }
    }
}

extension View {
    func sutraButton(variant: SutraButtonStyle.Variant = .primary) -> some View {
        self.modifier(SutraButtonStyle(variant: variant))
    }
}

// MARK: - Accessibility Modifiers
struct SutraAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) })
    }
}

extension View {
    func sutraAccessibility(label: String, hint: String? = nil) -> some View {
        self.modifier(SutraAccessibilityModifier(label: label, hint: hint))
    }
}

// MARK: - Haptic Feedback
struct SutraHapticModifier: ViewModifier {
    enum FeedbackType {
        case tap
        case selection
        case notificationSuccess
        case notificationWarning
        case notificationError
    }

    let feedbackType: FeedbackType
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if isEnabled {
                    triggerHaptic()
                }
            }
    }

    private func triggerHaptic() {
        switch feedbackType {
        case .tap:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        case .selection:
            let selection = UISelectionFeedbackGenerator()
            selection.selectionChanged()
        case .notificationSuccess:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        case .notificationWarning:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.warning)
        case .notificationError:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
}

extension View {
    func sutraHaptic(_ feedbackType: SutraHapticModifier.FeedbackType, enabled: Bool = true) -> some View {
        self.modifier(SutraHapticModifier(feedbackType: feedbackType, isEnabled: enabled))
    }
}

// MARK: - Spacing System (8pt Grid)
public struct SutraSpacing {
    // Base 8pt Grid System
    public static let base: CGFloat = 8.0
    public static let half: CGFloat = base / 2      // 4pt
    public static let quarter: CGFloat = base / 4   // 2pt

    // Golden Ratio for harmonious proportions (1.618)
    private static let φ: CGFloat = 1.618

    // Micro Spacing (0-8pt)
    public static let xxxs: CGFloat = quarter          // 2pt
    public static let xxs: CGFloat = half              // 4pt
    public static let xs: CGFloat = base * 0.75        // 6pt
    public static let sm: CGFloat = base               // 8pt

    // Base Spacing (8-24pt)
    public static let md: CGFloat = base * φ            // 12.9pt → 12pt
    public static let lg: CGFloat = base * φ * φ        // 20.9pt → 20pt
    public static let xl: CGFloat = base * 3            // 24pt

    // Component Spacing (24-64pt)
    public static let componentSm: CGFloat = base * 3   // 24pt
    public static let componentMd: CGFloat = base * 4   // 32pt
    public static let componentLg: CGFloat = base * 5   // 40pt
    public static let componentXl: CGFloat = base * 6   // 48pt
    public static let componentXxl: CGFloat = base * 8  // 64pt

    // Section Spacing (64-128pt)
    public static let sectionSm: CGFloat = base * 8     // 64pt
    public static let sectionMd: CGFloat = base * 10    // 80pt
    public static let sectionLg: CGFloat = base * 12    // 96pt

    // Content-specific spacing
    public static let sutraLineSpacing: CGFloat = md    // 12pt
    public static let sutraParagraphSpacing: CGFloat = lg  // 20pt
    public static let sutraChapterSpacing: CGFloat = componentXl  // 48pt
    public static let sutraToCommentaryGap: CGFloat = lg  // 20pt

    // Margins
    public static let marginNarrow: CGFloat = sm        // 8pt
    public static let marginStandard: CGFloat = md      // 12pt
    public static let marginWide: CGFloat = lg          // 20pt
    public static let readingMargin: CGFloat = componentLg  // 40pt
    public static let compactReadingMargin: CGFloat = xl  // 24pt

    // UI Elements
    public static let buttonPadding: CGFloat = md       // 12pt
    public static let buttonSpacing: CGFloat = sm       // 8pt
    public static let cardPadding: CGFloat = md         // 12pt
    public static let cardSpacing: CGFloat = md         // 12pt
    public static let toolbarPadding: CGFloat = sm      // 8pt
}

// MARK: - Golden Ratio Typography
public struct GoldenRatioTypography {
    public static let baseSize: CGFloat = 16.0
    public static let goldenRatio: CGFloat = 1.618

    public static func size(level: Int) -> CGFloat {
        let raw = baseSize * pow(goldenRatio, Double(level))
        return round(raw / 2) * 2  // Round to even number for pixel alignment
    }

    public static func lineHeight(base: CGFloat) -> CGFloat {
        return base * goldenRatio
    }

    // Preset levels
    public static let level0: CGFloat = baseSize        // 16pt
    public static let level1: CGFloat = size(level: 1)  // 20pt
    public static let level2: CGFloat = size(level: 2)  // 24pt
    public static let level3: CGFloat = size(level: 3)  // 28pt
    public static let level4: CGFloat = size(level: 4)  // 34pt
}

// MARK: - Chinese Font Manager
public struct ChineseFontManager {
    public static func appropriateFont(size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        let language = Locale.current.language.languageCode?.identifier

        if language == "zh-Hant" {
            // Traditional Chinese
            return Font.custom("PingFangTC", size: size).weight(weight)
        } else if language == "zh-Hans" {
            // Simplified Chinese
            return Font.custom("PingFangSC", size: size).weight(weight)
        }

        // Fallback to system font
        return Font.system(size: size, weight: weight, design: .serif)
    }

    public static func sutraTextFont(size: CGFloat = 16) -> Font {
        // Golden ratio-based font for sutra reading
        let fontSize = GoldenRatioTypography.baseSize
        let lineHeight = GoldenRatioTypography.lineHeight(base: fontSize)

        return appropriateFont(size: size, weight: .regular)
    }
}

// MARK: - Accessibility Semantic Categories
public enum AccessibilitySemanticCategory {
    case sutraText
    case commentaryText
    case navigation
    case button
    case link
    case heading
    case landmark
    case status
}

// MARK: - Enhanced Sutra Font Styles with Golden Ratio
extension SutraFontModifier {
    // New Golden Ratio-based styles
    public enum GoldenRatioStyle {
        case level0  // 16pt, 26pt line height
        case level1  // 20pt, 32pt line height
        case level2  // 24pt, 39pt line height
        case level3  // 28pt, 45pt line height
        case level4  // 34pt, 55pt line height

        var font: Font {
            switch self {
            case .level0: return ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0)
            case .level1: return ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1)
            case .level2: return ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level2)
            case .level3: return ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level3)
            case .level4: return ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level4)
            }
        }

        var lineHeight: CGFloat {
            switch self {
            case .level0: return GoldenRatioTypography.lineHeight(base: GoldenRatioTypography.level0)
            case .level1: return GoldenRatioTypography.lineHeight(base: GoldenRatioTypography.level1)
            case .level2: return GoldenRatioTypography.lineHeight(base: GoldenRatioTypography.level2)
            case .level3: return GoldenRatioTypography.lineHeight(base: GoldenRatioTypography.level3)
            case .level4: return GoldenRatioTypography.lineHeight(base: GoldenRatioTypography.level4)
            }
        }
    }
}

// MARK: - Spacing Modifiers
struct SutraSpacingModifier: ViewModifier {
    let value: CGFloat

    func body(content: Content) -> some View {
        content.padding(value)
    }
}

extension View {
    func sutraPadding(_ spacing: SutraSpacing) -> some View {
        self.modifier(SutraSpacingModifier(value: spacing.rawValue))
    }

    func sutraPadding(_ edges: Edge.Set = .all, _ spacing: SutraSpacing) -> some View {
        self.padding(edges, spacing.rawValue)
    }

    func sutraPadding(_ edges: Edge.Set = .all, _ value: CGFloat) -> some View {
        self.padding(edges, value)
    }
}

extension SutraSpacing {
    var rawValue: CGFloat {
        // Provide a default rawValue for backward compatibility
        return self.md
    }
}

// MARK: - Line Height Modifier
struct SutraLineHeightModifier: ViewModifier {
    let multiplier: CGFloat

    func body(content: Content) -> some View {
        content
            .lineSpacing(multiplier)
    }
}

extension View {
    func sutraLineHeight(_ multiplier: CGFloat) -> some View {
        self.modifier(SutraLineHeightModifier(multiplier: multiplier))
    }

    func sutraLineHeightGoldenRatio(_ level: Int) -> some View {
        let size = GoldenRatioTypography.size(level: level)
        let lineHeight = GoldenRatioTypography.lineHeight(base: size)
        return self.modifier(SutraLineHeightModifier(multiplier: lineHeight))
    }
}

// MARK: - Enhanced Accessibility Modifier
struct SutraEnhancedAccessibilityModifier: ViewModifier {
    let category: AccessibilitySemanticCategory
    let label: String
    let hint: String?
    let language: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) })
            .accessibilityAddTraits(accessibilityTraits)
            .accessibilityLanguage(language)
    }

    private var accessibilityTraits: AccessibilityTraits {
        switch category {
        case .sutraText:
            return .updatesFrequently
        case .commentaryText:
            return .staticText
        case .navigation:
            return .button
        case .button:
            return .button
        case .link:
            return .link
        case .heading:
            return .header
        case .landmark:
            return .button
        case .status:
            return [.staticText, .updatesFrequently]
        }
    }
}

extension View {
    func sutraAccessibility(
        category: AccessibilitySemanticCategory,
        label: String,
        hint: String? = nil,
        language: String? = "zh-CN"
    ) -> some View {
        self.modifier(
            SutraEnhancedAccessibilityModifier(
                category: category,
                label: label,
                hint: hint,
                language: language
            )
        )
    }
}

// MARK: - Animation Modifiers
extension View {
    func sutraTransition() -> some View {
        self.transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    func sutraSpringAnimation() -> some View {
        self.animation(.spring(response: 0.5, dampingFraction: 0.8), value: UUID())
    }

    func sutraEaseInOutAnimation() -> some View {
        self.animation(.easeInOut(duration: 0.3), value: UUID())
    }
}
