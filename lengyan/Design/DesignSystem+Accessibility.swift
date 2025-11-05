//
//  DesignSystem+Accessibility.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Accessibility Manager
public class SutraAccessibilityManager {

    public static let shared = SutraAccessibilityManager()
    private init() {}

    // MARK: - Accessibility Categories
    public enum AccessibilityCategory {
        case sutraText
        case commentaryText
        case navigation
        case button
        case link
        case heading
        case landmark
        case status
    }

    // MARK: - VoiceOver Configuration
    public func configureVoiceOver(for view: UIView, category: AccessibilityCategory, customLabel: String? = nil) {
        view.isAccessibilityElement = true

        switch category {
        case .sutraText:
            configureSutraTextAccessibility(for: view, customLabel: customLabel)

        case .commentaryText:
            configureCommentaryTextAccessibility(for: view, customLabel: customLabel)

        case .navigation:
            configureNavigationAccessibility(for: view, customLabel: customLabel)

        case .button:
            configureButtonAccessibility(for: view, customLabel: customLabel)

        case .link:
            configureLinkAccessibility(for: view, customLabel: customLabel)

        case .heading:
            configureHeadingAccessibility(for: view, customLabel: customLabel)

        case .landmark:
            configureLandmarkAccessibility(for: view, customLabel: customLabel)

        case .status:
            configureStatusAccessibility(for: view, customLabel: customLabel)
        }
    }

    private func configureSutraTextAccessibility(for view: UIView, customLabel: String?) {
        if let label = view as? UILabel {
            label.accessibilityLabel = customLabel ?? label.text
            label.accessibilityHint = NSLocalizedString("accessibility.sutra.hint", comment: "Sutra text content")
            label.accessibilityTraits = 1
        } else if let textView = view as? UITextView {
            textView.accessibilityLabel = customLabel ?? textView.text
            textView.accessibilityHint = NSLocalizedString("accessibility.sutra.hint", comment: "Sutra text content")
            textView.accessibilityTraits = 1
        }

        // Set language for proper pronunciation
        view.accessibilityLanguage = "zh-CN" // Simplified Chinese
    }

    private func configureCommentaryTextAccessibility(for view: UIView, customLabel: String?) {
        if let label = view as? UILabel {
            label.accessibilityLabel = customLabel ?? label.text
            label.accessibilityHint = NSLocalizedString("accessibility.commentary.hint", comment: "Commentary text content")
            label.accessibilityTraits = 1
        }

        // Add context for commentary
        if let existingLabel = view.accessibilityLabel {
            view.accessibilityLabel = NSLocalizedString("accessibility.commentary.prefix", comment: "Commentary: ") + existingLabel
        }
    }

    private func configureNavigationAccessibility(for view: UIView, customLabel: String?) {
        view.accessibilityLabel = customLabel ?? NSLocalizedString("accessibility.navigation.default", comment: "Navigation")
        view.accessibilityHint = NSLocalizedString("accessibility.navigation.hint", comment: "Navigate to different sections")
        view.accessibilityTraits = 1 << 9

        if let button = view as? UIButton {
            button.accessibilityLabel = customLabel ?? button.currentTitle
        }
    }

    private func configureButtonAccessibility(for view: UIView, customLabel: String?) {
        if let button = view as? UIButton {
            button.accessibilityLabel = customLabel ?? button.currentTitle
            button.accessibilityHint = NSLocalizedString("accessibility.button.hint", comment: "Double tap to activate")
            button.accessibilityTraits = 1 << 9
        }
    }

    private func configureLinkAccessibility(for view: UIView, customLabel: String?) {
        if let button = view as? UIButton {
            button.accessibilityLabel = customLabel ?? button.currentTitle
            button.accessibilityHint = NSLocalizedString("accessibility.link.hint", comment: "Double tap to open link")
            button.accessibilityTraits = 1 << 5
        }
    }

