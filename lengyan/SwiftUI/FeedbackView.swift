//
//  FeedbackView.swift
//  lengyan
//
//  反馈页面 — 对话式温暖风格
//

import SwiftUI

struct FeedbackView: View {
    @AppStorage("feedbackDraft") private var content = ""
    @State private var isSending = false
    @State private var sendSucceeded = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if sendSucceeded {
            successView
        } else {
            formView
        }
    }

    // MARK: - 致谢页

    @State private var showContent = false

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            // 莲花意象 — 内敛而庄严
            Image(systemName: "leaf.circle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(showContent ? 0.6 : 0))
                .padding(.bottom, 32)

            // 主文：感恩
            Text("感谢你的心声")
                .font(SutraTypographyBridge.uiBody(weight: .medium))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 12)

            // 副文：珍重
            Text("每一份心声，我们都珍重")
                .font(SutraTypographyBridge.uiCaption(weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 40)

            // 金色分隔线
            Rectangle()
                .fill(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.3))
                .frame(width: 40, height: 0.5)
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 20)

            // 收束：佛门祝福
            Text("阿弥陀佛")
                .font(SutraTypographyBridge.uiCaption(weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(SutraDesignSystem.backgroundColor())
        .onAppear {
            // 淡入动画，让致谢有仪式感
            withAnimation(.easeInOut(duration: 0.8)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
    }

    // MARK: - 反馈表单

    private var formView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.bottom, 20)

                    if let err = errorMessage {
                        errorBanner(err)
                            .padding(.bottom, 16)
                    }

                    textSection(frameHeight: geo.size.height - 260)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                sendButton

                footerText
            }
            .background(SutraDesignSystem.backgroundColor())
        }
    }

    // MARK: - 标题

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("有什么想对我们说？")
                .font(SutraTypographyBridge.uiBody(weight: .medium))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))

            Text("任何想法，我们都珍重")
                .font(SutraTypographyBridge.uiCaption(weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))
        }
    }

    // MARK: - 错误提示

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(SutraTypographyBridge.uiCaption(weight: .regular))
            .foregroundColor(.red)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.08))
            )
    }

    // MARK: - 文本输入

    private func textSection(frameHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 背景：纯净宣纸色，微妙区分输入区域，跟随主题
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(SutraDesignTokens.shared.color(for: .card)))

            if content.isEmpty {
                Text("写下你的心声…")
                    .font(SutraTypographyBridge.uiBody(weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textTertiary).opacity(0.5))
                    .padding(16)
            }

            hideTextEditorBackground(TextEditor(text: $content))
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                .frame(minHeight: max(160, frameHeight))
                .padding(12)
        }
    }

    // MARK: - 发送按钮

    private var sendButton: some View {
        Button(action: sendFeedback) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isSending ? "发送中…" : "发送")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEmpty
                        ? Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.3)
                        : Color(SutraDesignTokens.shared.color(for: .primary)))
            )
        }
        .disabled(isEmpty || isSending)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(SutraDesignSystem.backgroundColor())
    }

    // MARK: - 底部文字

    private var footerText: some View {
        Text("随缘随喜")
            .font(SutraTypographyBridge.uiSmall(weight: .light))
            .foregroundColor(SutraDesignSystem.color(.textTertiary))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    // MARK: - 发送

    private func sendFeedback() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        errorMessage = nil
        isSending = true
        FeedbackService.submit(FeedbackService.FeedbackRequest(content: text)) { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case .success:
                    content = ""
                    sendSucceeded = true
                case .failure:
                    errorMessage = "发送失败，请检查网络后重试"
                }
            }
        }
    }
}

// MARK: - iOS 16+ TextEditor 背景隐藏

@ViewBuilder
private func hideTextEditorBackground(_ editor: TextEditor) -> some View {
    if #available(iOS 16.0, *) {
        editor.scrollContentBackground(.hidden)
    } else {
        editor
    }
}
