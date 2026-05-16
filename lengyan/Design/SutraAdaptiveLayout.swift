import UIKit
import SwiftUI

/// 统一布局适配层 — 基于 Apple HIG 的原生 Readable Content Guide，不使用硬编码常量限制 View 宽高。
/// 让所有的视图自然而优雅地适配 iPad 大屏幕和多任务视窗。
enum SutraAdaptiveLayout {

    // MARK: - 核心常量
    /// Apple HIG 推荐的舒适阅读上限（用于计算或 SwiftUI 回退时）
    static let optimalReadingWidth: CGFloat = 680
    static let homeContentWidth: CGFloat = 720

    // MARK: - UIKit 约束

    /// 返回一个适用于全屏阅读视图的布局约束。将视图撑满屏幕，并配合内部的 textContainerInset 
    /// 或 contentInset 使用，确保滚动条贴近屏幕边缘，同时保持全屏幕响应滑动。
    static func fullScreenConstraints(
        for view: UIView,
        in guide: UILayoutGuide
    ) -> [NSLayoutConstraint] {
        return [
            view.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            view.topAnchor.constraint(equalTo: guide.topAnchor),
            view.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ]
    }

    /// 动态计算需要的水平内边距 (textContainerInset 或 contentInset 使用)，
    /// 确保内部文字等核心内容居中且不超过 maxWidth，同时让底层 ScrollView 撑满全屏。
    static func readingHorizontalInsets(
        containerWidth: CGFloat,
        maxWidth: CGFloat = optimalReadingWidth,
        minMargin: CGFloat = 20
    ) -> CGFloat {
        if containerWidth > maxWidth {
            return floor((containerWidth - maxWidth) / 2)
        }
        return minMargin
    }

    // MARK: - 导航与交互

    /// 是否应使用分栏导航
    static func shouldUseSplitNavigation(for trait: UITraitCollection) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// 是否应使用 sheet 而非 fullScreen modal
    static func shouldUseSheetModal(for trait: UITraitCollection) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - SwiftUI ViewModifier

extension View {
    /// 限制内部内容的阅读宽度，同时允许外层（如 ScrollView）撑满全屏。
    /// 请将此 Modifier 添加到 ScrollView 的**内部**内容视图上，而不是 ScrollView 本身，
    /// 这样能保证 ScrollView 的滚动条依旧贴在屏幕最边缘，而内容完美居中。
    func readingContentWidth() -> some View {
        modifier(ReadingContentWidthModifier())
    }
}

private struct ReadingContentWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                // 限制内容的最大宽度
                .frame(maxWidth: SutraAdaptiveLayout.optimalReadingWidth)
                // 用一个无形的外框将其撑开并居中，这样父视图（如 ScrollView）就不会被压缩
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}
