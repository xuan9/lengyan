//
//  FeedbackView.swift
//  lengyan
//
//  反馈页面 — 对话式温暖风格
//

import SwiftUI
import UIKit

enum FeedbackLengthState: Equatable {
    /// Keep the normal form quiet, then leave enough notice for a short
    /// paragraph before reaching the service limit.
    static let warningWindow = 200

    case hidden
    case remaining(Int)
    case limitReached
    case overLimit(Int)

    static func resolve(contentLength: Int, maximum: Int) -> FeedbackLengthState {
        let count = max(0, contentLength)
        if count > maximum {
            return .overLimit(count - maximum)
        }
        if count == maximum {
            return .limitReached
        }
        let remaining = maximum - count
        if remaining <= min(warningWindow, maximum) {
            return .remaining(remaining)
        }
        return .hidden
    }

    static func accessibilityAnnouncementLevel(
        contentLength: Int,
        maximum: Int
    ) -> Int {
        if contentLength > maximum { return 3 }
        if contentLength == maximum { return 2 }
        let remaining = maximum - max(0, contentLength)
        if remaining <= warningWindow { return 1 }
        return 0
    }
}

struct FeedbackView: View {
    // Feedback can contain sensitive text, so keep it only for this form's lifetime.
    @State private var content = ""
    @State private var isSending = false
    @State private var sendSucceeded = false
    @State private var submittedReference: String?
    @State private var didCopyReference = false
    @State private var errorMessage: String?
    @State private var showContent = false
    @State private var hasConsumedLegacyDraft = false
    @State private var lastLengthAnnouncementLevel = 0
    @Environment(\.dismiss) private var dismiss

    private var normalizedContent: String {
        FeedbackService.normalizedContent(content)
    }

    private var contentLength: Int {
        normalizedContent.count
    }

    private var isEmpty: Bool {
        normalizedContent.isEmpty
    }

    private var isTooLong: Bool {
        contentLength > FeedbackService.maximumContentLength
    }

    var body: some View {
        Group {
            if sendSucceeded {
                successView
            } else {
                formView
            }
        }
        .onAppear(perform: consumeLegacyDraftIfNeeded)
        .onChange(of: contentLength, perform: announceLengthMilestoneIfNeeded)
    }

    // MARK: - 致谢页

