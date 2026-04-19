//
//  FeedbackView.swift
//  lengyan
//
//  App 内反馈表单 — 禅意极简风格
//

import SwiftUI

struct FeedbackView: View {
    @AppStorage("feedbackDraft") private var content = ""
    @AppStorage("feedbackDraftType") private var draftType = "feedback"
    @State private var isSending = false
    @State private var sendSucceeded = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var selectedType: FeedbackService.FeedbackType {
        FeedbackService.FeedbackType(rawValue: draftType) ?? .feedback
    }

    var body: some View {
        if sendSucceeded {
            successView
        } else {
            formView
        }
    }

    // MARK: - 成功确认页

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🪷")
                .font(.system(size: 48))

            Text("感谢反馈")
                .font(SutraTypographyBridge.uiBody(weight: .medium))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))

            Text("阿弥陀佛")
                .font(SutraTypographyBridge.uiCaption(weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(SutraDesignSystem.backgroundColor())
        .onAppear {
            // 2 秒后自动返回
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }

    // MARK: - 反馈表单

    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 错误提示
                    if let err = errorMessage {
                        Text(err)
                            .font(SutraTypographyBridge.uiCaption(weight: .regular))
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.08))
                            )
                    }

                    typeSelector
                    textEditor
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            sendButton
        }
        .background(SutraDesignSystem.backgroundColor())
    }

    // MARK: - 类型选择

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("类型")
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))

            HStack(spacing: 10) {
                ForEach(FeedbackService.FeedbackType.allCases, id: \.self) { type in
                    let isSelected = selectedType == type
                    Button(action: { draftType = type.rawValue }) {
                        Text("\(type.icon) \(type.label)")
                            .font(.system(size: 13, weight: isSelected ? .medium : .light))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: isSelected ? .sutraText : .textSecondary)))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(isSelected ? 0.6 : 0.15), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - 文本输入

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内容")
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("写下你的反馈、建议或发现的问题…")
                        .font(SutraTypographyBridge.uiBody(weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.5))
                        .padding(12)
                }

                TextEditor(text: $content)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                    .frame(minHeight: 160)
                    .padding(8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.3), lineWidth: 0.5)
            )
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
                Text(isSending ? "发送中…" : "发送反馈")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.3)
                        : Color(SutraDesignTokens.shared.color(for: .primary)))
            )
        }
        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(SutraDesignSystem.backgroundColor())
    }

    // MARK: - 发送

    private func sendFeedback() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        errorMessage = nil
        isSending = true
        FeedbackService.submit(FeedbackService.FeedbackRequest(content: text, type: selectedType)) { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case .success:
                    content = ""
                    draftType = "feedback"
                    sendSucceeded = true
                case .failure:
                    errorMessage = "发送失败，请检查网络后重试"
                }
            }
        }
    }
}
