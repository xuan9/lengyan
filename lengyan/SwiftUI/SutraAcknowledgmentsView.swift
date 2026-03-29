import SwiftUI

struct SutraAcknowledgmentsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                // 顶端留白
                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 32) {
                    // 文字来源
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))

                            Text("文字来源")
                                .font(Font(SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                        }

                        Text("经文和科判来自法界佛教总会网站《大佛顶首楞严经浅释》。感恩法界佛教总会编辑整理！其经文援用《龙藏》及交光法师之《大佛顶首楞严经正脉疏》等，并以圆锳法师简要科判为主。")
                            .font(Font(SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                            .lineSpacing(6)
                    }
                    
 
                    // 音频来源
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))

                            Text("音频来源")
                                .font(Font(SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                        }

                        Text("音频内容来源于佛学多媒体资料库，感恩屏东能净协会读诵录制。")
                            .font(Font(SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                            .lineSpacing(6)
                    }
                    

                    // 音频来源
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))

                            Text("图片来源")
                                .font(Font(SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .medium)))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                        }

                        Text("程序图标和启动画面来自明代画家吳彬画作")
                            .font(Font(SutraTypographyManager.shared.uiFont(for: .uiBody, weight: .regular)))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                            .lineSpacing(6)
                    }
                }
                .padding(.horizontal, 32)

                Divider()
                    .background(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.3))
                    .padding(.vertical, 4)
                
                // 底部莲花点缀
                VStack(alignment: .leading, spacing: 8) {
                    Text("感恩上述来源，随喜功德！")
                        .font(Font(SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .light)))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textTertiary)))

                }
                
                
                VStack(alignment: .leading, spacing: 12,) {
                    Image(systemName: "hands.press.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))
                        

                    Text("南无楞严会上佛菩萨！")
                        .font(Font(SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .light)))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textTertiary)))
                    
                        .lineSpacing(8)
                }
                .padding(.horizontal, 32)
                Spacer(minLength: 60)
                
                Text("✧ ❀ ✧")
                    .font(.system(size: 16))
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.6))

                // Content
            }
        }
        .background(Color(SutraDesignTokens.shared.color(for: .background)).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
    }
}