    private func configureHeadingAccessibility(for view: UIView, customLabel: String?) {
        if let label = view as? UILabel {
            label.accessibilityLabel = customLabel ?? label.text
            label.accessibilityHint = NSLocalizedString("accessibility.heading.hint", comment: "Section heading")
            label.accessibilityTraits = 1 << 6
        }
    }

    private func configureLandmarkAccessibility(for view: UIView, customLabel: String?) {
        view.accessibilityLabel = customLabel ?? NSLocalizedString("accessibility.landmark.default", comment: "Landmark")
        view.accessibilityTraits = UIAccessibilityTraits()
        view.accessibilityElementsHidden = false
    }

    private func configureStatusAccessibility(for view: UIView, customLabel: String?) {
        if let label = view as? UILabel {
            label.accessibilityLabel = customLabel ?? label.text
            label.accessibilityHint = NSLocalizedString("accessibility.status.hint", comment: "Status information")
            label.accessibilityTraits = 1 | (1 << 10)  // staticText | updatesFrequently
        }
    }

    // MARK: - Dynamic Type Support
    public func configureDynamicType(for view: UIView, baseStyle: SutraTextStyle) {
        // Adjust for different content size categories
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory

        let adjustedStyle = SutraTypography.DynamicType.adjustForContentSizeCategory(baseStyle, category: contentSizeCategory)

        if let label = view as? UILabel {
            label.font = UIFont.sutraFont(style: adjustedStyle)
            adjustLineSpacing(for: label, style: adjustedStyle)
        } else if let textView = view as? UITextView {
            textView.font = UIFont.sutraFont(style: adjustedStyle)
            adjustLineSpacing(for: textView, style: adjustedStyle)
        } else if let button = view as? UIButton {
            button.titleLabel?.font = UIFont.sutraFont(style: adjustedStyle)
        }
    }

    private func adjustLineSpacing(for label: UILabel, style: SutraTextStyle) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = style.lineHeight

        let attributedText = NSMutableAttributedString(string: label.text ?? "")
        attributedText.addAttributes([
            .paragraphStyle: paragraphStyle,
            .font: UIFont.sutraFont(style: style)
        ], range: NSRange(location: 0, length: attributedText.length))

        label.attributedText = attributedText
    }

    private func adjustLineSpacing(for textView: UITextView, style: SutraTextStyle) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = style.lineHeight

        let attributedText = NSMutableAttributedString(string: textView.text)
        attributedText.addAttributes([
            .paragraphStyle: paragraphStyle,
            .font: UIFont.sutraFont(style: style)
        ], range: NSRange(location: 0, length: attributedText.length))

        textView.attributedText = attributedText
    }

    // MARK: - Reading Order
    public func configureReadingOrder(for containerView: UIView) {
        // Ensure proper reading order for VoiceOver users
        var accessibilityElements: [UIAccessibilityElement] = []

        // Sort views by visual order (top to bottom, left to right)
        let sortedSubviews = containerView.subviews.sorted { view1, view2 in
            if abs(view1.frame.origin.y - view2.frame.origin.y) < 10 {
                return view1.frame.origin.x < view2.frame.origin.x
            } else {
                return view1.frame.origin.y < view2.frame.origin.y
            }
        }

        for (index, subview) in sortedSubviews.enumerated() {
            let element = UIAccessibilityElement(accessibilityContainer: containerView)
            element.accessibilityLabel = subview.accessibilityLabel
            element.accessibilityHint = subview.accessibilityHint
            element.accessibilityTraits = subview.accessibilityTraits
            element.accessibilityFrame = subview.convert(subview.bounds, to: containerView)
            element.isAccessibilityElement = true
            accessibilityElements.append(element)
        }

        containerView.accessibilityElements = accessibilityElements
    }

    // MARK: - Accessibility Notifications
    public func announceChange(_ message: String) {
        UIAccessibilityPostNotification(UIAccessibilityNotifications(1 << 0), message)
    }

    public func announceScreenChanged(to view: UIView) {
        UIAccessibilityPostNotification(UIAccessibilityNotifications(1 << 1), view)
    }

    public func announceLayoutChanged(to view: UIView) {
        UIAccessibilityPostNotification(UIAccessibilityNotifications(1 << 2), view)
    }

    public func announceBookmarkChange(_ isBookmarked: Bool) {
        let message = isBookmarked ? "已添加书签" : "已移除书签"
        announceChange(message)
    }

    public func announceThemeChange(_ theme: SutraTheme) {
        let message = "主题已切换为 \(theme == .light ? "浅色" : theme == .sepia ? "米色" : "深色")"
        announceChange(message)
    }

    public func announceChapterChange(_ chapterName: String, chapterNumber: Int) {
        let message = "第\(chapterNumber)章：\(chapterName)"
        announceChange(message)
    }

    public func announceReadingProgress(_ progress: Float, for view: UIView) {
        let message = "阅读进度 \(Int(progress * 100))%"
        announceChange(message)
    }
}

