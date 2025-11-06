//
//  DesignSystem+Accessibility.swift
//  lengyan
//
//  Minimal Accessibility System
//  Reduced from 256 to ~80 lines (69% reduction)
//  Only essential features: navigation + button support
//

import UIKit

// MARK: - Accessibility Categories (Essential Only)
public enum AccessibilityCategory {
    case navigation
    case button
}

// MARK: - Accessibility Manager
@MainActor
public final class SutraAccessibilityManager {
    public static let shared = SutraAccessibilityManager()
    private init() {}

    // MARK: - VoiceOver Configuration
    public func configureVoiceOver(for view: UIView, category: AccessibilityCategory, customLabel: String? = nil) {
        view.isAccessibilityElement = true

        switch category {
        case .navigation:
            configureNavigation(for: view, customLabel: customLabel)
        case .button:
            configureButton(for: view, customLabel: customLabel)
        }
    }

    // MARK: - Configuration Methods
    private func configureNavigation(for view: UIView, customLabel: String?) {
        view.accessibilityLabel = customLabel ?? NSLocalizedString("accessibility.navigation.default", comment: "Navigation")
        view.accessibilityHint = NSLocalizedString("accessibility.navigation.hint", comment: "Navigate to different sections")
        view.accessibilityTraits = UIAccessibilityTraitButton

        if let button = view as? UIButton {
            button.accessibilityLabel = customLabel ?? button.currentTitle
        }
    }

    private func configureButton(for view: UIView, customLabel: String?) {
        if let button = view as? UIButton {
            button.accessibilityLabel = customLabel ?? button.currentTitle
            button.accessibilityHint = NSLocalizedString("accessibility.button.hint", comment: "Double tap to activate")
            button.accessibilityTraits = UIAccessibilityTraitButton
        }
    }

    // MARK: - Accessibility Announcements
    public func announce(_ message: String) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message)
    }

    public func postLayoutChangedNotification() {
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil)
    }

    public func postScreenChangedNotification() {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil)
    }

    // MARK: - Accessibility State
    public var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    public var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - UIKit Convenience Extensions
extension UIView {
    public func configureForAccessibility(_ category: AccessibilityCategory, customLabel: String? = nil) {
        SutraAccessibilityManager.shared.configureVoiceOver(for: self, category: category, customLabel: customLabel)
    }
}

extension UILabel {
    public func configureForAccessibility(_ category: AccessibilityCategory) {
        SutraAccessibilityManager.shared.configureVoiceOver(for: self, category: category)
    }
}

extension UIButton {
    public func configureForAccessibility(_ category: AccessibilityCategory) {
        SutraAccessibilityManager.shared.configureVoiceOver(for: self, category: category)
    }
}

// MARK: - Accessibility Best Practices
public struct AccessibilityGuidelines {
    /// Minimum touch target size (44x44 points per Apple HIG)
    public static let minimumTouchTarget: CGFloat = 44

    /// Recommended spacing between interactive elements
    public static let minimumTouchSpacing: CGFloat = 8
}
