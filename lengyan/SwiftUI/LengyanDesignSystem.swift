//
//  LengyanDesignSystem.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import SwiftUI

// MARK: - Design System
struct LengyanDesignSystem {

    // MARK: - Colors
    struct Colors {
        // Primary Colors
        static let primaryText = Color(red: 0.2, green: 0.2, blue: 0.2)
        static let secondaryText = Color(red: 0.5, green: 0.5, blue: 0.5)
        static let tertiaryText = Color(red: 0.7, green: 0.7, blue: 0.7)

        // Background Colors
        static let backgroundWarm = Color(red: 0.98, green: 0.96, blue: 0.92)
        static let backgroundCard = Color.white
        static let backgroundOverlay = Color.black.opacity(0.05)

        // Accent Colors
        static let accentGold = Color(red: 0.85, green: 0.75, blue: 0.6)
        static let accentBlue = Color(red: 0.2, green: 0.6, blue: 0.8)
        static let accentGreen = Color(red: 0.3, green: 0.7, blue: 0.5)

        // Status Colors
        static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
        static let warning = Color(red: 0.9, green: 0.6, blue: 0.2)
        static let error = Color(red: 0.8, green: 0.2, blue: 0.2)

        // Material Colors
        static let ultraThinMaterialBackground = Color(UIColor.systemBackground)
        static let thinMaterialBackground = Color(UIColor.secondarySystemBackground)
    }

    // MARK: - Typography
    struct Typography {
        // Sutra Fonts (Reading content)
        static let sutraLarge = Font.custom("Source Han Serif TC", size: 24)
        static let sutraTitle = Font.custom("Source Han Serif TC", size: 20)
        static let sutraBody = Font.custom("Source Han Serif TC", size: 18)
        static let sutraCaption = Font.custom("Source Han Serif TC", size: 14)

        // UI Fonts (Interface elements)
        static let uiLargeTitle = Font.custom("Source Han Sans TC", size: 34)
        static let uiTitle = Font.custom("Source Han Sans TC", size: 28)
        static let uiHeading = Font.custom("Source Han Sans TC", size: 20)
        static let uiBody = Font.custom("Source Han Sans TC", size: 16)
        static let uiCaption = Font.custom("Source Han Sans TC", size: 14)
        static let uiSmall = Font.custom("Source Han Sans TC", size: 12)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Shadow
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let small = Shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        static let accent = Shadow(color: LengyanDesignSystem.Colors.accentGold.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Theme Support
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .light

    enum AppTheme {
        case light
        case dark
        case sepia
    }

    var backgroundColor: Color {
        switch currentTheme {
        case .light:
            return LengyanDesignSystem.Colors.backgroundWarm
        case .dark:
            return Color(red: 0.1, green: 0.1, blue: 0.08)
        case .sepia:
            return Color(red: 0.96, green: 0.92, blue: 0.84)
        }
    }

    var cardColor: Color {
        switch currentTheme {
        case .light:
            return LengyanDesignSystem.Colors.backgroundCard
        case .dark:
            return Color(red: 0.15, green: 0.15, blue: 0.12)
        case .sepia:
            return Color(red: 0.92, green: 0.88, blue: 0.80)
        }
    }

    var primaryTextColor: Color {
        switch currentTheme {
        case .light:
            return LengyanDesignSystem.Colors.primaryText
        case .dark:
            return Color.white
        case .sepia:
            return Color(red: 0.2, green: 0.15, blue: 0.1)
        }
    }

    var secondaryTextColor: Color {
        switch currentTheme {
        case .light:
            return LengyanDesignSystem.Colors.secondaryText
        case .dark:
            return Color.gray
        case .sepia:
            return Color(red: 0.4, green: 0.35, blue: 0.3)
        }
    }

    var tertiaryTextColor: Color {
        switch currentTheme {
        case .light:
            return LengyanDesignSystem.Colors.tertiaryText
        case .dark:
            return Color.gray.opacity(0.7)
        case .sepia:
            return Color(red: 0.5, green: 0.45, blue: 0.4)
        }
    }
}

// MARK: - Custom Modifiers
extension View {
    func lengyanCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: LengyanDesignSystem.CornerRadius.medium)
                    .fill(ThemeManager().cardColor)
                    .shadow(
                        color: LengyanDesignSystem.Shadow.medium.color,
                        radius: LengyanDesignSystem.Shadow.medium.radius,
                        x: LengyanDesignSystem.Shadow.medium.x,
                        y: LengyanDesignSystem.Shadow.medium.y
                    )
            )
    }

    func lengyanMaterialCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: LengyanDesignSystem.CornerRadius.medium)
                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                    .shadow(
                        color: LengyanDesignSystem.Shadow.small.color,
                        radius: LengyanDesignSystem.Shadow.small.radius,
                        x: LengyanDesignSystem.Shadow.small.x,
                        y: LengyanDesignSystem.Shadow.small.y
                    )
            )
    }

    func lengyanAccentButton() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, LengyanDesignSystem.Spacing.lg)
            .padding(.vertical, LengyanDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: LengyanDesignSystem.CornerRadius.xl)
                    .fill(LengyanDesignSystem.Colors.accentGold)
                    .shadow(color: LengyanDesignSystem.Shadow.accent.color, radius: LengyanDesignSystem.Shadow.accent.radius, x: LengyanDesignSystem.Shadow.accent.x, y: LengyanDesignSystem.Shadow.accent.y)
            )
    }

    func lengyanSecondaryButton() -> some View {
        self
            .foregroundColor(LengyanDesignSystem.Colors.accentGold)
            .padding(.horizontal, LengyanDesignSystem.Spacing.lg)
            .padding(.vertical, LengyanDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: LengyanDesignSystem.CornerRadius.xl)
                    .foregroundColor(LengyanDesignSystem.Colors.accentGold.opacity(0.1))
            )
    }
}

