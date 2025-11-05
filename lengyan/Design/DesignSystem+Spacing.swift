//
//  DesignSystem+Spacing.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Spacing System
public struct SutraSpacing {

    // MARK: - Base Grid System (8pt grid)
    public struct Grid {
        public static let base: CGFloat = 8.0
        public static let half: CGFloat = base / 2      // 4pt
        public static let quarter: CGFloat = base / 4   // 2pt
    }

    // MARK: - Golden Ratio Spacing Scale
    // Using golden ratio (1.618) to create harmonious proportions
    private static let φ: CGFloat = 1.618

    // MARK: - Micro Spacing (0-8pt)
    public struct Micro {
        public static let xxxs: CGFloat = Grid.quarter          // 2pt
        public static let xxs: CGFloat = Grid.half              // 4pt
        public static let xs: CGFloat = Grid.base * 0.75        // 6pt
        public static let sm: CGFloat = Grid.base               // 8pt
    }

    // MARK: - Base Spacing (8-24pt)
    public struct Base {
        public static let sm: CGFloat = Grid.base                    // 8pt
        public static let base: CGFloat = Grid.base                    // 8pt
        public static let md: CGFloat = Grid.base * φ                  // 12.9pt → 12pt
        public static let lg: CGFloat = Grid.base * φ * φ              // 20.9pt → 20pt
        public static let xl: CGFloat = Grid.base * 3                  // 24pt
    }

    // MARK: - Component Spacing (24-64pt)
    public struct Component {
        public static let sm: CGFloat = Grid.base * 3                  // 24pt
        public static let md: CGFloat = Grid.base * 4                  // 32pt
        public static let lg: CGFloat = Grid.base * 5                  // 40pt
        public static let xl: CGFloat = Grid.base * 6                  // 48pt
        public static let xxl: CGFloat = Grid.base * 8                 // 64pt
    }

    // MARK: - Section Spacing (64-128pt)
    public struct Section {
        public static let sm: CGFloat = Grid.base * 8                  // 64pt
        public static let md: CGFloat = Grid.base * 10                 // 80pt
        public static let lg: CGFloat = Grid.base * 12                 // 96pt
        public static let xl: CGFloat = Grid.base * 14                 // 112pt
        public static let xxl: CGFloat = Grid.base * 16                // 128pt
    }

    // MARK: - Screen-level Spacing (128pt+)
    public struct Screen {
        public static let sm: CGFloat = Grid.base * 16                 // 128pt
        public static let md: CGFloat = Grid.base * 20                 // 160pt
        public static let lg: CGFloat = Grid.base * 24                 // 192pt
        public static let xl: CGFloat = Grid.base * 32                 // 256pt
    }

    // MARK: - Content-Specific Spacing
    public struct Content {
        // Text spacing for sutra content
        public static let sutraLineSpacing: CGFloat = Base.md          // 12pt between lines
        public static let sutraParagraphSpacing: CGFloat = Base.lg     // 20pt between paragraphs
        public static let sutraChapterSpacing: CGFloat = Component.xl  // 48pt between chapters

        // Commentary spacing
        public static let commentaryLineSpacing: CGFloat = Base.md      // 12pt
        public static let commentaryParagraphSpacing: CGFloat = Base.md // 12pt
        public static let sutraToCommentaryGap: CGFloat = Base.lg      // 20pt gap

        // Index and navigation spacing
        public static let indexItemSpacing: CGFloat = Base.md          // 12pt
        public static let indexSectionSpacing: CGFloat = Component.sm   // 24pt
        public static let navigationItemSpacing: CGFloat = Base.sm      // 8pt
    }

    // MARK: - UI Element Spacing
    public struct UIElement {
        // Button spacing
        public static let buttonHorizontalPadding: CGFloat = Base.md   // 12pt
        public static let buttonVerticalPadding: CGFloat = Base.sm     // 8pt
        public static let buttonSpacing: CGFloat = Base.sm             // 8pt between buttons
        public static let buttonGroupSpacing: CGFloat = Base.md        // 12pt between groups

