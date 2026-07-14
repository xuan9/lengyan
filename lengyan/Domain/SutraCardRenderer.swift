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
    private static func renderView<V: View>(view: V, size: CGSize, scale: CGFloat = 2.0) -> UIImage? {
        if #available(iOS 16.0, *) {
            return renderWithImageRenderer(view: view, size: size, scale: scale)
        } else {
            return renderWithHostingController(view: view, size: size, scale: scale)
        }
    }

    @available(iOS 16.0, *)
    @MainActor
    private static func renderWithImageRenderer<V: View>(view: V, size: CGSize, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage
    }

    @MainActor
    private static func renderWithHostingController<V: View>(view: V, size: CGSize, scale: CGFloat) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

}

struct SutraShareCardRenderPlan {
    let text: String
    let source: String
    let verseFontBase: CGFloat
    let width: CGFloat
    let height: CGFloat
    let renderScale: CGFloat
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
        let activityItems: [Any]
        if let image, let imageURL = writeShareJPEG(image: image) {
            activityItems = [imageURL, shareText]
        } else {
            activityItems = [shareText]
        }

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

    /// 长图预览/分享的安全高度。长图用 1x 输出，约 1080 x 11000 px，避免预览白屏和内存尖峰。
    static let maxLongShareImageHeight: CGFloat = 11000
    static let maxLongShareImageCharacterCount = 3000
    static let highResolutionLongImageCharacterCount = 520
    static let highResolutionLongImageHeight: CGFloat = 2400
    static let longShareJPEGQuality: CGFloat = 0.92

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
        maximumHeight: CGFloat? = nil,
        renderScale: CGFloat = 2.0
    ) -> UIImage? {
        let targetHeight = compactPortraitHeight(text: text, verseFontBase: verseFontBase, width: width, minHeightRatio: minHeightRatio)
        if let maximumHeight, targetHeight > maximumHeight {
            return nil
        }

        let view = SutraShareCardView(text: text, source: source, template: .portrait,
                                      verseFontBase: verseFontBase, compact: true, compactBreath: width * breathRatio)
            .frame(width: width, height: targetHeight)
        guard let image = renderView(view: view, size: CGSize(width: width, height: targetHeight), scale: renderScale),
              imageHasVisibleContent(image) else {
            return nil
        }
        return image
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
        guard let plan = longCardRenderPlan(text: text, source: source) else {
            return nil
        }
        return renderLongCard(plan: plan)
    }

    static func longCardRenderPlan(text: String, source: String) -> SutraShareCardRenderPlan? {
        let base = verseFontBase(forCharCount: text.count)
        let targetHeight = compactPortraitHeight(text: text, verseFontBase: base)
        guard let renderScale = longImageRenderScale(characterCount: text.count, targetHeight: targetHeight) else {
            return nil
        }
        return SutraShareCardRenderPlan(
            text: text,
            source: source,
            verseFontBase: base,
            width: 1080,
            height: targetHeight,
            renderScale: renderScale
        )
    }

    @MainActor
    static func renderLongCard(plan: SutraShareCardRenderPlan) -> UIImage? {
        return renderCompactPortrait(
            text: plan.text,
            source: plan.source,
            verseFontBase: plan.verseFontBase,
            width: plan.width,
            maximumHeight: maxLongShareImageHeight,
            renderScale: plan.renderScale
        )
    }

    static func longImageRenderScale(characterCount: Int, targetHeight: CGFloat) -> CGFloat? {
        if characterCount > maxLongShareImageCharacterCount || targetHeight > maxLongShareImageHeight {
            return nil
        }

        if characterCount > highResolutionLongImageCharacterCount || targetHeight > highResolutionLongImageHeight {
            return 1.0
        }

        return 2.0
    }

    static func writeShareJPEG(image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: longShareJPEGQuality) else {
            return nil
        }

        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("LengyanShare", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileName = "lengyan-share-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).jpg"
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func imageHasVisibleContent(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let width = 12
        let height = 12
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minLuminance = 255
        var maxLuminance = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
            minLuminance = min(minLuminance, luminance)
            maxLuminance = max(maxLuminance, luminance)
        }

        return maxLuminance - minLuminance > 8
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
        if let plan = longCardRenderPlan(text: text, source: source) {
            preview = SutraSharePreviewController(cardPlan: plan, fullText: text, longTextHint: nil)
        } else {
            preview = SutraSharePreviewController(cardPlan: nil, fullText: text,
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
    let cardPlan: SutraShareCardRenderPlan?
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

            if let cardPlan {
                ScrollView {
                    GeometryReader { geo in
                        let previewWidth = min(cardPlan.width, max(240, geo.size.width - 48))
                        let previewScale = previewWidth / cardPlan.width
                        HStack {
                            Spacer(minLength: 0)
                            SutraShareCardView(
                                text: cardPlan.text,
                                source: cardPlan.source,
                                template: .portrait,
                                verseFontBase: cardPlan.verseFontBase,
                                compact: true,
                                compactBreath: cardPlan.width * 0.08
                            )
                            .frame(width: cardPlan.width, height: cardPlan.height)
                            .scaleEffect(previewScale, anchor: .top)
                            .frame(width: previewWidth, height: cardPlan.height * previewScale)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: max(1, cardPlan.height * min(cardPlan.width, UIScreen.main.bounds.width - 48) / cardPlan.width))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            } else {
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
            }

            HStack(spacing: 10) {
                if cardPlan != nil {
                    actionButton(title: L10n.str("share_image"), systemName: "photo", action: { onShareImage?() }, primary: true)
                }
                actionButton(title: L10n.str("share_text"), systemName: "text.alignleft", action: { onShareText?() }, primary: cardPlan == nil)
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
    private let cardPlan: SutraShareCardRenderPlan?
    private let fullText: String
    private var temporaryShareURLs: [URL] = []

    init(cardPlan: SutraShareCardRenderPlan?, fullText: String, longTextHint: String? = nil) {
        self.cardPlan = cardPlan
        self.fullText = fullText
        super.init(rootView: SutraSharePreviewView(cardPlan: cardPlan, longTextHint: longTextHint))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        for url in temporaryShareURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

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

    private func shareImages() {
        guard let cardPlan,
              let image = SutraCardRenderer.renderLongCard(plan: cardPlan),
              let imageURL = SutraCardRenderer.writeShareJPEG(image: image) else {
            presentActivity([fullText])
            return
        }

        temporaryShareURLs.append(imageURL)
        presentActivity([imageURL])
    }
    private func shareText() { presentActivity([fullText]) }

    private func copyText() {
        UIPasteboard.general.string = fullText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss(animated: true)
    }
}
