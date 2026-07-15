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
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage
    }

    @MainActor
    private static func renderWithHostingController<V: View>(view: V, size: CGSize, scale: CGFloat) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .white
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
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
    let compactBreath: CGFloat
    let compactVerseGap: CGFloat
}

struct SutraSharePaginationPlan {
    let text: String
    let source: String
    let pageTexts: [String]
    let firstPagePlan: SutraShareCardRenderPlan

    var pageCount: Int { pageTexts.count }
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
        var temporaryURLs: [URL] = []
        let activityItems: [Any]
        let textURL = writeShareTextFile(text: shareText, source: source)
        if let image, let imageURL = writeShareJPEG(image: image, source: source) {
            temporaryURLs.append(imageURL)
            if let textURL {
                temporaryURLs.append(textURL)
                activityItems = [imageURL, textURL]
            } else {
                activityItems = [imageURL, shareText]
            }
        } else if template == .portrait,
                  let paginationPlan = paginatedCardPlan(text: text, source: source) {
            let pageURLs = writePaginatedJPEGFiles(plan: paginationPlan)
            temporaryURLs.append(contentsOf: pageURLs)
            if !pageURLs.isEmpty {
                if let textURL {
                    temporaryURLs.append(textURL)
                    activityItems = pageURLs + [textURL]
                } else {
                    activityItems = pageURLs + [shareText]
                }
            } else if let textURL {
                temporaryURLs.append(textURL)
                activityItems = [textURL]
            } else {
                activityItems = [shareText]
            }
        } else if let textURL {
            temporaryURLs.append(textURL)
            activityItems = [textURL]
        } else {
            activityItems = [shareText]
        }

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }

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

    /// 长图预览/分享的安全高度。超长图用 1x 输出，避免预览白屏和内存尖峰。
    static let maxLongShareImageHeight: CGFloat = 60000
    static let maxLongShareImageCharacterCount = 6000
    static let paginatedShareImageCharacterCount = 3000
    static let maxPaginatedShareImageCharacterCount = 30000
    static let highResolutionLongImageCharacterCount = 520
    static let highResolutionLongImageHeight: CGFloat = 2400
    static let longShareJPEGQuality: CGFloat = 0.92
    static let compactPortraitBreathRatio: CGFloat = 0.045
    static let compactPortraitVerseGapRatio: CGFloat = 0.03

    /// 按经文字数自适应正文字号基准：短句大、长文不低于可读字号。用户无需选字号。
    static func verseFontBase(forCharCount count: Int) -> CGFloat {
        let base = max(28, readableShareFontBase())
        let minBase = readableShareFontBase()
        let ref = 40.0
        let scale = (ref / Double(max(count, 40))).squareRoot()
        return min(base, max(minBase, base * scale))
    }

    static func readableShareFontBase(displayWidth: CGFloat = UIScreen.main.bounds.width, canvasWidth: CGFloat = 1080) -> CGFloat {
        let readingFontPointSize = currentReaderFontPointSize()
        let safeDisplayWidth = max(320, displayWidth)
        let canvasFontScale = min(2.5, canvasWidth / 300.0)
        return readingFontPointSize * canvasWidth / safeDisplayWidth / canvasFontScale
    }

    private static func currentReaderFontPointSize() -> CGFloat {
        let multiplier: CGFloat
        switch Prefers.shared.fontSizeLevel {
        case 0: multiplier = 0.8
        case 1: multiplier = 0.9
        case 2: multiplier = 1.0
        case 3: multiplier = 1.1
        case 4: multiplier = 1.25
        default: multiplier = 1.0
        }

        let padScale: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.0
        return round(24 * multiplier * padScale)
    }

    /// 竖版宽度不变、高度随内容增长地渲染单张卡片（短文紧凑，长文生成长图）。
    /// 用 UIFont 度量经文块高度来定画框（SwiftUI ImageRenderer 对含弹性元素的视图测高不可靠），
    /// 经文使用固定留白紧凑排版；极短句用最小高度兜底，避免压成扁条；过长图片由 maximumHeight 拦截。
    @MainActor
    static func renderCompactPortrait(
        text: String,
        source: String,
        verseFontBase: CGFloat,
        width: CGFloat = 1080,
        minHeightRatio: CGFloat = 0.72,
        breathRatio: CGFloat = compactPortraitBreathRatio,
        verseGapRatio: CGFloat = compactPortraitVerseGapRatio,
        maximumHeight: CGFloat? = nil,
        renderScale: CGFloat = 2.0
    ) -> UIImage? {
        let targetHeight = compactPortraitHeight(
            text: text,
            verseFontBase: verseFontBase,
            width: width,
            minHeightRatio: minHeightRatio,
            breathRatio: breathRatio,
            verseGapRatio: verseGapRatio
        )
        if let maximumHeight, targetHeight > maximumHeight {
            return nil
        }

        let breath = width * breathRatio
        let verseGap = width * verseGapRatio
        return renderCompactPortraitBitmap(
            text: text,
            source: source,
            verseFontBase: verseFontBase,
            width: width,
            height: targetHeight,
            breath: breath,
            verseGap: verseGap,
            renderScale: renderScale
        )
    }

    static func compactPortraitHeight(
        text: String,
        verseFontBase: CGFloat,
        width: CGFloat = 1080,
        minHeightRatio: CGFloat = 0.72,
        breathRatio: CGFloat = compactPortraitBreathRatio,
        verseGapRatio: CGFloat = compactPortraitVerseGapRatio
    ) -> CGFloat {
        // UIFont 精确估算经文块（引号+正文）高度，避免 SwiftUI 弹性布局导致测高不稳定。
        let verseBlock = verseBlockHeight(text: text, base: verseFontBase, width: width)
        let extras = compactPortraitChromeHeight(width: width, breathRatio: breathRatio, verseGapRatio: verseGapRatio)
        return max(verseBlock + extras, width * minHeightRatio)
    }

    static func compactPortraitChromeHeight(
        width: CGFloat = 1080,
        breathRatio: CGFloat = compactPortraitBreathRatio,
        verseGapRatio: CGFloat = compactPortraitVerseGapRatio
    ) -> CGFloat {
        let scale = min(2.5, width / 300.0)
        let edgeBreath = width * breathRatio * 2
        let verseGaps = width * verseGapRatio * 2
        let topDecoration = UIFont.systemFont(ofSize: 10 * scale).lineHeight
        let sourceAttribution = UIFont.systemFont(ofSize: 11 * scale).lineHeight + 6 + 1
        let sourceToBottomDecoration = width * 0.025
        let bottomDecoration = UIFont.systemFont(ofSize: 10 * scale).lineHeight

        return ceil(edgeBreath + verseGaps + topDecoration + sourceAttribution + sourceToBottomDecoration + bottomDecoration)
    }

    /// 用 UIFont 估算长图经文块（行内引号 + 正文）的渲染高度，与 SutraShareCardView 的字号/行距一致。
    /// SwiftUI ImageRenderer 对含弹性元素的视图高度测量不可靠，故用确定性的 NSString 度量替代。
    static func verseBlockHeight(text: String, base: CGFloat, width: CGFloat = 1080) -> CGFloat {
        let scale = min(2.5, width / 300.0)
        let pt = base * scale
        let font = UIFont.systemFont(ofSize: pt, weight: .regular)
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
        let verseH = height("「\(text)」", font)
        let measurementSlack = font.lineHeight + para.lineSpacing
        return ceil(verseH + measurementSlack)
    }

    @MainActor
    private static func renderCompactPortraitBitmap(
        text: String,
        source: String,
        verseFontBase: CGFloat,
        width: CGFloat,
        height: CGFloat,
        breath: CGFloat,
        verseGap: CGFloat,
        renderScale: CGFloat
    ) -> UIImage? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(origin: .zero, size: size)
            drawShareCardBackground(in: context, rect: rect)

            let contentWidth = width * 0.8
            let contentX = width * 0.1
            let scale = min(2.5, width / 300.0)
            let topFont = UIFont.systemFont(ofSize: 10 * scale)
            let bottomFont = UIFont.systemFont(ofSize: 10 * scale)
            let sourceFont = UIFont.systemFont(ofSize: 11 * scale)
            let verseFontSize = verseFontBase * max(0.8, min(scale, 2.5))
            let verseFont = UIFont.systemFont(ofSize: verseFontSize, weight: .regular)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 14 * scale

            let verseAttributes: [NSAttributedString.Key: Any] = [
                .font: verseFont,
                .foregroundColor: SutraDesignTokens.shared.color(for: .sutraText),
                .paragraphStyle: paragraph
            ]
            let verseString = "「\(text)」" as NSString
            let verseTextHeight = ceil(verseString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: verseAttributes,
                context: nil
            ).height)
            let verseBlockHeight = verseTextHeight + verseFont.lineHeight + paragraph.lineSpacing

            var y = breath
            drawCenteredDecoration(in: context, centerY: y + topFont.lineHeight / 2, width: width, lineWidth: width * 0.15, text: "✧", font: topFont, alpha: 0.5)
            y += topFont.lineHeight
            y += verseGap

            verseString.draw(
                with: CGRect(x: contentX, y: y, width: contentWidth, height: verseBlockHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: verseAttributes,
                context: nil
            )
            y += verseBlockHeight
            y += verseGap

            drawSourceAttribution(source, in: context, y: &y, width: width, contentX: contentX, contentWidth: contentWidth, font: sourceFont)
            y += width * 0.025
            drawCenteredDecoration(in: context, centerY: y + bottomFont.lineHeight / 2, width: width, lineWidth: width * 0.1, text: "✧ ❀ ✧", font: bottomFont, alpha: 0.35)

            drawWatermark(in: rect, width: width)
        }
    }

    private static func drawShareCardBackground(in context: CGContext, rect: CGRect) {
        SutraDesignTokens.shared.color(for: .card).setFill()
        context.fill(rect)

        SutraDesignTokens.shared.color(for: .surface).withAlphaComponent(0.3).setFill()
        context.fill(rect)

        let colors = [
            SutraDesignTokens.shared.color(for: .background).withAlphaComponent(0.2).cgColor,
            UIColor.clear.cgColor,
            SutraDesignTokens.shared.color(for: .decorativeGold).withAlphaComponent(0.05).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.55, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    private static func drawCenteredDecoration(
        in context: CGContext,
        centerY: CGFloat,
        width: CGFloat,
        lineWidth: CGFloat,
        text: String,
        font: UIFont,
        alpha: CGFloat
    ) {
        let gold = SutraDesignTokens.shared.color(for: .decorativeGold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: gold.withAlphaComponent(alpha)
        ]
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let centerX = width / 2
        let gap: CGFloat = 8
        let lineColor = gold.withAlphaComponent(0.3).cgColor

        context.setStrokeColor(lineColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: centerX - textSize.width / 2 - gap - lineWidth, y: centerY))
        context.addLine(to: CGPoint(x: centerX - textSize.width / 2 - gap, y: centerY))
        context.move(to: CGPoint(x: centerX + textSize.width / 2 + gap, y: centerY))
        context.addLine(to: CGPoint(x: centerX + textSize.width / 2 + gap + lineWidth, y: centerY))
        context.strokePath()

        (text as NSString).draw(
            at: CGPoint(x: centerX - textSize.width / 2, y: centerY - textSize.height / 2),
            withAttributes: textAttributes
        )
    }

    private static func drawSourceAttribution(
        _ source: String,
        in context: CGContext,
        y: inout CGFloat,
        width: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        font: UIFont
    ) {
        let tertiary = SutraDesignTokens.shared.color(for: .textTertiary)
        let gold = SutraDesignTokens.shared.color(for: .decorativeGold)
        context.setStrokeColor(gold.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: width / 2 - width * 0.1, y: y))
        context.addLine(to: CGPoint(x: width / 2 + width * 0.1, y: y))
        context.strokePath()
        y += 7

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tertiary,
            .paragraphStyle: paragraph,
            .kern: 2
        ]
        let sourceText = "── \(source) ──" as NSString
        sourceText.draw(
            with: CGRect(x: contentX, y: y, width: contentWidth, height: font.lineHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        y += font.lineHeight
    }

    private static func drawWatermark(in rect: CGRect, width: CGFloat) {
        let scale = min(2.5, width / 300.0)
        let font = UIFont.systemFont(ofSize: 8 * max(0.8, min(scale, 2.5)), weight: .ultraLight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: SutraDesignTokens.shared.color(for: .textTertiary).withAlphaComponent(0.2)
        ]
        let watermark = L10n.str("share_card_watermark") as NSString
        let size = watermark.size(withAttributes: attributes)
        watermark.draw(
            at: CGPoint(x: rect.maxX - width * 0.05 - size.width, y: rect.maxY - width * 0.02 - size.height),
            withAttributes: attributes
        )
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
        guard text.count <= maxLongShareImageCharacterCount else {
            return nil
        }

        return renderPlan(text: text, source: source)
    }

    private static func renderPlan(text: String, source: String) -> SutraShareCardRenderPlan? {
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
            renderScale: renderScale,
            compactBreath: 1080 * compactPortraitBreathRatio,
            compactVerseGap: 1080 * compactPortraitVerseGapRatio
        )
    }

    static func paginatedCardPlan(text: String, source: String) -> SutraSharePaginationPlan? {
        guard text.count > maxLongShareImageCharacterCount,
              text.count <= maxPaginatedShareImageCharacterCount else {
            return nil
        }

        let pageTexts = splitText(text, maxCharacters: paginatedShareImageCharacterCount)
        guard pageTexts.count > 1,
              let firstPageText = pageTexts.first,
              let firstPagePlan = renderPlan(text: firstPageText, source: pageSource(source, pageNumber: 1, pageCount: pageTexts.count)) else {
            return nil
        }

        return SutraSharePaginationPlan(text: text, source: source, pageTexts: pageTexts, firstPagePlan: firstPagePlan)
    }

    @MainActor
    static func renderLongCard(plan: SutraShareCardRenderPlan) -> UIImage? {
        return renderCompactPortrait(
            text: plan.text,
            source: plan.source,
            verseFontBase: plan.verseFontBase,
            width: plan.width,
            breathRatio: plan.compactBreath / plan.width,
            verseGapRatio: plan.compactVerseGap / plan.width,
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

    @MainActor
    static func writePaginatedJPEGFiles(plan: SutraSharePaginationPlan) -> [URL] {
        let uniqueSuffix = String(UUID().uuidString.prefix(6))
        var urls: [URL] = []

        for (offset, pageText) in plan.pageTexts.enumerated() {
            let pageNumber = offset + 1
            let pageSource = pageSource(plan.source, pageNumber: pageNumber, pageCount: plan.pageCount)
            guard let pagePlan = renderPlan(text: pageText, source: pageSource),
                  let image = renderLongCard(plan: pagePlan),
                  let imageURL = writeShareJPEG(
                    image: image,
                    source: plan.source,
                    uniqueSuffix: uniqueSuffix,
                    pageNumber: pageNumber,
                    pageCount: plan.pageCount
                  ) else {
                urls.forEach { try? FileManager.default.removeItem(at: $0) }
                return []
            }
            urls.append(imageURL)
        }

        return urls
    }

    static func writeShareJPEG(image: UIImage, source: String? = nil) -> URL? {
        guard let data = image.jpegData(compressionQuality: longShareJPEGQuality) else {
            return nil
        }

        return writeShareFile(data: data, fileName: shareJPEGFileName(source: source))
    }

    static func writeShareJPEG(
        image: UIImage,
        source: String? = nil,
        uniqueSuffix: String,
        pageNumber: Int,
        pageCount: Int
    ) -> URL? {
        guard let data = image.jpegData(compressionQuality: longShareJPEGQuality) else {
            return nil
        }

        return writeShareFile(
            data: data,
            fileName: shareJPEGFileName(
                source: source,
                uniqueSuffix: uniqueSuffix,
                pageNumber: pageNumber,
                pageCount: pageCount
            )
        )
    }

    static func writeShareTextFile(text: String, source: String? = nil) -> URL? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return writeShareFile(data: data, fileName: shareTextFileName(source: source))
    }

    private static func writeShareFile(data: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("LengyanShare", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func shareJPEGFileName(source: String? = nil, uniqueSuffix: String = String(UUID().uuidString.prefix(6))) -> String {
        shareFileName(source: source, descriptor: Book.shared.isSimplifiedChinese ? "分享图" : "分享圖", fileExtension: "jpg", uniqueSuffix: uniqueSuffix)
    }

    static func shareJPEGFileName(source: String? = nil, uniqueSuffix: String, pageNumber: Int, pageCount: Int) -> String {
        let width = max(2, String(pageCount).count)
        let page = String(format: "%0*d-%0*d", width, pageNumber, width, pageCount)
        let descriptor = Book.shared.isSimplifiedChinese ? "分享图-\(page)" : "分享圖-\(page)"
        return shareFileName(source: source, descriptor: descriptor, fileExtension: "jpg", uniqueSuffix: uniqueSuffix)
    }

    static func shareTextFileName(source: String? = nil, uniqueSuffix: String = String(UUID().uuidString.prefix(6))) -> String {
        shareFileName(source: source, descriptor: Book.shared.isSimplifiedChinese ? "经文" : "經文", fileExtension: "txt", uniqueSuffix: uniqueSuffix)
    }

    private static func shareFileName(source: String?, descriptor: String, fileExtension: String, uniqueSuffix: String) -> String {
        let sourceName = sanitizedFileNameComponent(source ?? "")
        let baseName = sourceName.isEmpty ? defaultShareImageBaseName : sourceName

        return "\(baseName)-\(descriptor)-\(uniqueSuffix).\(fileExtension)"
    }

    private static var defaultShareImageBaseName: String {
        Book.shared.isSimplifiedChinese ? "楞严经" : "楞嚴經"
    }

    private static func sanitizedFileNameComponent(_ rawValue: String) -> String {
        let stripped = rawValue
            .replacingOccurrences(of: "《", with: "")
            .replacingOccurrences(of: "》", with: "")
            .replacingOccurrences(of: "「", with: "")
            .replacingOccurrences(of: "」", with: "")

        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:：\n\r\t")
        let cleaned = stripped
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "- "))

        return cleaned
    }

    static func splitText(_ text: String, maxCharacters: Int) -> [String] {
        guard maxCharacters > 0, !text.isEmpty else { return [] }

        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxCharacters, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start..<end]))
            start = end
        }
        return result
    }

    private static func pageSource(_ source: String, pageNumber: Int, pageCount: Int) -> String {
        "\(source) \(pageNumber)/\(pageCount)"
    }

    /// 兼容旧调用：可返回单张长图或分页图。
    @MainActor
    static func renderCards(text: String, source: String) -> [UIImage] {
        if let image = renderLongCard(text: text, source: source) {
            return [image]
        }

        guard let paginationPlan = paginatedCardPlan(text: text, source: source) else {
            return []
        }

        return paginationPlan.pageTexts.enumerated().compactMap { offset, pageText in
            let pageSource = pageSource(source, pageNumber: offset + 1, pageCount: paginationPlan.pageCount)
            guard let plan = renderPlan(text: pageText, source: pageSource) else {
                return nil
            }
            return renderLongCard(plan: plan)
        }
    }

    /// 弹出预览页：可安全生成时展示单张长图；太长则分页图片；极长则只给「分享文字 + 拷贝」。
    @MainActor
    static func presentPreview(text: String, source: String, from vc: UIViewController, barButtonItem: UIBarButtonItem? = nil) {
        let preview: SutraSharePreviewController
        if let plan = longCardRenderPlan(text: text, source: source) {
            preview = SutraSharePreviewController(cardPlan: plan, paginationPlan: nil, fullText: text, longTextHint: nil)
        } else if let paginationPlan = paginatedCardPlan(text: text, source: source) {
            preview = SutraSharePreviewController(
                cardPlan: nil,
                paginationPlan: paginationPlan,
                fullText: text,
                longTextHint: String(format: L10n.str("share_paginated_image_hint_format"), text.count, paginationPlan.pageCount)
            )
        } else {
            preview = SutraSharePreviewController(cardPlan: nil, paginationPlan: nil, fullText: text,
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
    let paginationPlan: SutraSharePaginationPlan?
    var onShareImage: (() -> Void)?
    var onShareText: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?
    /// 非空 = 纯文本模式（长图过大未渲染）：展示提示、隐藏「分享美图」按钮
    var longTextHint: String? = nil

    var body: some View {
        let previewPlan = cardPlan ?? paginationPlan?.firstPagePlan
        let canShareImage = cardPlan != nil || paginationPlan != nil

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

            if let previewPlan {
                GeometryReader { proxy in
                    ScrollView {
                        let previewWidth = min(previewPlan.width, max(240, proxy.size.width - 48))
                        let previewScale = previewWidth / previewPlan.width
                        let previewHeight = max(1, previewPlan.height * previewScale)

                        VStack(spacing: 12) {
                            HStack {
                                Spacer(minLength: 0)
                                ZStack(alignment: .topLeading) {
                                    SutraShareCardView(
                                        text: previewPlan.text,
                                        source: previewPlan.source,
                                        template: .portrait,
                                        verseFontBase: previewPlan.verseFontBase,
                                        compact: true,
                                        compactBreath: previewPlan.compactBreath,
                                        compactVerseGap: previewPlan.compactVerseGap
                                    )
                                    .frame(width: previewPlan.width, height: previewPlan.height)
                                    .scaleEffect(previewScale, anchor: .topLeading)
                                }
                                .frame(width: previewWidth, height: previewHeight, alignment: .topLeading)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(uiColor: SutraDesignTokens.shared.color(for: .divider)).opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                                Spacer(minLength: 0)
                            }

                            if let longTextHint {
                                Text(longTextHint)
                                    .font(.system(size: 13, weight: .regular, design: .serif))
                                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
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
                if canShareImage {
                    actionButton(title: L10n.str("share_image"), systemName: "photo", action: { onShareImage?() }, primary: true)
                }
                actionButton(title: L10n.str("share_text"), systemName: "text.alignleft", action: { onShareText?() }, primary: !canShareImage)
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
    private let paginationPlan: SutraSharePaginationPlan?
    private let fullText: String
    private var temporaryShareURLs: [URL] = []

    init(cardPlan: SutraShareCardRenderPlan?, paginationPlan: SutraSharePaginationPlan?, fullText: String, longTextHint: String? = nil) {
        self.cardPlan = cardPlan
        self.paginationPlan = paginationPlan
        self.fullText = fullText
        super.init(rootView: SutraSharePreviewView(cardPlan: cardPlan, paginationPlan: paginationPlan, longTextHint: longTextHint))
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
        if let paginationPlan {
            let urls = SutraCardRenderer.writePaginatedJPEGFiles(plan: paginationPlan)
            guard !urls.isEmpty else {
                presentActivity([fullText])
                return
            }

            temporaryShareURLs.append(contentsOf: urls)
            presentActivity(urls)
            return
        }

        guard let cardPlan,
              let image = SutraCardRenderer.renderLongCard(plan: cardPlan),
              let imageURL = SutraCardRenderer.writeShareJPEG(image: image, source: cardPlan.source) else {
            presentActivity([fullText])
            return
        }

        temporaryShareURLs.append(imageURL)
        presentActivity([imageURL])
    }
    private func shareText() {
        let source = cardPlan?.source ?? paginationPlan?.source
        guard let textURL = SutraCardRenderer.writeShareTextFile(text: fullText, source: source) else {
            presentActivity([fullText])
            return
        }

        temporaryShareURLs.append(textURL)
        presentActivity([textURL])
    }

    private func copyText() {
        UIPasteboard.general.string = fullText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss(animated: true)
    }
}
