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

    /// 按经文字数自适应正文字号基准：短句大、长文小（夹在 14~22）。用户无需选字号。
    static func verseFontBase(forCharCount count: Int) -> CGFloat {
        let base: CGFloat = 22
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

    /// 渲染一组分享卡片：自动判断一张（自适应字号）或多张（超长自动分图）
    @MainActor
    static func renderCards(text: String, source: String) -> [UIImage] {
        let chunks = splitSutra(text)
        return chunks.compactMap { chunk in
            render(text: chunk, source: source, template: .portrait,
                   verseFontBase: verseFontBase(forCharCount: chunk.count))
        }
    }

    /// 弹出预览页：展示将分享的卡片（一张或多张），由用户选「分享美图 / 分享文字 / 拷贝」
    @MainActor
    static func presentPreview(text: String, source: String, from vc: UIViewController, barButtonItem: UIBarButtonItem? = nil) {
        let images = renderCards(text: text, source: source)
        guard !images.isEmpty else { return }
        let preview = SutraSharePreviewController(images: images, fullText: text)
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("预览")
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

            HStack(spacing: 10) {
                actionButton(title: "分享美图", systemName: "photo", action: { onShareImage?() }, primary: true)
                actionButton(title: "分享文字", systemName: "text.alignleft", action: { onShareText?() }, primary: false)
                actionButton(title: "拷贝", systemName: "doc.on.doc", action: { onCopy?() }, primary: false)
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

    init(images: [UIImage], fullText: String) {
        self.images = images
        self.fullText = fullText
        super.init(rootView: SutraSharePreviewView(images: images))
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
