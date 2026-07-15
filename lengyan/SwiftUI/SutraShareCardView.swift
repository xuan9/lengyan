//
//  SutraShareCardView.swift
//  lengyan
//
//  经文分享卡片 — 增长飞轮的分享引擎
//  隐喻：印赠经文，传播善知识
//  三种模板：竖版(朋友圈) / 方形(小红书) / 横版(微博)
//

import SwiftUI

/// 分享卡片模板
enum ShareCardTemplate: String, CaseIterable {
    case portrait  = "竖版禅意"   // 9:16
    case square    = "方形卡片"   // 1:1
    case landscape = "横版金句"   // 16:9

    var aspectRatio: CGFloat {
        switch self {
        case .portrait:  return 9.0 / 16.0
        case .square:    return 1.0
        case .landscape: return 16.0 / 9.0
        }
    }

    var renderSize: CGSize {
        switch self {
        case .portrait:  return CGSize(width: 1080, height: 1920)
        case .square:    return CGSize(width: 1080, height: 1080)
        case .landscape: return CGSize(width: 1920, height: 1080)
        }
    }

    var icon: String {
        switch self {
        case .portrait:  return "rectangle.portrait"
        case .square:    return "square"
        case .landscape: return "rectangle"
        }
    }
}

/// 分享卡片 SwiftUI 视图
/// 设计：宣纸纹理 + 楷体排版 + 微妙水印
struct SutraShareCardView: View {
    let text: String
    let source: String
    let template: ShareCardTemplate
    /// 经文正文字号基准（由渲染器按文字长度自适应传入：短句大、长文小）
    var verseFontBase: CGFloat = 22
    /// 紧凑模式：单张短/中经文用——竖版宽度不变、高度随内容收缩，消除 9:16 画框的上下尴尬留白。
    /// 间距改以宽度为基准（不依赖高度），并无 GeometryReader，便于高度自适应。
    var compact: Bool = false
    /// 紧凑模式上下边缘留白高度（由渲染器按测量出的内容高度计算传入）
    var compactBreath: CGFloat = 0
    /// 紧凑模式经文块上下间距。必须是固定值，避免长图预览/导出出现大片空白。
    var compactVerseGap: CGFloat = 0

    var body: some View {
        if compact {
            compactBody
        } else {
            GeometryReader { geo in
                ZStack {
                    // 背景
                    cardBackground

                    // 内容布局
                    cardContent(size: geo.size)

                    // 水印
                    watermark(size: geo.size)
                }
            }
            .aspectRatio(template.aspectRatio, contentMode: .fit)
        }
    }

    /// 紧凑模式渲染：固定宽度 1080、无 GeometryReader，高度由内容撑开（由渲染器加 frame 定最终高度）。
    /// watermark 用 overlay 贴右下——不进 ZStack，避免其 Spacer/maxHeight 撑破自然高度测量。
    private var compactBody: some View {
        let size = CGSize(width: 1080, height: 1080)
        return ZStack(alignment: .top) {
            cardBackground
            cardContent(size: size)
        }
        .frame(width: 1080)
        .overlay(watermark(size: size), alignment: .bottomTrailing)
    }

    /// 紧凑模式上下边缘留白：固定高度（compactBreath），避免弹性 Spacer 使自然高度不可测；
    /// 固定模板仍用弹性 Spacer 撑满 9:16 画框。
    @ViewBuilder
    private var edgeSpacer: some View {
        if compact { Color.clear.frame(height: compactBreath) } else { Spacer() }
    }