// MARK: - Custom Components
struct LengyanSutraText: View {
    let text: String
    let size: Font
    let lineHeight: CGFloat

    init(_ text: String, size: Font = LengyanDesignSystem.Typography.sutraBody, lineHeight: CGFloat = 1.6) {
        self.text = text
        self.size = size
        self.lineHeight = lineHeight
    }

    var body: some View {
        Text(text)
            .font(size)
            .lineSpacing(CGFloat(Int(lineHeight * 20) - 20))
            .foregroundColor(ThemeManager().primaryTextColor)
    }
}

struct LengyanSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LengyanDesignSystem.Spacing.sm) {
            Text(title)
                .font(LengyanDesignSystem.Typography.uiTitle)
                .foregroundColor(ThemeManager().primaryTextColor)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(ThemeManager().secondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LengyanLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: LengyanDesignSystem.Spacing.md) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LengyanDesignSystem.Colors.accentGold,
                    lineWidth: 3
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)

            Text("加载中...")
                .font(LengyanDesignSystem.Typography.uiCaption)
                .foregroundColor(ThemeManager().secondaryTextColor)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
struct LengyanDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                LengyanSectionHeader("楞严经", subtitle: "The Śūraṅgama Sūtra")

                LengyanSutraText("如是我聞。一時，佛在室羅筏城，祇桓精舍。")

                HStack {
                    Button("主要按钮") {}
                        .lengyanAccentButton()

                    Button("次要按钮") {}
                        .lengyanSecondaryButton()
                }

                LengyanLoadingView()
            }
            .padding()
            .background(ThemeManager().backgroundColor)
            .previewDisplayName("Light Theme")

            VStack(spacing: 20) {
                LengyanSectionHeader("楞严经", subtitle: "The Śūraṅgama Sūtra")

                LengyanSutraText("如是我聞。一時，佛在室羅筏城，祇桓精舍。")

                HStack {
                    Button("主要按钮") {}
                        .lengyanAccentButton()

                    Button("次要按钮") {}
                        .lengyanSecondaryButton()
                }

                LengyanLoadingView()
            }
            .padding()
            .background(Color.black)
            .previewDisplayName("Dark Theme")
            .preferredColorScheme(.dark)
        }
    }
}