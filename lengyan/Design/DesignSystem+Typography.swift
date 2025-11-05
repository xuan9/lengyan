//
//  DesignSystem+Typography.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Typography Scale
public struct SutraTypography {

    // MARK: - Font Families
    public struct FontFamily {
        // Primary Chinese fonts - optimized for readability
        public static let chineseTraditional = "PingFangTC"   // Traditional Chinese
        public static let chineseSimplified = "PingFangSC"    // Simplified Chinese
        public static let fallbackChinese = "Heiti SC"        // System fallback
        public static let sansSerif = "SFProDisplay"          // For UI elements
        public static let serif = "TimesNewRomanPSMT"         // For classical elements

        // Determine appropriate font based on system locale
        public static func appropriateChineseFont() -> String {
            for language in NSLocale.preferredLanguages {
                if language.hasPrefix("zh-Hant") {
                    return chineseTraditional
                } else if language.hasPrefix("zh-Hans") {
                    return chineseSimplified
                }
            }
            return chineseSimplified
        }
    }

    // MARK: - Font Weights
    public struct FontWeight {
        public static let ultralight: UIFont.Weight = .ultraLight
        public static let thin: UIFont.Weight = .thin
        public static let light: UIFont.Weight = .light
        public static let regular: UIFont.Weight = .regular
        public static let medium: UIFont.Weight = .medium
        public static let semibold: UIFont.Weight = .semibold
        public static let bold: UIFont.Weight = .bold
        public static let heavy: UIFont.Weight = .heavy
        public static let black: UIFont.Weight = .black
    }

    // MARK: - Type Scale (Golden Ratio based: 1.618)
    public struct Scale {
        // Base sizes for different screen categories
        private static let baseSize: CGFloat = 16.0  // Base body text size
        private static let goldenRatio: CGFloat = 1.618

        // Dynamic type sizes
        public static let xxxLarge = baseSize * pow(goldenRatio, 4)  // 16 * 6.85 = 109.6 → 34
        public static let xxLarge = baseSize * pow(goldenRatio, 3)   // 16 * 4.24 = 67.8 → 28
        public static let xLarge = baseSize * pow(goldenRatio, 2)    // 16 * 2.62 = 41.9 → 24
        public static let large = baseSize * goldenRatio              // 16 * 1.618 = 25.9 → 22
        public static let medium = baseSize                           // 16
        public static let small = baseSize / goldenRatio              // 16 / 1.618 = 9.9 → 14
        public static let xSmall = baseSize / pow(goldenRatio, 2)     // 16 / 2.62 = 6.1 → 12
        public static let xxSmall = baseSize / pow(goldenRatio, 3)    // 16 / 4.24 = 3.8 → 10

        // Rounded sizes for better rendering
        public static let xxxLargeRounded: CGFloat = 34
        public static let xxLargeRounded: CGFloat = 28
        public static let xLargeRounded: CGFloat = 24
        public static let largeRounded: CGFloat = 22
        public static let mediumRounded: CGFloat = 18
        public static let smallRounded: CGFloat = 16
        public static let xSmallRounded: CGFloat = 14
        public static let xxSmallRounded: CGFloat = 12
    }

    // MARK: - Line Height System
    public struct LineHeight {
        // Golden ratio line heights for optimal readability
        public static let tight: CGFloat = 1.2      // For headlines
        public static let normal: CGFloat = 1.4     // For body text
        public static let relaxed: CGFloat = 1.6    // For sutra text (traditional preference)
        public static let spacious: CGFloat = 1.8   // For commentary
        public static let sacred: CGFloat = 1.618   // Golden ratio for special text

        // Absolute line heights for consistency
        public static let sutraReading: CGFloat = 28     // For main sutra content
        public static let commentaryReading: CGFloat = 26 // For commentary text
        public static let navigation: CGFloat = 20        // For navigation elements
    }

    // MARK: - Letter Spacing
    public struct LetterSpacing {
        public static let tight: CGFloat = -0.5
        public static let normal: CGFloat = 0.0
        public static let relaxed: CGFloat = 0.5
        public static let spacious: CGFloat = 1.0

        // Chinese character spacing optimization
        public static let chineseNormal: CGFloat = 0.0
        public static let chineseRelaxed: CGFloat = 0.2
        public static let chineseSpacious: CGFloat = 0.4
    }

