//
//  DesignSystem+Tokens.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Design Tokens Manager
public class SutraDesignTokens {

    // MARK: - Shared Instance
    public static let shared = SutraDesignTokens()
    private init() {}

    // MARK: - Current Theme
    public var currentTheme: SutraTheme = .light {
        didSet {
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
        }
    }

    // MARK: - Token Categories
    public struct ColorTokens {
        // Semantic color tokens
        public static let backgroundPrimary = "background.primary"
        public static let backgroundSecondary = "background.secondary"
        public static let backgroundSurface = "background.surface"
        public static let backgroundOverlay = "background.overlay"

        public static let textPrimary = "text.primary"
        public static let textSecondary = "text.secondary"
        public static let textTertiary = "text.tertiary"
        public static let textOnAccent = "text.on.accent"

        public static let sutraText = "sutra.text.primary"
        public static let sutraCommentary = "sutra.text.commentary"
        public static let sutraChapterTitle = "sutra.text.chapter"

        public static let accentPrimary = "accent.primary"
        public static let accentSecondary = "accent.secondary"

        public static let borderDefault = "border.default"
        public static let borderSubtle = "border.subtle"

        public static let shadowDefault = "shadow.default"

        public static let bookmarkActive = "bookmark.active"
        public static let bookmarkInactive = "bookmark.inactive"

        public static let favoriteActive = "favorite.active"
        public static let favoriteInactive = "favorite.inactive"
    }

    public struct TypographyTokens {
        // Font family tokens
        public static let chinesePrimary = "font.chinese.primary"
        public static let chineseSecondary = "font.chinese.secondary"
        public static let latinPrimary = "font.latin.primary"
        public static let latinSecondary = "font.latin.secondary"

        // Font size tokens
        public static let sizeXXXLarge = "font.size.xxxlarge"
        public static let sizeXXLarge = "font.size.xxlarge"
        public static let sizeXLarge = "font.size.xlarge"
        public static let sizeLarge = "font.size.large"
        public static let sizeMedium = "font.size.medium"
        public static let sizeSmall = "font.size.small"
        public static let sizeXSmall = "font.size.xsmall"
        public static let sizeXXSmall = "font.size.xxsmall"

        // Font weight tokens
        public static let weightUltraLight = "font.weight.ultralight"
        public static let weightThin = "font.weight.thin"
        public static let weightLight = "font.weight.light"
        public static let weightRegular = "font.weight.regular"
        public static let weightMedium = "font.weight.medium"
        public static let weightSemibold = "font.weight.semibold"
        public static let weightBold = "font.weight.bold"

        // Line height tokens
        public static let lineHeightTight = "lineHeight.tight"
        public static let lineHeightNormal = "lineHeight.normal"
        public static let lineHeightRelaxed = "lineHeight.relaxed"
        public static let lineHeightSpacious = "lineHeight.spacious"
        public static let lineHeightSacred = "lineHeight.sacred"

        // Letter spacing tokens
        public static let letterSpacingTight = "letterSpacing.tight"
        public static let letterSpacingNormal = "letterSpacing.normal"
        public static let letterSpacingRelaxed = "letterSpacing.relaxed"
    }

    public struct SpacingTokens {
        // Micro spacing tokens
        public static let spacingXXXS = "spacing.xxxs"
        public static let spacingXXS = "spacing.xxs"
        public static let spacingXS = "spacing.xs"
        public static let spacingSM = "spacing.sm"

        // Base spacing tokens
        public static let spacingBase = "spacing.base"
        public static let spacingMD = "spacing.md"
        public static let spacingLG = "spacing.lg"
        public static let spacingXL = "spacing.xl"

        // Component spacing tokens
        public static let spacingComponentSM = "spacing.component.sm"
        public static let spacingComponentMD = "spacing.component.md"
        public static let spacingComponentLG = "spacing.component.lg"
        public static let spacingComponentXL = "spacing.component.xl"
        public static let spacingComponentXXL = "spacing.component.xxl"

        // Section spacing tokens
        public static let spacingSectionSM = "spacing.section.sm"
        public static let spacingSectionMD = "spacing.section.md"
        public static let spacingSectionLG = "spacing.section.lg"
        public static let spacingSectionXL = "spacing.section.xl"
        public static let spacingSectionXXL = "spacing.section.xxl"

        // Content spacing tokens
        public static let spacingSutraLine = "spacing.sutra.line"
        public static let spacingSutraParagraph = "spacing.sutra.paragraph"
        public static let spacingSutraChapter = "spacing.sutra.chapter"
        public static let spacingCommentaryLine = "spacing.commentary.line"
    }

