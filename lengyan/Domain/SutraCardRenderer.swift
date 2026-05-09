//
//  SutraCardRenderer.swift
//  lengyan
//
//  分享卡片渲染引擎 — SwiftUI View → UIImage
//  支持 iOS 16+ ImageRenderer，iOS 15 fallback
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
        template: ShareCardTemplate = .portrait
    ) -> UIImage? {
        let size = template.renderSize
        let view = SutraShareCardView(text: text, source: source, template: template)
            .frame(width: size.width, height: size.height)

        if #available(iOS 16.0, *) {
            return renderWithImageRenderer(view: view, size: size)
        } else {
            return renderWithUIGraphics(view: view, size: size)
        }
    }

    /// 使用默认竖版模板快速渲染（零摩擦分享路径）
    @MainActor
    static func renderDefault(text: String, source: String) -> UIImage? {
        return render(text: text, source: source, template: .portrait)
    }

    // MARK: - iOS 16+ Renderer

    @available(iOS 16.0, *)
    @MainActor
    private static func renderWithImageRenderer<V: View>(view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0  // 2x 对于分享图足够清晰
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage
    }

    // MARK: - iOS 15 Fallback

    @MainActor
    private static func renderWithUIGraphics<V: View>(view: V, size: CGSize) -> UIImage? {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .clear

        // Force layout
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
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