    // MARK: - Text Styles
    public struct TextStyle {
        // MARK: - Sutra Content Styles

        // Main sutra text - optimized for sacred reading
        public static let sutraLarge = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.largeRounded,
            weight: FontWeight.medium,
            lineHeight: LineHeight.sacred,
            letterSpacing: LetterSpacing.chineseRelaxed,
            tracking: 0
        )

        public static let sutraBody = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.mediumRounded,
            weight: FontWeight.regular,
            lineHeight: LineHeight.sacred,
            letterSpacing: LetterSpacing.chineseRelaxed,
            tracking: 0
        )

        public static let sutraSmall = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.smallRounded,
            weight: FontWeight.regular,
            lineHeight: LineHeight.relaxed,
            letterSpacing: LetterSpacing.chineseNormal,
            tracking: 0
        )

        // Commentary text
        public static let commentary = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.smallRounded,
            weight: FontWeight.light,
            lineHeight: LineHeight.spacious,
            letterSpacing: LetterSpacing.chineseNormal,
            tracking: 0
        )

        // Chapter titles
        public static let chapterTitle = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.xLargeRounded,
            weight: FontWeight.semibold,
            lineHeight: LineHeight.tight,
            letterSpacing: LetterSpacing.chineseSpacious,
            tracking: 0
        )

        // Section titles
        public static let sectionTitle = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.largeRounded,
            weight: FontWeight.semibold,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.chineseNormal,
            tracking: 0
        )

        // MARK: - UI Element Styles

        // Navigation
        public static let navigationTitle = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.largeRounded,
            weight: FontWeight.semibold,
            lineHeight: LineHeight.tight,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        public static let navigationButton = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.mediumRounded,
            weight: FontWeight.medium,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        // Buttons
        public static let buttonLarge = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.mediumRounded,
            weight: FontWeight.semibold,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        public static let buttonMedium = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.smallRounded,
            weight: FontWeight.medium,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        // Labels and metadata
        public static let label = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.xSmallRounded,
            weight: FontWeight.medium,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        public static let caption = SutraTextStyle(
            font: FontFamily.sansSerif,
            size: Scale.xxSmallRounded,
            weight: FontWeight.regular,
            lineHeight: LineHeight.normal,
            letterSpacing: LetterSpacing.normal,
            tracking: 0
        )

        // Index and table of contents
        public static let indexItem = SutraTextStyle(
            font: FontFamily.appropriateChineseFont(),
            size: Scale.smallRounded,
            weight: FontWeight.light,
            lineHeight: LineHeight.relaxed,
            letterSpacing: LetterSpacing.chineseNormal,
            tracking: 0
        )

        
    }

    // MARK: - Dynamic Type Support
    public struct DynamicType {
        public static func preferredFont(for style: SutraTextStyle,
                                       compatibleWith traitCollection: UITraitCollection) -> UIFont {
            let metrics = UIFontMetrics(forTextStyle: .body)
            let baseFont = UIFont(name: style.font, size: style.size) ??
                          UIFont.systemFont(ofSize: style.size, weight: style.weight)

            return metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)
        }

        public static func adjustForContentSizeCategory(_ style: SutraTextStyle,
                                                       category: UIContentSizeCategory) -> SutraTextStyle {
            var adjustedStyle = style

            // Adjust sizes based on content size category
            switch category {
            case .extraSmall:
                adjustedStyle.size *= 0.8
            case .small:
                adjustedStyle.size *= 0.9
            case .medium:
                adjustedStyle.size *= 1.0
            case .large:
                adjustedStyle.size *= 1.1
            case .extraLarge:
                adjustedStyle.size *= 1.2
            case .extraExtraLarge:
                adjustedStyle.size *= 1.3
            case .extraExtraExtraLarge:
                adjustedStyle.size *= 1.4
            case .accessibilityMedium:
                adjustedStyle.size *= 1.6
            case .accessibilityLarge:
                adjustedStyle.size *= 1.8
            case .accessibilityExtraLarge:
                adjustedStyle.size *= 2.0
            case .accessibilityExtraExtraLarge:
                adjustedStyle.size *= 2.2
            case .accessibilityExtraExtraExtraLarge:
                adjustedStyle.size *= 2.4
            case .unspecified:
                break
            default:
                break
            }

            return adjustedStyle
        }
    }

    // MARK: - Text Attributes Builder
    public static func attributes(for style: SutraTextStyle,
                                 color: UIColor = .label,
                                 theme: SutraTheme = .light) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = style.lineHeight
        paragraphStyle.lineSpacing = style.lineHeight * style.size - style.size

        // Add first line indent for sutra text (traditional Chinese formatting)
        if style == TextStyle.sutraLarge || style == TextStyle.sutraBody {
            paragraphStyle.firstLineHeadIndent = style.size * 2
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: style.font, size: style.size) ??
                  UIFont.systemFont(ofSize: style.size, weight: style.weight),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: color
        ]

        // Add letter spacing if specified
        if style.letterSpacing != 0 {
            attributes[.kern] = style.letterSpacing
        }

        return attributes
    }

    // MARK: - Chinese Text Optimization
    public struct ChineseOptimization {
        // Optimize line breaking for Chinese characters
        public static func optimizedParagraphStyle(for style: SutraTextStyle) -> NSParagraphStyle {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = style.lineHeight

            // Chinese-specific line breaking rules
            paragraphStyle.lineBreakMode = .byWordWrapping

            // Enable hyphenation (not typically used for Chinese, but available)
            paragraphStyle.hyphenationFactor = 0.0

            // Set appropriate alignment
            paragraphStyle.alignment = .left

            return paragraphStyle
        }

        // Check if text contains Chinese characters
        public static func containsChineseCharacters(_ text: String) -> Bool {
            return text.range(of: "\\p{Han}", options: .regularExpression) != nil
        }

        // Get appropriate font for mixed Chinese/English text
        public static func fontForMixedText(chineseStyle: SutraTextStyle,
                                          englishStyle: SutraTextStyle) -> (UIFont, UIFont) {
            let chineseFont = UIFont(name: chineseStyle.font, size: chineseStyle.size) ??
                             UIFont.systemFont(ofSize: chineseStyle.size, weight: chineseStyle.weight)

            let englishFont = UIFont(name: englishStyle.font, size: englishStyle.size) ??
                             UIFont.systemFont(ofSize: englishStyle.size, weight: englishStyle.weight)

            return (chineseFont, englishFont)
        }
    }
}