    /// 经文上下留白：弹性 minHeight，短句时撑开让经文居中、长文时自动收紧
    @ViewBuilder
    private func verseEdgeGap(size: CGSize) -> some View {
        if compact {
            Color.clear.frame(height: compactVerseGap)
        } else {
            Spacer().frame(minHeight: ratio(size, 0.05))
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            // 底色
            Rectangle()
                .fill(SutraDesignSystem.color(.card))

            // 宣纸纹理模拟
            Rectangle()
                .fill(SutraDesignSystem.color(.surface).opacity(0.3))

            // 微妙渐变
            LinearGradient(
                colors: [
                    SutraDesignSystem.color(.background).opacity(0.2),
                    .clear,
                    SutraDesignSystem.color(.decorativeGold).opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Content

    private func cardContent(size: CGSize) -> some View {
        VStack(spacing: 0) {
            // 页眉：上边距 + 顶饰（固定在顶）
            edgeSpacer
            topDecoration(size: size)

            // 经文主体：上下留白将其推至视觉中部；内容多时弹性自动收紧、短句撑开居中
            verseEdgeGap(size: size)
            verseContent(size: size)
            verseEdgeGap(size: size)

            // 页脚：来源 + 底饰紧凑成组，贴下边距（normal page footer）
            sourceAttribution(size: size)
            Spacer().frame(height: ratio(size, 0.025))
            bottomDecoration(size: size)
            edgeSpacer
        }
        .padding(.horizontal, size.width * 0.1)
    }

    // MARK: - Top Decoration

    private func topDecoration(size: CGSize) -> some View {
        HStack(spacing: 8) {
            decorativeLine(width: size.width * 0.15)
            Text("✧")
                .font(.system(size: fontSize(for: size, base: 10)))
                .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.5))
            decorativeLine(width: size.width * 0.15)
        }
    }

    // MARK: - Verse Content

    @ViewBuilder
    private func verseContent(size: CGSize) -> some View {
        if compact {
            Text("「\(text)」")
                .font(shareFont(size: size))
                .foregroundColor(SutraDesignSystem.color(.sutraText))
                .lineSpacing(fontSize(for: size, base: 14))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: ratio(size, 0.02)) {
                // 开引号
                HStack {
                    Text("「")
                        .font(.system(size: fontSize(for: size, base: 32), weight: .ultraLight))
                        .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.5))
                    Spacer()
                }

                // 经文
                Text(text)
                    .font(shareFont(size: size))
                    .foregroundColor(SutraDesignSystem.color(.sutraText))
                    .lineSpacing(fontSize(for: size, base: 14))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)

                // 闭引号
                HStack {
                    Spacer()
                    Text("」")
                        .font(.system(size: fontSize(for: size, base: 32), weight: .ultraLight))
                        .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.5))
                }
            }
        }
    }

    // MARK: - Source Attribution

    private func sourceAttribution(size: CGSize) -> some View {
        VStack(spacing: 6) {
            decorativeLine(width: size.width * 0.2)
            Text("── \(source) ──")
                .font(.system(size: fontSize(for: size, base: 11), weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))
                .tracking(2)
        }
    }

    // MARK: - Bottom Decoration

    private func bottomDecoration(size: CGSize) -> some View {
        HStack(spacing: 6) {
            decorativeLine(width: size.width * 0.1)
            Text("✧ ❀ ✧")
                .font(.system(size: fontSize(for: size, base: 10)))
                .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.35))
            decorativeLine(width: size.width * 0.1)
        }
    }

    // MARK: - Watermark

    private func watermark(size: CGSize) -> some View {
        let mark = Text(L10n.str("share_card_watermark"))
            .font(.system(size: fontSize(for: size, base: 8), weight: .ultraLight))
            .foregroundColor(SutraDesignSystem.color(.textTertiary).opacity(0.2))
            .padding(.trailing, size.width * 0.05)
            .padding(.bottom, ratio(size, 0.02))
        // 紧凑模式：返回纯标记（不带 maxHeight frame，否则会撑破自然高度测量），由 compactBody 用 overlay 贴右下
        if compact {
            return AnyView(mark)
        } else {
            return AnyView(VStack { Spacer(); HStack { Spacer(); mark } })
        }
    }

    // MARK: - Helpers

    private func decorativeLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(SutraDesignSystem.color(.decorativeGold).opacity(0.3))
            .frame(width: width, height: 0.5)
    }

    private func fontSize(for size: CGSize, base: CGFloat) -> CGFloat {
        // 以宽度为基准：固定模板（min 即取宽）与紧凑模式（高度自适应）下都稳定一致
        let scale = size.width / 300.0
        return base * max(0.8, min(scale, 2.5))
    }

    /// 段间间距基准：固定模板沿用高度比例（原视觉不变），紧凑模式用宽度比例（不依赖自适应高度）
    private func ratio(_ size: CGSize, _ v: CGFloat) -> CGFloat {
        compact ? size.width * v : size.height * v
    }

    private func shareFont(size: CGSize) -> Font {
        let sz = fontSize(for: size, base: verseFontBase)
        if compact {
            return .system(size: sz, weight: .regular)
        }
        // 优先楷体
        if let _ = UIFont(name: "STKaiti", size: sz) {
            return .custom("STKaiti", size: sz)
        }
        return .system(size: sz, weight: .regular)
    }
}