        // Card spacing
        public static let cardPadding: CGFloat = Base.md               // 12pt
        public static let cardSpacing: CGFloat = Base.md               // 12pt between cards
        public static let cardMargin: CGFloat = Base.sm                // 8pt margin

        // Toolbar spacing
        public static let toolbarHeight: CGFloat = Component.sm        // 24pt height
        public static let toolbarPadding: CGFloat = Base.sm            // 8pt padding
        public static let toolbarItemSpacing: CGFloat = Base.md        // 12pt between items

        // Navigation spacing
        public static let navigationHeight: CGFloat = Component.sm     // 24pt
        public static let navigationPadding: CGFloat = Base.md         // 12pt
        public static let navigationTitleMargin: CGFloat = Base.sm     // 8pt

        // Tab bar spacing
        public static let tabBarHeight: CGFloat = Component.sm         // 24pt
        public static let tabBarPadding: CGFloat = Base.sm             // 8pt
    }

    // MARK: - Responsive Spacing
    public struct Responsive {
        // Screen size breakpoints
        public struct Breakpoint {
            public static let small: CGFloat = 375    // iPhone SE
            public static let medium: CGFloat = 414   // iPhone Pro
            public static let large: CGFloat = 768    // iPad
            public static let xlarge: CGFloat = 1024  // iPad Pro
        }

        // Dynamic spacing based on screen size
        public static func spacing(for baseSpacing: CGFloat,
                                  screenWidth: CGFloat) -> CGFloat {
            switch screenWidth {
            case 0..<Breakpoint.small:
                return baseSpacing * 0.875   // Reduce by 12.5%
            case Breakpoint.small..<Breakpoint.medium:
                return baseSpacing             // Keep base spacing
            case Breakpoint.medium..<Breakpoint.large:
                return baseSpacing * 1.125     // Increase by 12.5%
            default:
                return baseSpacing * 1.25      // Increase by 25%
            }
        }

        // Safe area insets for different devices
        public static func safeAreaInsets(for screenBounds: CGRect) -> UIEdgeInsets {
            // These would be automatically calculated by iOS, but we provide defaults
            let topInset: CGFloat
            let bottomInset: CGFloat

            if screenBounds.height >= 812 { // iPhone X and larger
                topInset = 44
                bottomInset = 34
            } else {
                topInset = 20
                bottomInset = 0
            }

            return UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        }
    }

    // MARK: - Layout Margins
    public struct Margins {
        // Standard margins for different container types
        public static let narrow: CGFloat = Base.sm                    // 8pt
        public static let standard: CGFloat = Base.md                  // 12pt
        public static let wide: CGFloat = Base.lg                      // 20pt
        public static let extraWide: CGFloat = Component.sm            // 24pt

        // Reading margins for comfortable sutra reading
        public static let readingMargin: CGFloat = Component.lg        // 40pt
        public static let compactReadingMargin: CGFloat = Base.xl      // 24pt

        // Dynamic margins based on screen width
        public static func readingMargin(for screenWidth: CGFloat) -> CGFloat {
            switch screenWidth {
            case 0..<375:
                return compactReadingMargin
            case 375..<414:
                return Base.xl
            default:
                return readingMargin
            }
        }
    }

    // MARK: - Spacing Utilities
    public struct Utils {
        /// Snap a value to the nearest grid point
        public static func snapToGrid(_ value: CGFloat, gridSize: CGFloat = Grid.base) -> CGFloat {
            return round(value / gridSize) * gridSize
        }

        /// Create a CGRect with spacing applied
        public static func rectWithSpacing(in container: CGRect,
                                         horizontalSpacing: CGFloat,
                                         verticalSpacing: CGFloat) -> CGRect {
            return CGRect(
                x: container.origin.x + horizontalSpacing,
                y: container.origin.y + verticalSpacing,
                width: container.width - (horizontalSpacing * 2),
                height: container.height - (verticalSpacing * 2)
            )
        }

