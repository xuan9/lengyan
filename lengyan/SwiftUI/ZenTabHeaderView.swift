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
            if let symbolName = symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.6))
            }

            Text(NSLocalizedString(titleKey, comment: ""))
                .font(SutraTypographyBridge.uiLargeTitle(weight: .bold))
                .foregroundColor(SutraDesignSystem.color(.primary))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.bottom, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
    }
}