// MARK: - Accessibility Action Selectors
extension UIViewController {

    @objc open func accessibilityPreviousPage() {
        // Implementation for accessibility previous page action
        // This should be implemented by view controllers that support pagination
    }

    @objc open func accessibilityNextPage() {
        // Implementation for accessibility next page action
        // This should be implemented by view controllers that support pagination
    }

    @objc open func accessibilityToggleBookmark() {
        // Implementation for accessibility bookmark toggle action
        // This should be implemented by view controllers that support bookmarking
    }

    @objc open func accessibilityShare() {
        // Implementation for accessibility share action
        // This should be implemented by view controllers that support sharing
    }

    @objc open func accessibilityChangeTheme() {
        // Implementation for accessibility theme change action
        SutraThemeManager.shared.toggleTheme()
    }

    @objc open func accessibilityChapterNavigator() {
        // Implementation for accessibility chapter navigator action
        // This should be implemented by view controllers that support chapter navigation
    }

    @objc private func accessibilityBack() {
        // Implementation for accessibility back action
        navigationController?.popViewController(animated: true)
    }

    @objc private func accessibilityNormalMode() {
        // Implementation for accessibility normal reading mode
    }

    @objc private func accessibilityFocusMode() {
        // Implementation for accessibility focus reading mode
    }

    @objc private func accessibilitySacredMode() {
        // Implementation for accessibility sacred reading mode
    }
}

// MARK: - Accessible Button Component
public class SutraAccessibleButton: UIButton {

    public var accessibilityCategory: SutraAccessibilityManager.AccessibilityCategory = .button
    public var customAccessibilityLabel: String?
    public var customAccessibilityHint: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAccessibility()
    }

    private func setupAccessibility() {
        SutraAccessibilityManager.shared.configureVoiceOver(
            for: self,
            category: accessibilityCategory,
            customLabel: customAccessibilityLabel
        )

        if let hint = customAccessibilityHint {
            accessibilityHint = hint
        }
    }

    public func updateAccessibility() {
        SutraAccessibilityManager.shared.configureVoiceOver(
            for: self,
            category: accessibilityCategory,
            customLabel: customAccessibilityLabel
        )

        if let hint = customAccessibilityHint {
            accessibilityHint = hint
        }
    }
}

// MARK: - Accessible Text View Component
public class SutraAccessibleTextView: UITextView {

    public enum TextType {
        case sutra
        case commentary
        case heading
        case body
    }

    public var textType: TextType = .body {
        didSet { updateAccessibility() }
    }

