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

    var body: some View {
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
            Spacer()

            // 顶部装饰
            topDecoration(size: size)

            Spacer().frame(height: size.height * 0.06)

            // 经文正文
            verseContent(size: size)

            Spacer().frame(height: size.height * 0.04)

            // 来源标注
            sourceAttribution(size: size)

            Spacer()

            // 底部装饰
            bottomDecoration(size: size)

            Spacer().frame(height: size.height * 0.05)
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

    private func verseContent(size: CGSize) -> some View {
        VStack(spacing: size.height * 0.02) {
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

            // 闭引号
            HStack {
                Spacer()
                Text("」")
                    .font(.system(size: fontSize(for: size, base: 32), weight: .ultraLight))
                    .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.5))
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
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("楞严")
                    .font(.system(size: fontSize(for: size, base: 8), weight: .ultraLight))
                    .foregroundColor(SutraDesignSystem.color(.textTertiary).opacity(0.2))
                    .padding(.trailing, size.width * 0.05)
                    .padding(.bottom, size.height * 0.02)
            }
        }
    }

    // MARK: - Helpers

    private func decorativeLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(SutraDesignSystem.color(.decorativeGold).opacity(0.3))
            .frame(width: width, height: 0.5)
    }

    private func fontSize(for size: CGSize, base: CGFloat) -> CGFloat {
        let scale = min(size.width, size.height) / 300.0
        return base * max(0.8, min(scale, 2.5))
    }

    private func shareFont(size: CGSize) -> Font {
        let sz = fontSize(for: size, base: verseFontBase)
        // 优先楷体
        if let _ = UIFont(name: "STKaiti", size: sz) {
            return .custom("STKaiti", size: sz)
        }
        return .system(size: sz, weight: .regular)
    }
}
