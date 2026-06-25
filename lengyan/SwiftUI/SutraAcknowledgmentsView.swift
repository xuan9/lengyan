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
                Text("经典流传 仰仗诸缘")
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(textSecondary)
                    .tracking(3)
                    .padding(.top, 48)
                    .padding(.bottom, 32)

                // MARK: 来源 — 逐一致敬
                sourceCard(
                    title: "文字",
                    text: "《大佛顶首楞严经》源自佛陀于舍卫国祇园精舍宣说，又名《中印度那烂陀大道场经》。相传龙树菩萨自龙宫默记传出。天台智者大师为求此经，面向西方礼拜十八年而未得见。后般剌蜜谛法师割臂藏经，历尽艰险带至广州，于唐神龙元年（705）在制旨道场（今光孝寺）译出。般剌蜜谛法师任译主，弥伽释迦法师译语，怀迪法师证译，房融笔受。译毕，法师即回国承当罪责。\n\n此后历经千年，无数大德传持、注释、流通。本应用经文与科判取材于法界佛教总会编辑之《大佛顶首楞严经浅释》，其经文援用《龙藏》，科判以圆瑛法师简要科判为主，参照交光法师《正脉疏》等。感恩一切为此经流传付出心血者。"
                )

                goldDivider

                sourceCard(
                    title: "音频",
                    text: "音频读诵由屏东能净协会录制，资料来源于佛学多媒体资料库。感恩清音演法，普利有情。"
                )

                goldDivider

                sourceCard(
                    title: "图像",
                    text: "图标和启动画面取自明代画家吴彬佛画。吴彬，字文中，莆田人，以奇崛画法著称，其佛画庄严古逸，为晚明独步。"
                )

                goldDivider

                // MARK: 收束 — 致敬
                VStack(spacing: 12) {
                    Text("随喜功德")
                        .font(SutraTypographyBridge.uiCaption(weight: .light))
                        .foregroundColor(textTertiary)
                        .tracking(4)

                    Text("☸️南無楞嚴會上佛菩薩")
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