    public var customAccessibilityLabel: String?
    public var customAccessibilityHint: String?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAccessibility()
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        updateAccessibility()
        setupDynamicType()
    }

    private func updateAccessibility() {
        let category: SutraAccessibilityManager.AccessibilityCategory = {
            switch textType {
            case .sutra: return .sutraText
            case .commentary: return .commentaryText
            case .heading: return .heading
            case .body: return .sutraText
            }
        }()

        SutraAccessibilityManager.shared.configureVoiceOver(
            for: self,
            category: category,
            customLabel: customAccessibilityLabel
        )

        if let hint = customAccessibilityHint {
            accessibilityHint = hint
        }

        // Configure language based on text type
        switch textType {
        case .sutra, .commentary, .heading:
            accessibilityLanguage = "zh-CN"
        case .body:
            accessibilityLanguage = nil // Use system default
        }
    }

    private func setupDynamicType() {
        let baseStyle: SutraTextStyle = {
            switch textType {
            case .sutra: return SutraTypography.TextStyle.sutraBody
            case .commentary: return SutraTypography.TextStyle.commentary
            case .heading: return SutraTypography.TextStyle.sectionTitle
            case .body: return SutraTypography.TextStyle.sutraBody
            }
        }()

        SutraAccessibilityManager.shared.configureDynamicType(for: self, baseStyle: baseStyle)

        // Listen for content size category changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: NSNotification.Name.UIContentSizeCategoryDidChange,
            object: nil
        )
    }

    @objc private func contentSizeCategoryDidChange() {
        setupDynamicType()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Accessibility Helpers
public struct SutraAccessibilityHelpers {

    // MARK: - WCAG Contrast Validation
    public static func validateContrastRatio(foreground: UIColor, background: UIColor) -> (ratio: CGFloat, passesWCAG: Bool) {
        let luminance1 = calculateLuminance(foreground)
        let luminance2 = calculateLuminance(background)
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)

        let contrastRatio = (lighter + 0.05) / (darker + 0.05)
        let passesWCAG = contrastRatio >= 4.5 // WCAG AA standard

        return (ratio: contrastRatio, passesWCAG: passesWCAG)
    }

    private static func calculateLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Apply gamma correction
        let redCorrected = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let greenCorrected = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let blueCorrected = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)

        return 0.2126 * redCorrected + 0.7152 * greenCorrected + 0.0722 * blueCorrected
    }

    // MARK: - Touch Target Size Validation
    public static func validateTouchTargetSize(for view: UIView) -> Bool {
        let size = view.bounds.size
        let minSize: CGFloat = 44 // Apple HIG minimum touch target size
        return size.width >= minSize && size.height >= minSize
    }

    public func ensureMinimumTouchTarget(for view: UIView) {
        let currentFrame = view.frame
        let minSize: CGFloat = 44

        if currentFrame.width < minSize || currentFrame.height < minSize {
            let newSize = max(max(currentFrame.width, currentFrame.height), minSize)
            let expandedFrame = CGRect(
                x: currentFrame.midX - newSize / 2,
                y: currentFrame.midY - newSize / 2,
                width: newSize,
                height: newSize
            )

            // Create invisible larger touch area
            let touchView = UIView(frame: expandedFrame)
            touchView.backgroundColor = UIColor.clear
            touchView.isAccessibilityElement = false
            view.superview?.insertSubview(touchView, belowSubview: view)

            // Transfer gestures to touch view
            for gesture in view.gestureRecognizers ?? [] {
                touchView.addGestureRecognizer(gesture)
            }
        }
    }

    // MARK: - Focus Management
    public static func setAccessibilityFocus(on view: UIView) {
        UIAccessibilityPostNotification(UIAccessibilityNotifications(1 << 2), view)
    }

    public static func setAccessibilityFocusToFirstElement(in containerView: UIView) {
        if let firstElement = containerView.subviews.first(where: { $0.isAccessibilityElement }) {
            setAccessibilityFocus(on: firstElement)
        }
    }

    // MARK: - Reduced Motion Support
    public static func shouldReduceMotion() -> Bool {
        return UIAccessibility.isReduceMotionEnabled
    }

    public static func animateWithReducedMotionSupport(
        duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        if shouldReduceMotion() {
            // Provide instant feedback or simplified animation
            animations()
            completion?(true)
        } else {
            UIView.animate(withDuration: duration, animations: animations, completion: completion)
        }
    }

    // MARK: - Switch Control Support
    public static func configureForSwitchControl(_ view: UIView) {
        view.isAccessibilityElement = true
        view.accessibilityTraits = UIAccessibilityTraits(1 << 9)
        view.accessibilityHint = NSLocalizedString("accessibility.switch.hint", comment: "Activate with switch control")
    }

    // MARK: - VoiceOver Navigation Helpers
    public static func createAccessibilityElement(for view: UIView, in container: UIView) -> UIAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityLabel = view.accessibilityLabel
        element.accessibilityHint = view.accessibilityHint
        element.accessibilityTraits = view.accessibilityTraits
        element.accessibilityFrame = view.convert(view.bounds, to: container)
        element.isAccessibilityElement = true
        return element
    }

    // MARK: - Accessibility Audit Helpers
    public static func performAccessibilityAudit(on viewController: UIViewController) -> [String] {
        var issues: [String] = []

        // Check for accessibility labels
        checkAccessibilityLabels(viewController.view, issues: &issues)

        // Check for touch target sizes
        checkTouchTargetSizes(viewController.view, issues: &issues)

        // Check for contrast ratios
        checkContrastRatios(viewController.view, issues: &issues)

        // Check for navigation flow
        checkNavigationFlow(viewController.view, issues: &issues)

        return issues
    }

    private static func checkAccessibilityLabels(_ view: UIView, issues: inout [String]) {
        if view.isAccessibilityElement && (view.accessibilityLabel?.isEmpty ?? true) {
            issues.append("Missing accessibility label for \(type(of: view))")
        }

        for subview in view.subviews {
            checkAccessibilityLabels(subview, issues: &issues)
        }
    }

    private static func checkTouchTargetSizes(_ view: UIView, issues: inout [String]) {
        if view.isAccessibilityElement && !validateTouchTargetSize(for: view) {
            issues.append("Touch target too small for \(type(of: view)): \(view.bounds.size)")
        }

        for subview in view.subviews {
            checkTouchTargetSizes(subview, issues: &issues)
        }
    }

    private static func checkContrastRatios(_ view: UIView, issues: inout [String]) {
        // This would require more complex implementation to check actual colors
        // For now, just a placeholder
        if let label = view as? UILabel {
            if let backgroundColor = view.backgroundColor, let textColor = label.textColor {
                let contrast = validateContrastRatio(foreground: textColor, background: backgroundColor)
                if !contrast.passesWCAG {
                    issues.append("Poor contrast ratio (\(String(format: "%.2f", contrast.ratio))) for label: \(label.text ?? "unnamed")")
                }
            }
        }

        for subview in view.subviews {
            checkContrastRatios(subview, issues: &issues)
        }
    }

    private static func checkNavigationFlow(_ view: UIView, issues: inout [String]) {
        // Check for proper navigation order and landmarks
        if view.accessibilityElements?.isEmpty == false && view.accessibilityElements == nil {
            issues.append("Complex view \(type(of: view)) without accessibility elements defined")
        }

        for subview in view.subviews {
            checkNavigationFlow(subview, issues: &issues)
        }
    }
}

// MARK: - Accessibility Configuration Extension
extension UIViewController {
    @objc open func configureAccessibility() {
        // Set up navigation controller accessibility
        if let navigationController = navigationController {
            navigationController.navigationBar.isAccessibilityElement = false
        }

        // Configure view accessibility
        view.isAccessibilityElement = false

        // Set up proper reading order
        SutraAccessibilityManager.shared.configureReadingOrder(for: view)
    }

    public func announceAppearance() {
        SutraAccessibilityManager.shared.announceScreenChanged(to: view)
    }
}