    private var successView: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 32)

                    Image(systemName: "leaf.circle")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(
                            Color(SutraDesignTokens.shared.color(for: .decorativeGold))
                                .opacity(showContent ? 0.6 : 0)
                        )
                        .padding(.bottom, 24)

                    Text(L10n.str("feedback_success_title"))
                        .font(SutraTypographyBridge.uiBody(weight: .medium))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                        .opacity(showContent ? 1 : 0)
                        .padding(.bottom, 12)

                    Text(L10n.str("feedback_success_subtitle"))
                        .font(SutraTypographyBridge.uiCaption(weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.textTertiary))
                        .opacity(showContent ? 1 : 0)
                        .padding(.bottom, 24)

                    if let submittedReference {
                        referenceSection(submittedReference)
                            .opacity(showContent ? 1 : 0)
                            .padding(.bottom, 32)
                    }

                    Button(action: dismiss.callAsFunction) {
                        Text(L10n.str("done"))
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .tracking(3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 64)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(SutraDesignSystem.color(.primary))
                            )
                    }
                    .opacity(showContent ? 1 : 0)

                    Spacer(minLength: 32)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            .background(SutraDesignSystem.backgroundColor())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                showContent = true
            }
        }
    }

    private func referenceSection(_ reference: String) -> some View {
        VStack(spacing: 12) {
            Text(L10n.str("feedback_reference_title"))
                .font(SutraTypographyBridge.uiSmall(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))

            Text(FeedbackService.displayReference(reference) ?? reference)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                .accessibilityLabel(
                    L10n.str("feedback_reference_title") + " " + reference
                )

            Button {
                UIPasteboard.general.string = reference
                didCopyReference = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: didCopyReference ? "checkmark" : "doc.on.doc")
                    Text(
                        L10n.str(
                            didCopyReference
                                ? "feedback_reference_copied"
                                : "feedback_reference_copy"
                        )
                    )
                }
                .font(SutraTypographyBridge.uiSmall(weight: .medium))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(SutraDesignTokens.shared.color(for: .card)))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 反馈表单

    private var formView: some View {
        GeometryReader { geo in
            ScrollView {
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

                    Spacer(minLength: 0)

                    sendButton
                    footerText
                }
                .frame(minHeight: geo.size.height)
                .readingContentWidth()
            }
            .background(SutraDesignSystem.backgroundColor())
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.str("feedback_title"))
                .font(SutraTypographyBridge.uiBody(weight: .medium))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))

            Text(L10n.str("feedback_subtitle"))
                .font(SutraTypographyBridge.uiCaption(weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))
        }
    }

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

    private func textSection(frameHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(SutraDesignTokens.shared.color(for: .card)))

                if content.isEmpty {
                    Text(L10n.str("feedback_placeholder"))
                        .font(SutraTypographyBridge.uiBody(weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.textTertiary).opacity(0.5))
                        .padding(16)
                }

                hideTextEditorBackground(TextEditor(text: $content))
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .sutraText)))
                    .frame(minHeight: max(160, frameHeight))
                    .padding(12)
                    .accessibilityHint(editorAccessibilityHint)
            }

            if shouldShowContentLength {
                Text(contentLengthText)
                    .font(SutraTypographyBridge.uiSmall(weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(isTooLong ? .red : SutraDesignSystem.color(.textTertiary))
                    .accessibilityLabel(contentLengthText)
            }
        }
    }

    private var sendButton: some View {
        Button(action: sendFeedback) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isSending ? L10n.str("feedback_sending") : L10n.str("feedback_send"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isEmpty || isTooLong
                            ? Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.3)
                            : Color(SutraDesignTokens.shared.color(for: .primary))
                    )
            )
        }
        .disabled(isEmpty || isTooLong || isSending)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(SutraDesignSystem.backgroundColor())
    }

    private var footerText: some View {
        Text(L10n.str("feedback_footer"))
            .font(SutraTypographyBridge.uiSmall(weight: .light))
            .foregroundColor(SutraDesignSystem.color(.textTertiary))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    // MARK: - 发送

    private func sendFeedback() {
        let text = normalizedContent
        guard !text.isEmpty else { return }
        guard text.count <= FeedbackService.maximumContentLength else {
            errorMessage = contentTooLongMessage
            return
        }
        guard let productID = FeedbackService.currentProductID() else {
            errorMessage = L10n.str("feedback_send_failed")
            return
        }

        errorMessage = nil
        didCopyReference = false
        isSending = true
        FeedbackService.submit(
            FeedbackService.FeedbackRequest(productID: productID, content: text)
        ) { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case let .success(reference):
                    content = ""
                    submittedReference = reference
                    sendSucceeded = true
                case let .failure(error):
                    switch error {
                    case .contentTooLong:
                        errorMessage = contentTooLongMessage
                    case .rateLimited:
                        errorMessage = L10n.str("feedback_rate_limited_error")
                    case .invalidRequest, .transportFailed, .serverRejected:
                        errorMessage = L10n.str("feedback_send_failed")
                    }
                }
            }
        }
    }

    private func consumeLegacyDraftIfNeeded() {
        guard !hasConsumedLegacyDraft else { return }
        hasConsumedLegacyDraft = true
        let legacyDraft = FeedbackService.consumeLegacyDraft()
        if content.isEmpty {
            content = legacyDraft
        }
    }

    private func announceLengthMilestoneIfNeeded(_ length: Int) {
        let level = FeedbackLengthState.accessibilityAnnouncementLevel(
            contentLength: length,
            maximum: FeedbackService.maximumContentLength
        )
        if level < lastLengthAnnouncementLevel {
            lastLengthAnnouncementLevel = level
            return
        }
        guard level > lastLengthAnnouncementLevel,
              SutraAccessibilityManager.shared.isVoiceOverRunning else { return }
        lastLengthAnnouncementLevel = level
        SutraAccessibilityManager.shared.announce(contentLengthText)
    }

    private var contentLengthText: String {
        let maximum = FeedbackService.maximumContentLength
        switch FeedbackLengthState.resolve(
            contentLength: contentLength,
            maximum: maximum
        ) {
        case .hidden:
            return ""
        case let .remaining(remaining):
            return String(
                format: L10n.str("feedback_content_remaining_format"),
                remaining
            )
        case .limitReached:
            return String(
                format: L10n.str("feedback_content_limit_reached_format"),
                maximum
            )
        case let .overLimit(excess):
            return String(
                format: L10n.str("feedback_content_over_limit_format"),
                excess
            )
        }
    }

    private var shouldShowContentLength: Bool {
        FeedbackLengthState.resolve(
            contentLength: contentLength,
            maximum: FeedbackService.maximumContentLength
        ) != .hidden
    }

    private var editorAccessibilityHint: String {
        String(
            format: L10n.str("feedback_editor_accessibility_hint_format"),
            FeedbackService.maximumContentLength
        )
    }

    private var contentTooLongMessage: String {
        String(
            format: L10n.str("feedback_content_too_long_error_format"),
            FeedbackService.maximumContentLength
        )
    }
}

// MARK: - TextEditor 背景隐藏

@ViewBuilder
private func hideTextEditorBackground(_ editor: TextEditor) -> some View {
    if #available(iOS 16.0, *) {
        editor.scrollContentBackground(.hidden)
    } else {
        editor
    }
}