    public struct ShapeTokens {
        // Corner radius tokens
        public static let cornerRadiusXSmall = "cornerRadius.xsmall"
        public static let cornerRadiusSmall = "cornerRadius.small"
        public static let cornerRadiusMedium = "cornerRadius.medium"
        public static let cornerRadiusLarge = "cornerRadius.large"
        public static let cornerRadiusXLarge = "cornerRadius.xlarge"
        public static let cornerRadiusRound = "cornerRadius.round"

        // Border width tokens
        public static let borderWidthThin = "borderWidth.thin"
        public static let borderWidthMedium = "borderWidth.medium"
        public static let borderWidthThick = "borderWidth.thick"
    }

    public struct MotionTokens {
        // Duration tokens
        public static let durationInstant = "motion.duration.instant"
        public static let durationFast = "motion.duration.fast"
        public static let durationNormal = "motion.duration.normal"
        public static let durationSlow = "motion.duration.slow"
        public static let durationSlower = "motion.duration.slower"

        // Easing tokens
        public static let easingEase = "motion.easing.ease"
        public static let easingEaseIn = "motion.easing.easeIn"
        public static let easingEaseOut = "motion.easing.easeOut"
        public static let easingEaseInOut = "motion.easing.easeInOut"
        public static let easingSpring = "motion.easing.spring"

        // Delay tokens
        public static let delayNone = "motion.delay.none"
        public static let delayShort = "motion.delay.short"
        public static let delayMedium = "motion.delay.medium"
        public static let delayLong = "motion.delay.long"
    }

    public struct ShadowTokens {
        public static let shadowSubtle = "shadow.subtle"
        public static let shadowMedium = "shadow.medium"
        public static let shadowStrong = "shadow.strong"
        public static let shadowGlow = "shadow.glow"
    }

    public struct OpacityTokens {
        public static let opacityTransparent = "opacity.transparent"
        public static let opacitySubtle = "opacity.subtle"
        public static let opacityLight = "opacity.light"
        public static let opacityMedium = "opacity.medium"
        public static let opacityStrong = "opacity.strong"
        public static let opacityOpaque = "opacity.opaque"
    }

    // MARK: - Token Resolution
    public func color(for token: String, theme: SutraTheme? = nil) -> UIColor {
        let activeTheme = theme ?? currentTheme

        // Color token resolution logic
        switch token {
        // Background colors
        case ColorTokens.backgroundPrimary:
            return SutraColors.Semantic.background(theme: activeTheme)
        case ColorTokens.backgroundSecondary:
            return SutraColors.Semantic.surface(theme: activeTheme)
        case ColorTokens.backgroundSurface:
            return SutraColors.Semantic.card(theme: activeTheme)
        case ColorTokens.backgroundOverlay:
            return activeTheme == .dark ? UIColor.black.withAlphaComponent(0.7) : UIColor.black.withAlphaComponent(0.4)

        // Text colors
        case ColorTokens.textPrimary:
            return SutraColors.Semantic.primary(theme: activeTheme)
        case ColorTokens.textSecondary:
            return activeTheme == .dark ? SutraColors.Dark.textSecondary : SutraColors.Light.textSecondary
        case ColorTokens.textTertiary:
            return activeTheme == .dark ? SutraColors.Dark.textTertiary : SutraColors.Light.textTertiary
        case ColorTokens.textOnAccent:
            return UIColor.white

        // Sutra-specific colors
        case ColorTokens.sutraText:
            return SutraColors.Semantic.sutraText(theme: activeTheme)
        case ColorTokens.sutraCommentary:
            return SutraColors.Semantic.commentaryText(theme: activeTheme)
        case ColorTokens.sutraChapterTitle:
            return SutraColors.Semantic.chapterTitle(theme: activeTheme)

        // Accent colors
        case ColorTokens.accentPrimary:
            return SutraColors.Semantic.accent(theme: activeTheme)
        case ColorTokens.accentSecondary:
            return activeTheme == .dark ? SutraColors.Dark.primaryLight : SutraColors.Light.primaryLight

        // Border colors
        case ColorTokens.borderDefault:
            return SutraColors.Semantic.divider(theme: activeTheme)
        case ColorTokens.borderSubtle:
            return activeTheme == .dark ? SutraColors.Dark.border : SutraColors.Light.border

        // Status colors
        case ColorTokens.bookmarkActive:
            return activeTheme == .dark ? SutraColors.Dark.bookmark : SutraColors.Light.bookmark
        case ColorTokens.bookmarkInactive:
            return SutraColors.Semantic.primary(theme: activeTheme)
        case ColorTokens.favoriteActive:
            return activeTheme == .dark ? SutraColors.Dark.favorite : SutraColors.Light.favorite
        case ColorTokens.favoriteInactive:
            return SutraColors.Semantic.primary(theme: activeTheme)

        default:
            return UIColor.systemGray
        }
    }

