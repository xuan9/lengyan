//
//  SutraCardRenderer.swift
//  lengyan
//
//  分享卡片渲染引擎 — SwiftUI View → UIImage
//  SwiftUI View → UIImage 渲染引擎
//

import SwiftUI
import UIKit

/// 经文卡片渲染器
/// 将 SwiftUI 分享卡片视图渲染为高分辨率 UIImage
struct SutraCardRenderer {

    // MARK: - Public API

    /// 渲染分享卡片为 UIImage
    /// - Parameters:
    ///   - text: 经文内容
    ///   - source: 来源标注
    ///   - template: 卡片模板（默认竖版，零摩擦分享）
    /// - Returns: 渲染后的高分辨率图片
    @MainActor
    static func render(
        text: String,
        source: String,
        template: ShareCardTemplate = .portrait,
        verseFontBase: CGFloat = 22
    ) -> UIImage? {
        let size = template.renderSize
        let view = SutraShareCardView(text: text, source: source, template: template, verseFontBase: verseFontBase)
            .frame(width: size.width, height: size.height)

        return renderView(view: view, size: size)
    }

    /// 使用默认竖版模板快速渲染（零摩擦分享路径）
    @MainActor
    static func renderDefault(text: String, source: String) -> UIImage? {
        return renderLongCard(text: text, source: source)
    }

    // MARK: - ImageRenderer

    @MainActor
    private static func renderView<V: View>(view: V, size: CGSize) -> UIImage? {
        if #available(iOS 16.0, *) {
            return renderWithImageRenderer(view: view, size: size)
        } else {
            return renderWithHostingController(view: view, size: size)
        }
    }

    @available(iOS 16.0, *)
    @MainActor
    private static func renderWithImageRenderer<V: View>(view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0  // 2x 对于分享图足够清晰
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage
    }

    @MainActor
    private static func renderWithHostingController<V: View>(view: V, size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

}

// MARK: - Share Helper

extension SutraCardRenderer {

    /// 一键分享：渲染图片 + 弹出分享面板
    @MainActor
    static func shareCard(
        text: String,
        source: String,
        template: ShareCardTemplate = .portrait,
        from viewController: UIViewController,
        barButtonItem: UIBarButtonItem? = nil
    ) {
        let image: UIImage?
        if template == .portrait {
            image = renderLongCard(text: text, source: source)
        } else {
            image = render(text: text, source: source, template: template)
        }

        // 同时分享图片和文本（图片优先显示）；长图过大时仍分享全文文字。
        let shareText = "「\(text)」── \(source) ──"
        let activityItems: [Any] = image.map { [$0, shareText] } ?? [shareText]

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // iPad popover 支持
        if let popover = activityVC.popoverPresentationController {
            if let barItem = barButtonItem {
                popover.barButtonItem = barItem
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0, height: 0
                )
            }
        }

        viewController.present(activityVC, animated: true)
    }
}

// MARK: - v1+v2：自适应字号 + 单张长图 + 预览

extension SutraCardRenderer {

    /// 2x 渲染时约 2160 x 24000 px，继续放大会明显增加内存和分享兼容风险。
    static let maxLongShareImageHeight: CGFloat = 12000

    /// 按经文字数自适应正文字号基准：短句大、长文小（夹在 14~28）。用户无需选字号。
    static func verseFontBase(forCharCount count: Int) -> CGFloat {
        let base: CGFloat = 28
        let minBase: CGFloat = 14
        let ref = 40.0
        let scale = (ref / Double(max(count, 40))).squareRoot()
        return min(base, max(minBase, base * scale))
    }

    /// 竖版宽度不变、高度随内容增长地渲染单张卡片（短文紧凑，长文生成长图）。
    /// 用 UIFont 度量经文块高度来定画框（SwiftUI ImageRenderer 对含弹性元素的视图测高不可靠），
    /// 经文上下弹性留白将其居中；极短句用最小高度兜底，避免压成扁条；过长图片由 maximumHeight 拦截。
    @MainActor
    static func renderCompactPortrait(
        text: String,
        source: String,
        verseFontBase: CGFloat,
        width: CGFloat = 1080,
        minHeightRatio: CGFloat = 0.72,
        breathRatio: CGFloat = 0.08,
        maximumHeight: CGFloat? = nil
    ) -> UIImage? {
        let targetHeight = compactPortraitHeight(text: text, verseFontBase: verseFontBase, width: width, minHeightRatio: minHeightRatio)
        if let maximumHeight, targetHeight > maximumHeight {
            return nil
        }

        let view = SutraShareCardView(text: text, source: source, template: .portrait,
                                      verseFontBase: verseFontBase, compact: true, compactBreath: width * breathRatio)
            .frame(width: width, height: targetHeight)
        return renderView(view: view, size: CGSize(width: width, height: targetHeight))
    }

    static func compactPortraitHeight(
        text: String,
        verseFontBase: CGFloat,
        width: CGFloat = 1080,
        minHeightRatio: CGFloat = 0.72
    ) -> CGFloat {
        // UIFont 精确估算经文块（引号+正文）高度，避免 SwiftUI 弹性布局导致测高不稳定。
        let verseBlock = verseBlockHeight(text: text, base: verseFontBase, width: width)
        // 固定部分估算：页眉顶饰、经文上下间距、页脚来源/底饰、上下页边距。偏大防经文溢出。
        let extras = width * 0.42
        return max(verseBlock + extras, width * minHeightRatio)
    }

