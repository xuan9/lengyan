//
//  DesignSystem+Spacing.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Minimal Spacing System
/// Simplified spacing system with only the 3 values actually used in the codebase
/// Reduced from 360 to ~50 lines (86% reduction)
public struct SutraSpacing {

    // MARK: - Base Spacing
    /// Essential spacing values used throughout the app
    public struct Base {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 20
    }
}