    public func typography(for token: String) -> SutraTextStyle {
        switch token {
        // Font families
        case TypographyTokens.chinesePrimary:
            return SutraTextStyle(
                font: SutraTypography.FontFamily.appropriateChineseFont(),
                size: SutraTypography.Scale.mediumRounded,
                weight: .regular,
                lineHeight: SutraTypography.LineHeight.normal,
                letterSpacing: 0,
                tracking: 0
            )

        // Sizes
        case TypographyTokens.sizeXXXLarge:
            return SutraTypography.TextStyle.sutraLarge
        case TypographyTokens.sizeXXLarge:
            return SutraTypography.TextStyle.sutraLarge
        case TypographyTokens.sizeXLarge:
            return SutraTypography.TextStyle.sutraLarge
        case TypographyTokens.sizeLarge:
            return SutraTypography.TextStyle.sutraLarge
        case TypographyTokens.sizeMedium:
            return SutraTypography.TextStyle.sutraBody
        case TypographyTokens.sizeSmall:
            return SutraTypography.TextStyle.sutraSmall
        case TypographyTokens.sizeXSmall:
            return SutraTypography.TextStyle.sutraSmall
        case TypographyTokens.sizeXXSmall:
            return SutraTypography.TextStyle.caption

        default:
            return SutraTypography.TextStyle.sutraBody
        }
    }

    public func spacing(for token: String) -> CGFloat {
        switch token {
        // Micro spacing
        case SpacingTokens.spacingXXXS: return SutraSpacing.Micro.xxxs
        case SpacingTokens.spacingXXS: return SutraSpacing.Micro.xxs
        case SpacingTokens.spacingXS: return SutraSpacing.Micro.xs
        case SpacingTokens.spacingSM: return SutraSpacing.Micro.sm

        // Base spacing
        case SpacingTokens.spacingBase: return SutraSpacing.Base.base
        case SpacingTokens.spacingMD: return SutraSpacing.Base.md
        case SpacingTokens.spacingLG: return SutraSpacing.Base.lg
        case SpacingTokens.spacingXL: return SutraSpacing.Base.xl

        // Component spacing
        case SpacingTokens.spacingComponentSM: return SutraSpacing.Component.sm
        case SpacingTokens.spacingComponentMD: return SutraSpacing.Component.md
        case SpacingTokens.spacingComponentLG: return SutraSpacing.Component.lg
        case SpacingTokens.spacingComponentXL: return SutraSpacing.Component.xl
        case SpacingTokens.spacingComponentXXL: return SutraSpacing.Component.xxl

        // Section spacing
        case SpacingTokens.spacingSectionSM: return SutraSpacing.Section.sm
        case SpacingTokens.spacingSectionMD: return SutraSpacing.Section.md
        case SpacingTokens.spacingSectionLG: return SutraSpacing.Section.lg
        case SpacingTokens.spacingSectionXL: return SutraSpacing.Section.xl
        case SpacingTokens.spacingSectionXXL: return SutraSpacing.Section.xxl

        // Content spacing
        case SpacingTokens.spacingSutraLine: return SutraSpacing.Content.sutraLineSpacing
        case SpacingTokens.spacingSutraParagraph: return SutraSpacing.Content.sutraParagraphSpacing
        case SpacingTokens.spacingSutraChapter: return SutraSpacing.Content.sutraChapterSpacing
        case SpacingTokens.spacingCommentaryLine: return SutraSpacing.Content.commentaryLineSpacing

        default: return SutraSpacing.Base.md
        }
    }

    public func shape(for token: String) -> CGFloat {
        switch token {
        case ShapeTokens.cornerRadiusXSmall: return SutraCornerRadius.xSmall
        case ShapeTokens.cornerRadiusSmall: return SutraCornerRadius.small
        case ShapeTokens.cornerRadiusMedium: return SutraCornerRadius.medium
        case ShapeTokens.cornerRadiusLarge: return SutraCornerRadius.large
        case ShapeTokens.cornerRadiusXLarge: return SutraCornerRadius.xLarge
        case ShapeTokens.cornerRadiusRound: return SutraCornerRadius.round
        default: return SutraCornerRadius.medium
        }
    }

