import UIKit
import SwiftUI

/// 统一布局适配层 — 基于 Apple HIG 的原生 Readable Content Guide，不使用硬编码常量限制 View 宽高。
/// 让所有的视图自然而优雅地适配 iPad 大屏幕和多任务视窗。
enum SutraAdaptiveLayout {

    // MARK: - 核心常量
    /// Apple HIG 推荐的舒适阅读上限（用于计算或 SwiftUI 回退时）
    static let optimalReadingWidth: CGFloat = 680
    /// Slightly wider than the reading column so the chapter grid can breathe
    /// while any extra toolbar width flows to the potentially long resume title.
    static let homeContentWidth: CGFloat = 768
    /// 横屏阅读上限：iPad 横屏时放宽经文宽度，减少两侧留白空洞感
    static let landscapeReadingWidth: CGFloat = 960

    /// 听经目录在横屏和普通窗口中保持原有的紧凑节奏；只有 iPad 的高屏窗口
    /// 才逐步增加行高，利用竖向空间而不放大已经足够清晰的 20pt 列表文字。
    /// 这里使用宽高差连续插值，不按 orientation 硬切，旋转和分屏缩放时不会跳版。
    static func audioTrackRowHeight(
        containerSize: CGSize,
        deviceIdiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> CGFloat {
        let compactHeight: CGFloat = 52
        guard deviceIdiom == .pad else { return compactHeight }

        let tallWindowDifference = max(containerSize.height - containerSize.width, 0)
        let tallWindowProgress = min(tallWindowDifference / 280, 1)
        let largeIPadProgress = min(max(containerSize.height - 1_120, 0) / 100, 1)
        return compactHeight + 10 * tallWindowProgress + 6 * largeIPadProgress
    }

    /// 根据容器尺寸判断是否横屏宽屏（宽度大于高度，且足够宽）
    static func isWideLandscape(containerWidth: CGFloat, containerHeight: CGFloat) -> Bool {
        return containerWidth > containerHeight && containerWidth >= 1024
    }

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
    /// 横屏宽屏时自动放宽至 landscapeReadingWidth，减少 iPad 横屏留白空洞。
    static func readingHorizontalInsets(
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        maxWidth: CGFloat = optimalReadingWidth,
        minMargin: CGFloat = 20
    ) -> CGFloat {
        let effectiveWidth = isWideLandscape(containerWidth: containerWidth, containerHeight: containerHeight)
            ? max(maxWidth, landscapeReadingWidth)
            : maxWidth
        if containerWidth > effectiveWidth {
            return floor((containerWidth - effectiveWidth) / 2)
        }
        return minMargin
    }

    /// Home content stays compact in portrait and expands only in a genuinely
    /// wide landscape window. Requiring the complete size prevents a tall
    /// 13-inch iPad from being mistaken for landscape when height is omitted.
    static func homeHorizontalInsets(containerSize: CGSize) -> CGFloat {
        readingHorizontalInsets(
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            maxWidth: homeContentWidth,
            minMargin: 0
        )
    }

    /// Splits the compact/two-row home actions into a flexible primary column
    /// and a content-sized trailing column while preserving the shared outer
    /// edges used by the chapter grid.
    static func homeTwoRowActionWidths(
        availableWidth: CGFloat,
        columnGap: CGFloat,
        preferredTrailingWidth: CGFloat,
        minimumTapWidth: CGFloat = 44
    ) -> (primary: CGFloat, trailing: CGFloat) {
        let maximumTrailingWidth = max(
            minimumTapWidth,
            availableWidth - columnGap - minimumTapWidth
        )
        let trailingWidth = min(
            max(minimumTapWidth, preferredTrailingWidth),
            maximumTrailingWidth
        )
        let primaryWidth = max(
            minimumTapWidth,
            availableWidth - columnGap - trailingWidth
        )
        return (primaryWidth, trailingWidth)
    }

    /// In the iPad single-row toolbar, listening has a predictable compact
    /// label while the outline resume target can be much longer. Give listening
    /// its intrinsic width (within a cap) and let resume absorb the remainder.
    static func homeSingleRowPrimaryWidths(
        availableWidth: CGFloat,
        reservedWidth: CGFloat,
        preferredListeningWidth: CGFloat,
        minimumTapWidth: CGFloat = 44,
        maximumListeningFraction: CGFloat = 0.45
    ) -> (resume: CGFloat, listening: CGFloat) {
        let flexibleWidth = max(availableWidth - reservedWidth, 0)
        guard flexibleWidth > 0 else { return (0, 0) }

        let minimumWidth = min(
            max(minimumTapWidth, 0),
            flexibleWidth / 2
        )
        let fraction = min(max(maximumListeningFraction, 0), 1)
        let maximumListeningWidth = min(
            max(minimumWidth, flexibleWidth * fraction),
            max(flexibleWidth - minimumWidth, minimumWidth)
        )
        let listeningWidth = min(
            max(preferredListeningWidth, minimumWidth),
            maximumListeningWidth
        )
        let resumeWidth = max(flexibleWidth - listeningWidth, minimumWidth)
        return (resumeWidth, listeningWidth)
    }

    /// Uses the resume slot only as far as its content needs. A long outline
    /// keeps the full slot and truncates at the available edge. Once resume is
    /// complete, spare width first finishes listening and then expands all
    /// three gaps equally, avoiding one oversized invisible button.
    static func homeSingleRowContentDistribution(
        maximumResumeWidth: CGFloat,
        initialListeningWidth: CGFloat,
        preferredResumeWidth: CGFloat,
        preferredListeningWidth: CGFloat,
        minimumTapWidth: CGFloat = 44,
        minimumGap: CGFloat = 8
    ) -> (resume: CGFloat, listening: CGFloat, gap: CGFloat) {
        let capacity = maximumResumeWidth.isFinite
            ? max(maximumResumeWidth, 0)
            : 0
        let listeningWidth = initialListeningWidth.isFinite
            ? max(initialListeningWidth, 0)
            : 0
        let resumePreference = preferredResumeWidth.isFinite
            ? max(preferredResumeWidth, 0)
            : 0
        let listeningPreference = preferredListeningWidth.isFinite
            ? max(preferredListeningWidth, 0)
            : 0
        let minimumWidth = min(max(minimumTapWidth, 0), capacity)
        let resumeWidth = min(
            max(resumePreference, minimumWidth),
            capacity
        )
        var unusedWidth = max(capacity - resumeWidth, 0)
        let listeningIncrease = min(
            max(listeningPreference - listeningWidth, 0),
            unusedWidth
        )
        unusedWidth -= listeningIncrease
        let gap = max(minimumGap, 0) + unusedWidth / 3
        return (
            resumeWidth,
            listeningWidth + listeningIncrease,
            gap
        )
    }

    /// A two-line opening verse needs both font line boxes plus the explicit
    /// paragraph spacing. The fixed minimum preserves the existing iPad rhythm.
    static func homeOpeningVerseHeight(
        fontLineHeight: CGFloat,
        lineSpacing: CGFloat,
        minimumHeight: CGFloat
    ) -> CGFloat {
        max(
            minimumHeight,
            ceil(max(fontLineHeight, 0) * 2 + max(lineSpacing, 0))
        )
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
