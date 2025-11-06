//
//  DesignSystem+Layout.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Layout Utilities
/// Essential layout utilities for the reading app
@available(*, deprecated, message: "Layout utilities are not currently used. Consider using native SwiftUI layout or UIKit auto layout instead.")
public struct SutraLayoutUtils {

    // MARK: - Safe Area Calculations
    public static func safeAreaInsets(for view: UIView) -> UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        }
    }

    // MARK: - Reading Frame Calculator
    public static func readingFrame(in container: UIView) -> CGRect {
        let safeArea = safeAreaInsets(for: container)
        let margin: CGFloat = 20  // Fixed reading margin

        return CGRect(
            x: safeArea.left + margin,
            y: safeArea.top,
            width: container.frame.width - safeArea.left - safeArea.right - (margin * 2),
            height: container.frame.height - safeArea.top - safeArea.bottom
        )
    }

    // MARK: - Responsive Height Calculator
    public static func responsiveHeight(for baseHeight: CGFloat,
                                       screenHeight: CGFloat) -> CGFloat {
        switch screenHeight {
        case 0..<667: // iPhone SE, iPhone 8
            return baseHeight * 0.875
        case 667..<736: // iPhone 8 Plus
            return baseHeight
        case 736..<812: // iPhone Plus
            return baseHeight * 1.125
        case 812..<896: // iPhone X, XS, 11 Pro
            return baseHeight * 1.15
        case 896..<CGFloat.greatestFiniteMagnitude: // iPhone XR, XS Max, 11, 11 Pro Max
            return baseHeight * 1.2
        default:
            return baseHeight
        }
    }

    // MARK: - Centering Constraints
    public static func centerInView(_ subview: UIView, in parentView: UIView) -> [NSLayoutConstraint] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        return [
            subview.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            subview.centerYAnchor.constraint(equalTo: parentView.centerYAnchor)
        ]
    }

    // MARK: - Full Screen Constraints
    public static func fillSuperview(_ view: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        view.translatesAutoresizingMaskIntoConstraints = false
        return [
            view.topAnchor.constraint(equalTo: view.superview!.topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: view.superview!.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: view.superview!.trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: view.superview!.bottomAnchor, constant: -insets.bottom)
        ]
    }
}

// MARK: - Layout Constants
/// Essential layout constants for the reading app
@available(*, deprecated, message: "Layout constants are not currently used. Consider using native values or move to actual layout code.")
public struct SutraLayoutConstants {
    // Reading layout constants
    public static let optimalReadingWidth: CGFloat = 680  // Maximum width for comfortable reading
    public static let minReadingWidth: CGFloat = 280      // Minimum readable width
    public static let maxReadingWidth: CGFloat = 800      // Maximum width before centering

    // Touch target sizes (Apple HIG compliant)
    public static let minTouchTarget: CGFloat = 44
    public static let preferredTouchTarget: CGFloat = 48

    // Navigation heights
    public static let navigationBarHeight: CGFloat = 44
    public static let statusBarHeight: CGFloat = 20
    public static let homeIndicatorHeight: CGFloat = 34

    // Animation constants
    public static let defaultAnimationDuration: TimeInterval = 0.3
    public static let fastAnimationDuration: TimeInterval = 0.2
    public static let slowAnimationDuration: TimeInterval = 0.5
}