    public func motionDuration(for token: String) -> TimeInterval {
        switch token {
        case MotionTokens.durationInstant: return 0.0
        case MotionTokens.durationFast: return 0.2
        case MotionTokens.durationNormal: return 0.3
        case MotionTokens.durationSlow: return 0.5
        case MotionTokens.durationSlower: return 0.8
        default: return 0.3
        }
    }

    public func opacity(for token: String) -> CGFloat {
        switch token {
        case OpacityTokens.opacityTransparent: return 0.0
        case OpacityTokens.opacitySubtle: return 0.1
        case OpacityTokens.opacityLight: return 0.3
        case OpacityTokens.opacityMedium: return 0.5
        case OpacityTokens.opacityStrong: return 0.7
        case OpacityTokens.opacityOpaque: return 1.0
        default: return 1.0
        }
    }
}

// MARK: - Theme Change Notification
extension Notification.Name {
    public static let themeDidChange = Notification.Name("themeDidChange")
}

// MARK: - Token Extensions
extension UIView {
    public func applyToken(backgroundColor token: String, theme: SutraTheme? = nil) {
        self.backgroundColor = SutraDesignTokens.shared.color(for: token, theme: theme)
    }

    public func applyToken(cornerRadius token: String) {
        self.layer.cornerRadius = SutraDesignTokens.shared.shape(for: token)
    }

    public func applyToken(opacity token: String) {
        self.alpha = SutraDesignTokens.shared.opacity(for: token)
    }
}

extension UILabel {
    public func applyToken(textStyle token: String, color: String? = nil, theme: SutraTheme? = nil) {
        let style = SutraDesignTokens.shared.typography(for: token)
        self.font = UIFont.sutraFont(style: style)

        if let colorToken = color {
            self.textColor = SutraDesignTokens.shared.color(for: colorToken, theme: theme)
        }
    }
}

extension CALayer {
    public func applyToken(shadow token: String) {
        switch token {
        case SutraDesignTokens.ShadowTokens.shadowSubtle:
            self.shadowColor = UIColor.black.cgColor
            self.shadowOffset = CGSize(width: 0, height: 2)
            self.shadowRadius = 4
            self.shadowOpacity = 0.08
        case SutraDesignTokens.ShadowTokens.shadowMedium:
            self.shadowColor = UIColor.black.cgColor
            self.shadowOffset = CGSize(width: 0, height: 4)
            self.shadowRadius = 8
            self.shadowOpacity = 0.12
        case SutraDesignTokens.ShadowTokens.shadowStrong:
            self.shadowColor = UIColor.black.cgColor
            self.shadowOffset = CGSize(width: 0, height: 8)
            self.shadowRadius = 16
            self.shadowOpacity = 0.2
        case SutraDesignTokens.ShadowTokens.shadowGlow:
            self.shadowColor = SutraDesignTokens.shared.color(for: SutraDesignTokens.ColorTokens.accentPrimary).cgColor
            self.shadowOffset = CGSize.zero
            self.shadowRadius = 12
            self.shadowOpacity = 0.3
        default:
            break
        }
    }
}

// MARK: - Animation Builder with Tokens
public class SutraAnimationBuilder {
    public static func animateWithTokens(duration token: String,
                                       delay delayToken: String = SutraDesignTokens.MotionTokens.delayNone,
                                       easing: String = SutraDesignTokens.MotionTokens.easingEaseInOut,
                                       animations: @escaping () -> Void,
                                       completion: ((Bool) -> Void)? = nil) {
        let duration = SutraDesignTokens.shared.motionDuration(for: token)
        let delay = SutraDesignTokens.shared.motionDuration(for: delayToken)

        let options: UIView.AnimationOptions = {
            switch easing {
            case SutraDesignTokens.MotionTokens.easingEase:
                return .curveEaseInOut
            case SutraDesignTokens.MotionTokens.easingEaseIn:
                return .curveEaseIn
            case SutraDesignTokens.MotionTokens.easingEaseOut:
                return .curveEaseOut
            case SutraDesignTokens.MotionTokens.easingEaseInOut:
                return .curveEaseInOut
            case SutraDesignTokens.MotionTokens.easingSpring:
                return .curveEaseInOut // Will use spring animation below
            default:
                return .curveEaseInOut
            }
        }()

        if easing == SutraDesignTokens.MotionTokens.easingSpring {
            UIView.animate(withDuration: duration,
                          delay: delay,
                          usingSpringWithDamping: 0.8,
                          initialSpringVelocity: 0.5,
                          options: options,
                          animations: animations,
                          completion: completion)
        } else {
            UIView.animate(withDuration: duration,
                          delay: delay,
                          options: options,
                          animations: animations,
                          completion: completion)
        }
    }
}