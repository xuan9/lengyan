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
            VStack(spacing: 0) {

                // MARK: 开篇 — 缘起
                Text(L10n.str("acknowledgments_intro"))
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(textSecondary)
                    .tracking(3)
                    .padding(.top, 48)
                    .padding(.bottom, 32)

                // MARK: 来源 — 逐一致敬
                sourceCard(
                    title: L10n.str("acknowledgments_text_title"),
                    text: L10n.str("acknowledgments_text_body")
                )

                goldDivider

                sourceCard(
                    title: L10n.str("acknowledgments_audio_title"),
                    text: L10n.str("acknowledgments_audio_body")
                )

                goldDivider

                sourceCard(
                    title: L10n.str("acknowledgments_image_title"),
                    text: L10n.str("acknowledgments_image_body")
                )

                goldDivider

                // MARK: 收束 — 致敬
                VStack(spacing: 12) {
                    Text(L10n.str("acknowledgments_footer"))
                        .font(SutraTypographyBridge.uiCaption(weight: .light))
                        .foregroundColor(textTertiary)
                        .tracking(4)

                    Text(L10n.str("footer_homage"))
                        .font(SutraTypographyBridge.uiCaption(weight: .medium))
                        .foregroundColor(goldColor.opacity(0.65))
                        .tracking(3)
                }
                .padding(.top, 40)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 28)
        }
        .background(Color(SutraDesignTokens.shared.color(for: .background)).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 来源卡片

    private func sourceCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SutraTypographyBridge.uiCaption(weight: .medium))
                .foregroundColor(textSecondary)
                .tracking(3)

            Text(text)
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(textPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    // MARK: - 金色分隔线

    private var goldDivider: some View {
        Rectangle()
            .fill(goldColor.opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 40)
    }
}