    /// 用 UIFont 估算经文块（上引号 + 正文 + 下引号）的渲染高度，与 SutraShareCardView 的字号/行距一致。
    /// SwiftUI ImageRenderer 对含弹性元素的视图高度测量不可靠，故用确定性的 NSString 度量替代。
    static func verseBlockHeight(text: String, base: CGFloat, width: CGFloat = 1080) -> CGFloat {
        let scale = min(2.5, width / 300.0)
        let pt = base * scale
        let font = UIFont(name: "STKaiti", size: pt) ?? .systemFont(ofSize: pt)
        let quoteFont = UIFont(name: "STKaiti", size: 32 * scale) ?? .systemFont(ofSize: 32 * scale)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 14 * scale
        let usable = width * 0.8
        func height(_ s: String, _ f: UIFont) -> CGFloat {
            let attr: [NSAttributedString.Key: Any] = [.font: f, .paragraphStyle: para]
            let r = (s as NSString).boundingRect(
                with: CGSize(width: usable, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attr, context: nil)
            return ceil(r.height)
        }
        let verseH = height(text, font)
        let quoteH = height("「", quoteFont)
        let innerSpacing = width * 0.02 * 2   // 经文 VStack 内上下 spacing（引号↔正文）
        return (quoteH * 2 + verseH + innerSpacing) * 1.1   // 10% 余量，吸收 boundingRect 与 SwiftUI 换行差异，防溢出
    }

    /// 渲染单张分享长图。过长时返回 nil，调用方保持全文文字分享/拷贝。
    @MainActor
    static func renderLongCard(text: String, source: String) -> UIImage? {
        let base = verseFontBase(forCharCount: text.count)
        return renderCompactPortrait(
            text: text,
            source: source,
            verseFontBase: base,
            maximumHeight: maxLongShareImageHeight
        )
    }

    /// 兼容旧调用：现在最多只返回一张长图。
    @MainActor
    static func renderCards(text: String, source: String) -> [UIImage] {
        renderLongCard(text: text, source: source).map { [$0] } ?? []
    }

    /// 弹出预览页：可安全生成时展示单张长图；超长则不渲染图，只给「分享文字 + 拷贝」。
    @MainActor
    static func presentPreview(text: String, source: String, from vc: UIViewController, barButtonItem: UIBarButtonItem? = nil) {
        let preview: SutraSharePreviewController
        if let image = renderLongCard(text: text, source: source) {
            preview = SutraSharePreviewController(images: [image], fullText: text, longTextHint: nil)
        } else {
            preview = SutraSharePreviewController(images: [], fullText: text,
                                                  longTextHint: String(format: L10n.str("share_long_text_hint_format"), text.count))
        }
        preview.modalPresentationStyle = .pageSheet
        if let sheet = preview.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        vc.present(preview, animated: true)
    }
}

// MARK: - 分享预览页（展示长图 + 三选项）

struct SutraSharePreviewView: View {
    let images: [UIImage]
    var onShareImage: (() -> Void)?
    var onShareText: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?
    /// 非空 = 纯文本模式（长图过大未渲染）：展示提示、隐藏「分享美图」按钮
    var longTextHint: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.str("share_preview_title"))
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textPrimary)))
                Spacer()
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if images.isEmpty {
                // 纯文本模式：长图过大未渲染，给一句说明居中展示
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .primary)).opacity(0.6))
                    Text(longTextHint ?? "")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(images.indices, id: \.self) { i in
                            Image(uiImage: images[i])
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            HStack(spacing: 10) {
                if !images.isEmpty {
                    actionButton(title: L10n.str("share_image"), systemName: "photo", action: { onShareImage?() }, primary: true)
                }
                actionButton(title: L10n.str("share_text"), systemName: "text.alignleft", action: { onShareText?() }, primary: images.isEmpty)
                actionButton(title: L10n.str("copy"), systemName: "doc.on.doc", action: { onCopy?() }, primary: false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: SutraDesignTokens.shared.color(for: .background)))
    }

    private func actionButton(title: String, systemName: String, action: @escaping () -> Void, primary: Bool) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName).font(.system(size: 18, weight: .regular))
                Text(title).font(.system(size: 12, weight: .medium, design: .serif))
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundColor(primary
                ? Color(uiColor: SutraDesignTokens.shared.color(for: .background))
                : Color(uiColor: SutraDesignTokens.shared.color(for: .textPrimary)))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(primary
                        ? Color(uiColor: SutraDesignTokens.shared.color(for: .primary))
                        : Color(uiColor: SutraDesignTokens.shared.color(for: .card)))
            )
        }
    }
}

final class SutraSharePreviewController: UIHostingController<SutraSharePreviewView> {
    private let images: [UIImage]
    private let fullText: String

    init(images: [UIImage], fullText: String, longTextHint: String? = nil) {
        self.images = images
        self.fullText = fullText
        super.init(rootView: SutraSharePreviewView(images: images, longTextHint: longTextHint))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.onShareImage = { [weak self] in self?.shareImages() }
        rootView.onShareText = { [weak self] in self?.shareText() }
        rootView.onCopy = { [weak self] in self?.copyText() }
        rootView.onClose = { [weak self] in self?.dismiss(animated: true) }
    }

    private func presentActivity(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(vc, animated: true)
    }

    private func shareImages() { presentActivity(images) }
    private func shareText() { presentActivity([fullText]) }

    private func copyText() {
        UIPasteboard.general.string = fullText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss(animated: true)
    }
}