// MARK: - Text Style Model
public struct SutraTextStyle: Equatable {
    public let font: String
    public var size: CGFloat
    public let weight: UIFont.Weight
    public let lineHeight: CGFloat
    public let letterSpacing: CGFloat
    public let tracking: CGFloat

    public init(font: String, size: CGFloat, weight: UIFont.Weight,
                lineHeight: CGFloat, letterSpacing: CGFloat, tracking: CGFloat) {
        self.font = font
        self.size = size
        self.weight = weight
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.tracking = tracking
    }
}

// MARK: - Typography Extensions
extension UIFont {
    public static func sutraFont(style: SutraTextStyle,
                                compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let baseFont = UIFont(name: style.font, size: style.size) ??
                      UIFont.systemFont(ofSize: style.size, weight: style.weight)

        if let traitCollection = traitCollection {
            let metrics = UIFontMetrics(forTextStyle: .body)
            return metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)
        }

        return baseFont
    }
}

extension NSAttributedString {
    public static func sutraAttributedText(text: String,
                                          style: SutraTextStyle,
                                          color: UIColor = .label) -> NSAttributedString {
        let attributes = SutraTypography.attributes(for: style, color: color)
        return NSAttributedString(string: text, attributes: attributes)
    }

    public static func mixedChineseEnglishAttributedText(
        chineseText: String,
        englishText: String,
        chineseStyle: SutraTextStyle,
        englishStyle: SutraTextStyle,
        color: UIColor = .label
    ) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        // Chinese text
        let chineseAttributes = SutraTypography.attributes(for: chineseStyle, color: color)
        attributedString.append(NSAttributedString(string: chineseText, attributes: chineseAttributes))

        // English text
        let englishAttributes = SutraTypography.attributes(for: englishStyle, color: color)
        attributedString.append(NSAttributedString(string: englishText, attributes: englishAttributes))

        return attributedString
    }
}