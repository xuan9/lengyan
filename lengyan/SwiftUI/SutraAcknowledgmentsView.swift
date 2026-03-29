import SwiftUI

struct SutraAcknowledgmentsView: View {
    @Environment(\.presentationMode) var presentationMode

    private var goldColor: Color {
        Color(SutraDesignTokens.shared.color(for: .decorativeGold))
    }

    private var textPrimary: Color {
        Color(SutraDesignTokens.shared.color(for: .textPrimary))
    }

    private var textSecondary: Color {
        Color(SutraDesignTokens.shared.color(for: .textSecondary))
    }

    private var textTertiary: Color {
        Color(SutraDesignTokens.shared.color(for: .textTertiary))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SutraSpacing.Base.xxl) {
                // 顶端留白
                Spacer(minLength: SutraSpacing.Base.xl)

                VStack(alignment: .leading, spacing: SutraSpacing.Base.xl) {
                    // 文字来源
                    sourceSection(
                        icon: "doc.text.fill",
                        title: "文字来源",
                        text: "经文和科判来自法界佛教总会网站《大佛顶首楞严经浅释》。感恩法界佛教总会编辑整理！其经文援用《龙藏》及交光法师之《大佛顶首楞严经正脉疏》等，并以圆锳法师简要科判为主。"
                    )

                    // 音频来源
                    sourceSection(
                        icon: "waveform.circle.fill",
                        title: "音频来源",
                        text: "音频内容来源于佛学多媒体资料库，感恩屏东能净协会读诵录制。"
                    )

                    // 图片来源
                    sourceSection(
                        icon: "photo.circle.fill",
                        title: "图片来源",
                        text: "程序图标和启动画面来自明代画家吳彬画作"
                    )
                }
                .padding(.horizontal, SutraSpacing.Base.xl)

                Divider()
                    .background(goldColor.opacity(0.3))
                    .padding(.vertical, SutraSpacing.Base.xs)

                // 感恩
                VStack(alignment: .leading, spacing: SutraSpacing.Base.sm) {
                    Text("感恩上述来源，随喜功德！")
                        .font(SutraTypographyBridge.sutraCaption(weight: .light))
                        .foregroundColor(textTertiary)
                }

                VStack(alignment: .leading, spacing: SutraSpacing.Touch.spacing) {
                    Image(systemName: "hands.press.fill")
                        .font(SutraTypographyBridge.uiLargeTitle(weight: .regular))
                        .foregroundColor(goldColor)

                    Text("南无楞严会上佛菩萨！")
                        .font(SutraTypographyBridge.sutraCaption(weight: .light))
                        .foregroundColor(textTertiary)
                        .lineSpacing(SutraSpacing.Base.sm)
                }
                .padding(.horizontal, SutraSpacing.Base.xl)

                Spacer(minLength: SutraSpacing.Base.xxl)

                Text("✧ ❀ ✧")
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(goldColor.opacity(0.6))
            }
        }
        .background(Color(SutraDesignTokens.shared.color(for: .background)).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceSection(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: SutraSpacing.Touch.spacing) {
            HStack(spacing: SutraSpacing.Base.sm) {
                Image(systemName: icon)
                    .font(SutraTypographyBridge.uiBody(weight: .medium))
                    .foregroundColor(goldColor)

                Text(title)
                    .font(Font(SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)))
                    .foregroundColor(textSecondary)
            }

            Text(text)
                .font(Font(SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)))
                .foregroundColor(textPrimary)
                .lineSpacing(SutraSpacing.Base.sm + 2)
        }
    }
}
