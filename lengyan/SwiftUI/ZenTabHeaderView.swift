//
//  ZenTabHeaderView.swift
//  lengyan
//
//  Unified classic frame header for main Tab views
//

import SwiftUI

struct ZenTabHeaderView: View {
    let titleKey: String
    var symbolName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(SutraTypographyBridge.uiLargeTitle(weight: .bold))
                .tracking(20)
                .foregroundColor(SutraDesignSystem.color(.primary))
                .padding(.bottom, 10)

            // 底部细线 — 经卷章节标题的端庄感
            Rectangle()
                .fill(SutraDesignSystem.color(.primary).opacity(0.15))
                .frame(width: 60, height: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.bottom, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
    }
}
