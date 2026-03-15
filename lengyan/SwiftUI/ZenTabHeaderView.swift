//
//  ZenTabHeaderView.swift
//  lengyan
//
//  Unified classic frame header for main Tab views
//

import SwiftUI

struct ZenTabHeaderView: View {
    let titleKey: String
    /// SF Symbol name, displayed above the title in gold as a contextual icon
    var symbolName: String? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingSM)) {
            // 🔱 小图标 — 用于区分 Tab 类别，自然融入当前场景语境
            if let symbolName = symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))
            }

            // 主标题 — 鎏金色，粗体
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(SutraTypographyBridge.uiLargeTitle(weight: .bold))
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .chapterTitle)))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.bottom, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
    }
}