        /// Calculate the spacing needed between items in a container
        public static func spacingBetweenItems(containerWidth: CGFloat,
                                              itemCount: Int,
                                              itemWidth: CGFloat,
                                              totalSpacing: CGFloat) -> CGFloat {
            let availableWidth = containerWidth - (itemWidth * CGFloat(itemCount))
            return availableWidth / CGFloat(itemCount - 1)
        }

        /// Create insets with consistent spacing
        public static func insets(all value: CGFloat) -> UIEdgeInsets {
            return UIEdgeInsets(top: value, left: value, bottom: value, right: value)
        }

        public static func insets(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> UIEdgeInsets {
            return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }

        public static func insets(top: CGFloat = 0, left: CGFloat = 0,
                                bottom: CGFloat = 0, right: CGFloat = 0) -> UIEdgeInsets {
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
    }

    // MARK: - Animation Spacing
    public struct Animation {
        // Spacing-related animation durations
        public static let spacingTransition: TimeInterval = 0.3
        public static let contentTransition: TimeInterval = 0.25
        public static let uiElementTransition: TimeInterval = 0.2

        // Spring animation parameters for smooth spacing changes
        public static let springDamping: CGFloat = 0.8
        public static let springVelocity: CGFloat = 0.5
    }
}

// MARK: - Convenience Extensions
extension CGRect {
    public func insetBy(spacing: CGFloat) -> CGRect {
        return insetBy(dx: spacing, dy: spacing)
    }

    public func insetBy(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> CGRect {
        return CGRect(
            x: origin.x + horizontal,
            y: origin.y + vertical,
            width: width - (horizontal * 2),
            height: height - (vertical * 2)
        )
    }
}

extension UIEdgeInsets {
    public init(all value: CGFloat) {
        self.init(top: value, left: value, bottom: value, right: value)
    }

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    public var horizontalTotal: CGFloat {
        return left + right
    }

    public var verticalTotal: CGFloat {
        return top + bottom
    }
}

// MARK: - Spacing Calculator
public struct SpacingCalculator {
    private let screenWidth: CGFloat
    private let screenHeight: CGFloat

    public init(screenWidth: CGFloat, screenHeight: CGFloat) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }

    public func microXxxs() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Micro.xxxs, screenWidth: screenWidth)
    }

    public func microXxs() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Micro.xxs, screenWidth: screenWidth)
    }

    public func microXs() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Micro.xs, screenWidth: screenWidth)
    }

    public func microSm() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Micro.sm, screenWidth: screenWidth)
    }

    public func baseSm() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Base.sm, screenWidth: screenWidth)
    }

    public func baseMd() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Base.md, screenWidth: screenWidth)
    }

    public func baseLg() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Base.lg, screenWidth: screenWidth)
    }

    public func baseXl() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Base.xl, screenWidth: screenWidth)
    }

    public func componentSm() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Component.sm, screenWidth: screenWidth)
    }

    public func componentMd() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Component.md, screenWidth: screenWidth)
    }

    public func componentLg() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Component.lg, screenWidth: screenWidth)
    }

    public func componentXl() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Component.xl, screenWidth: screenWidth)
    }

    public func componentXxl() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Component.xxl, screenWidth: screenWidth)
    }

    public func sectionSm() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Section.sm, screenWidth: screenWidth)
    }

    public func sectionMd() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Section.md, screenWidth: screenWidth)
    }

    public func sectionLg() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Section.lg, screenWidth: screenWidth)
    }

    public func sectionXl() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Section.xl, screenWidth: screenWidth)
    }

    public func sectionXxl() -> CGFloat {
        return SutraSpacing.Responsive.spacing(for: SutraSpacing.Section.xxl, screenWidth: screenWidth)
    }

    public func readingMargin() -> CGFloat {
        return SutraSpacing.Margins.readingMargin(for: screenWidth)
    }

    public func safeAreaInsets() -> UIEdgeInsets {
        return SutraSpacing.Responsive.safeAreaInsets(for: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
    }
}