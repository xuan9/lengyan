//
//  DesignSystem+Spacing.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - 禅意间距系统 - Web Design System Migration
/// Zen Spacing System - 禅意极简主义
/// Optimized spacing based on web design system (基础间距: 4px)
public struct SutraSpacing {

    // MARK: - Base Spacing - 基础间距 (from 设计系统总结.md)
    /// Web Design System: 基础间距: 4px (0.25rem)
    public struct Base {
        public static let xs: CGFloat = 4    // 基础间距: 4px (0.25rem)
        public static let sm: CGFloat = 8    // 小间距: 8px (0.5rem) - 按钮内边距
        public static let md: CGFloat = 16   // 中间距: 16px (1rem) - 段落间距
        public static let lg: CGFloat = 24   // 大间距: 24px (1.5rem) - 组件间距
        public static let xl: CGFloat = 32   // 超大间距: 32px (2rem) - 区块间距
        public static let xxl: CGFloat = 48  // 章节间距
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

    // MARK: - Zen Layout Spacing - 禅意布局间距
    /// Web Design System: 70% 禅雾灰 + 20% 禅纸白 + 10% 禅竹绿
    /// Traditional Zen layout proportions based on web design principles
    public struct Zen {
        public static let cardPadding: CGFloat = 28           // 卡片内边距（增强呼吸感）
        public static let cardMargin: CGFloat = 16            // 卡片外边距
        public static let contentMargin: CGFloat = 24         // 内容边距（增强呼吸感）
        public static let navigationHeight: CGFloat = 56      // 导航栏高度
        public static let tabBarHeight: CGFloat = 64          // 标签栏高度
    }

    // MARK: - Touch Target Spacing (Mobile UX)
    /// iOS-compliant touch targets for better mobile experience
    public struct Touch {
        public static let minimum: CGFloat = 44               // iOS minimum
        public static let comfortable: CGFloat = 48           // Comfortable touch
        public static let spacing: CGFloat = 12               // Touch element spacing
    }
}
