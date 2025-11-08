//
//  DesignSystem+Spacing.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Enhanced Zen Spacing System
/// Optimized spacing for Chinese text readability and Zen aesthetics
/// Based on traditional Chinese book layout principles
public struct SutraSpacing {

    // MARK: - Base Spacing
    /// Essential spacing values optimized for Chinese reading
    public struct Base {
        public static let xs: CGFloat = 4    // Micro spacing
        public static let sm: CGFloat = 8    // Small spacing
        public static let md: CGFloat = 16   // Medium spacing (increased for Chinese)
        public static let lg: CGFloat = 24   // Large spacing (increased for readability)
        public static let xl: CGFloat = 32   // Extra large spacing
        public static let xxl: CGFloat = 48  // Section spacing
    }

    // MARK: - Chinese Reading Specific Spacing
    /// Specialized spacing for sutra content and Chinese typography
    public struct Reading {
        public static let characterSpacing: CGFloat = 1.0      // Character spacing for Chinese
        public static let lineHeight: CGFloat = 1.8            // Line height for Chinese text
        public static let paragraphSpacing: CGFloat = 20       // Paragraph spacing
        public static let sectionSpacing: CGFloat = 32         // Section spacing
        public static let chapterSpacing: CGFloat = 48         // Chapter spacing
    }

    // MARK: - Zen Layout Spacing
    /// Traditional Zen layout proportions based on Golden Ratio
    public struct Zen {
        public static let cardPadding: CGFloat = 24           // Card padding
        public static let cardMargin: CGFloat = 16            // Card margin
        public static let contentMargin: CGFloat = 20         // Content margin
        public static let navigationHeight: CGFloat = 56      // Navigation height
        public static let tabBarHeight: CGFloat = 64          // Tab bar height
    }

    // MARK: - Touch Target Spacing (Mobile UX)
    /// iOS-compliant touch targets for better mobile experience
    public struct Touch {
        public static let minimum: CGFloat = 44               // iOS minimum
        public static let comfortable: CGFloat = 48           // Comfortable touch
        public static let spacing: CGFloat = 12               // Touch element spacing
    }
}
