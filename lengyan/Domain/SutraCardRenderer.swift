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

        return renderWithImageRenderer(view: view, size: size)
    }

    /// 使用默认竖版模板快速渲染（零摩擦分享路径）
    @MainActor
    static func renderDefault(text: String, source: String) -> UIImage? {
        return render(text: text, source: source, template: .portrait)
    }

    // MARK: - ImageRenderer

    @MainActor
    private static func renderWithImageRenderer<V: View>(view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0  // 2x 对于分享图足够清晰
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage
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
        guard let image = render(text: text, source: source, template: template) else { return }

        // 同时分享图片和文本（图片优先显示）
        let shareText = "「\(text)」── \(source) ──"
        let activityItems: [Any] = [image, shareText]

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

// MARK: - v1+v2：自适应字号 + 自动分多图 + 预览

extension SutraCardRenderer {

    /// 按经文字数自适应正文字号基准：短句大、长文小（夹在 14~28）。用户无需选字号。
    static func verseFontBase(forCharCount count: Int) -> CGFloat {
        let base: CGFloat = 28
        let minBase: CGFloat = 14
        let ref = 40.0
        let scale = (ref / Double(max(count, 40))).squareRoot()
        return min(base, max(minBase, base * scale))
    }

    /// 文本过长时按标点拆成多段（每段 ≤ maxChars），让每张图字号都舒适可读，而非缩到看不清
    static func splitSutra(_ text: String, maxChars: Int = 480) -> [String] {
        guard text.count > maxChars else { return [text] }
        var chunks: [String] = []
        var current = ""
        let breaks: Set<Character> = ["。", "！", "？", "；", "，", "：", "．", "…", "\n"]
        for ch in text {
            current.append(ch)
            if current.count >= maxChars && breaks.contains(ch) {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// 竖版宽度不变、高度随内容收缩地渲染单张卡片（短/中经文用，消除 9:16 画框的上下尴尬留白）。
    /// 用 UIFont 度量经文块高度来定画框（SwiftUI ImageRenderer 对含弹性元素的视图测高不可靠），
    /// 经文上下弹性留白将其居中；极短句用最小高度兜底，避免压成扁条。
    @MainActor
    static func renderCompactPortrait(
        text: String,
        source: String,
        verseFontBase: CGFloat,
        width: CGFloat = 1080,
        minHeightRatio: CGFloat = 0.72,
        breathRatio: CGFloat = 0.08
    ) -> UIImage? {
        // 1) UIFont 精确估算经文块（引号+正文）高度——SwiftUI 弹性元素使 ImageRenderer 高度测量不可靠，
        //    改用确定性的 NSString 文本度量，与字号/行距一致
        let verseBlock = verseBlockHeight(text: text, base: verseFontBase, width: width)
        // 2) 固定部分估算（页眉顶饰 + 经文上下间距 + 页脚来源/底饰 + 上下页边距），偏大防经文溢出
        let extras = width * 0.42
        let targetHeight = max(verseBlock + extras, width * minHeightRatio)
        // 3) 渲染：经文上下弹性留白在 targetHeight 内将其推至视觉中部，header 紧贴顶、footer 紧贴底
        let view = SutraShareCardView(text: text, source: source, template: .portrait,
                                      verseFontBase: verseFontBase, compact: true, compactBreath: width * breathRatio)
            .frame(width: width, height: targetHeight)
        return renderWithImageRenderer(view: view, size: CGSize(width: width, height: targetHeight))
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

    /// 美图分享的图数上限：超过则不再渲染美图（省去一次性渲染十几张图的卡顿与内存；社交平台也不宜连发多图）
    static let maxShareImageCount = 6

    /// 渲染一组分享卡片：自动判断一张（自适应字号）或多张（超长自动分图）。
    /// 注意：超 maxShareImageCount 的超长经文应在 presentPreview 中走纯文本路径，不调用本方法。
    @MainActor
    static func renderCards(text: String, source: String) -> [UIImage] {
        let chunks = splitSutra(text)
        let single = chunks.count == 1
        return chunks.compactMap { chunk in
            let base = verseFontBase(forCharCount: chunk.count)
            // 单张：竖版缩高贴合内容（消除短经文的上下留白）；多张分图：维持固定 9:16，浏览高度一致
            if single {
                return renderCompactPortrait(text: chunk, source: source, verseFontBase: base)
            } else {
                return render(text: chunk, source: source, template: .portrait, verseFontBase: base)
            }
        }
    }

    /// 弹出预览页：≤ maxShareImageCount 张时展示美图（可选分享美图/文字/拷贝）；
    /// 超长（> 上限）则不渲染图，只给「分享文字 + 拷贝」并提示经文较长（省渲染、社交友好）。
    @MainActor
    static func presentPreview(text: String, source: String, from vc: UIViewController, barButtonItem: UIBarButtonItem? = nil) {
        let chunks = splitSutra(text)
        let preview: SutraSharePreviewController
        if chunks.count > maxShareImageCount {
            preview = SutraSharePreviewController(images: [], fullText: text,
                                                  longTextHint: String(format: L10n.str("share_long_text_hint_format"), text.count))
        } else {
            let images = chunks.compactMap { chunk in
                let base = verseFontBase(forCharCount: chunk.count)
                return chunks.count == 1
                    ? renderCompactPortrait(text: chunk, source: source, verseFontBase: base)
                    : render(text: chunk, source: source, template: .portrait, verseFontBase: base)
            }
            guard !images.isEmpty else { return }
            preview = SutraSharePreviewController(images: images, fullText: text, longTextHint: nil)
        }
        preview.modalPresentationStyle = .pageSheet
        if let sheet = preview.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        vc.present(preview, animated: true)
    }
}

// MARK: - 分享预览页（展示卡片 + 三选项）

struct SutraSharePreviewView: View {
    let images: [UIImage]
    var onShareImage: (() -> Void)?
    var onShareText: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?
    /// 非空 = 纯文本模式（经文过长未渲染美图）：展示提示、隐藏「分享美图」按钮
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
                // 纯文本模式：经文过长未渲染美图，给一句说明居中展示
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
