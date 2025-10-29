//
//  SutraAccessibilityManager.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Accessibility Enhancement Manager
class SutraAccessibilityManager {

    static let shared = SutraAccessibilityManager()
    private init() {}

    // MARK: - VoiceOver Configuration
    public func configureVoiceOver(for viewController: UIViewController) {
        // Configure main view
        viewController.view.isAccessibilityElement = false
        viewController.view.accessibilityElementsHidden = false

        // Configure navigation
        configureNavigationAccessibility(for: viewController.navigationController)

        // Configure content based on view controller type
        if let pageViewController = viewController as? SutraPageViewController {
            configurePageViewControllerAccessibility(pageViewController)
        } else if let chapterViewController = viewController as? SutraChapterContentViewController {
            configureChapterViewControllerAccessibility(chapterViewController)
        }
    }

    private func configureNavigationAccessibility(for navigationController: UINavigationController?) {
        guard let navController = navigationController else { return }

        navController.navigationBar.isAccessibilityElement = true
        navController.navigationBar.accessibilityLabel = NSLocalizedString("Navigation bar", comment: "Accessibility label for navigation bar")
        navController.navigationBar.accessibilityHint = NSLocalizedString("Contains navigation controls", comment: "Accessibility hint")

        // Configure back button
        if let backButton = navController.navigationBar.backItem?.backBarButtonItem {
            backButton.accessibilityLabel = NSLocalizedString("Back", comment: "Accessibility label for back button")
            backButton.accessibilityHint = NSLocalizedString("Go back to previous page", comment: "Accessibility hint")
        }

        // Configure title
        if let titleView = navController.navigationBar.topItem?.titleView as? SacredTitleView {
            titleView.isAccessibilityElement = true
            titleView.accessibilityLabel = NSLocalizedString("Chapter title", comment: "Accessibility label")
        }
    }

    private func configurePageViewControllerAccessibility(_ viewController: SutraPageViewController) {
        // Configure page view accessibility
        viewController.view.accessibilityLabel = NSLocalizedString("Sutra reading page", comment: "Accessibility label")
        viewController.view.accessibilityHint = NSLocalizedString("Swipe left or right to navigate between pages", comment: "Accessibility hint")

        // Configure custom actions for page navigation
        let previousPageAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Previous page", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityPreviousPage)
        )

        let nextPageAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Next page", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityNextPage)
        )

        let bookmarkAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Toggle bookmark", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityToggleBookmark)
        )

        let shareAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Share sutra", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityShare)
        )

        let themeAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Change theme", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityChangeTheme)
        )

        let chapterNavigatorAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Chapter navigator", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityChapterNavigator)
        )

        viewController.view.accessibilityCustomActions = [
            previousPageAction,
            nextPageAction,
            bookmarkAction,
            shareAction,
            themeAction,
            chapterNavigatorAction
        ]
    }

    private func configureChapterViewControllerAccessibility(_ viewController: SutraChapterContentViewController) {
        // Configure chapter content view
        viewController.view.accessibilityLabel = NSLocalizedString("Chapter content", comment: "Accessibility label")

        // Configure sutra text view
        if let sutraView = viewController.sutraView {
            sutraView.isAccessibilityElement = true
            sutraView.accessibilityLabel = NSLocalizedString("Sutra text", comment: "Accessibility label")
            sutraView.accessibilityHint = NSLocalizedString("Contains the sacred sutra text", comment: "Accessibility hint")

            // Configure accessibility traits for text content
            sutraView.accessibilityTraits = [.staticText, .updatesFrequently]

            // Set accessibility value to reading progress if available
            if let attributedText = sutraView.attributedText {
                let textLength = attributedText.length
                let visibleRange = sutraView.visibleTextRange
                if let range = visibleRange {
                    let progress = Int((range.location + range.length) * 100 / textLength)
                    sutraView.accessibilityValue = NSLocalizedString("\(progress)% read", comment: "Reading progress")
                }
            }
        }

        // Configure navigation actions
        let backAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Back to sutra list", comment: "Accessibility action"),
            target: viewController,
            selector: #selector(accessibilityBack)
        )

        viewController.view.accessibilityCustomActions = [backAction]
    }

    // MARK: - Reading Progress Accessibility
    public func announceReadingProgress(_ progress: Float, for view: UIView) {
        let progressPercentage = Int(progress * 100)
        let announcement = NSLocalizedString("Reading progress: \(progressPercentage) percent", comment: "VoiceOver announcement")

        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    public func announceChapterChange(_ chapterName: String, chapterNumber: Int) {
        let announcement = NSLocalizedString("Chapter \(chapterNumber): \(chapterName)", comment: "VoiceOver announcement")

        UIAccessibility.post(notification: .announcement, argument: announcement)
        SutraHapticManager.shared.haptic(.sacred)
    }

    public func announceBookmarkChange(_ isBookmarked: Bool) {
        let announcement = isBookmarked ?
            NSLocalizedString("Bookmark added", comment: "VoiceOver announcement") :
            NSLocalizedString("Bookmark removed", comment: "VoiceOver announcement")

        UIAccessibility.post(notification: .announcement, argument: announcement)
        SutraHapticManager.shared.haptic(isBookmarked ? .success : .selection)
    }

    public func announceThemeChange(_ theme: SutraTheme) {
        let themeName: String
        switch theme {
        case .light:
            themeName = NSLocalizedString("Light theme", comment: "VoiceOver announcement")
        case .sepia:
            themeName = NSLocalizedString("Sepia theme", comment: "VoiceOver announcement")
        case .dark:
            themeName = NSLocalizedString("Dark theme", comment: "VoiceOver announcement")
        }

        let announcement = NSLocalizedString("Theme changed to \(themeName)", comment: "VoiceOver announcement")

        UIAccessibility.post(notification: .announcement, argument: announcement)
        SutraHapticManager.shared.haptic(.light)
    }

    // MARK: - Enhanced Text Accessibility
    public func configureTextAccessibility(for textView: UITextView, sutraType: String) {
        textView.isAccessibilityElement = true
        textView.accessibilityLabel = "\(sutraType) \(NSLocalizedString("text", comment: "Accessibility label"))"
        textView.accessibilityHint = NSLocalizedString("Sacred text content", comment: "Accessibility hint")

        // Configure accessibility traits
        textView.accessibilityTraits = [.staticText, .updatesFrequently]

        // Enable text accessibility
        textView.accessibilityScrollDirection = .vertical

        // Configure text content accessibility
        if let attributedText = textView.attributedText {
            // Add accessibility navigation markers for important sections
            addAccessibilityMarkers(to: attributedText, in: textView)
        }
    }

    private func addAccessibilityMarkers(to attributedText: NSAttributedString, in textView: UITextView) {
        let text = attributedText.string
        let lines = text.components(separatedBy: .newlines)

        // Add accessibility elements for each paragraph or important section
        var accessibilityElements: [UIAccessibilityElement] = []
        var currentOffset = 0

        for (index, line) in lines.enumerated() {
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let element = UIAccessibilityElement(accessibilityContainer: textView)

                let lineRange = (text as NSString).range(of: line)
                element.accessibilityLabel = line.trimmingCharacters(in: .whitespacesAndNewlines)
                element.accessibilityFrameInContainerSpace = textView.frame
                element.accessibilityTraits = .staticText

                accessibilityElements.append(element)
                currentOffset = lineRange.location + lineRange.length
            }
        }

        if !accessibilityElements.isEmpty {
            textView.accessibilityElements = accessibilityElements
        }
    }

    // MARK: - Navigation Accessibility Enhancements
    public func enhanceNavigationAccessibility(for navigationController: UINavigationController) {
        // Configure accessibility for navigation controller
        navigationController.isAccessibilityElement = false
        navigationController.view.isAccessibilityElement = false

        // Configure accessibility post notifications for navigation changes
        navigationController.delegate = NavigationAccessibilityDelegate()
    }

    // MARK: - Button Accessibility
    public func configureButtonAccessibility(_ button: UIButton, title: String, hint: String? = nil, action: String? = nil) {
        button.isAccessibilityElement = true
        button.accessibilityLabel = title

        if let hint = hint {
            button.accessibilityHint = hint
        }

        if let action = action {
            button.accessibilityValue = action
        }

        // Add appropriate accessibility traits
        if button.isSelected {
            button.accessibilityTraits.insert(.selected)
        }

        if !button.isEnabled {
            button.accessibilityTraits.insert(.notEnabled)
        }
    }

    // MARK: - Gesture Accessibility
    public func announceGesture(_ gesture: String, description: String) {
        let announcement = "\(gesture): \(description)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    // MARK: - Reading Mode Accessibility
    public func configureReadingModeAccessibility(for view: UIView, mode: String) {
        view.isAccessibilityElement = true
        view.accessibilityLabel = NSLocalizedString("Reading mode", comment: "Accessibility label")
        view.accessibilityValue = mode
        view.accessibilityHint = NSLocalizedString("Double tap to change reading mode", comment: "Accessibility hint")

        // Configure accessibility custom actions
        let normalModeAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Normal reading mode", comment: "Accessibility action"),
            target: view,
            selector: #selector(accessibilityNormalMode)
        )

        let focusModeAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Focus reading mode", comment: "Accessibility action"),
            target: view,
            selector: #selector(accessibilityFocusMode)
        )

        let sacredModeAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Sacred reading mode", comment: "Accessibility action"),
            target: view,
            selector: #selector(accessibilitySacredMode)
        )

        view.accessibilityCustomActions = [normalModeAction, focusModeAction, sacredModeAction]
    }

    // MARK: - Accessibility Testing Helpers
    public func runAccessibilityAudit(on viewController: UIViewController) -> [String] {
        var issues: [String] = []

        // Check for missing accessibility labels
        checkForMissingLabels(in: viewController.view, issues: &issues)

        // Check for accessibility element hierarchy
        checkAccessibilityHierarchy(in: viewController.view, issues: &issues)

        // Check for contrast issues
        checkContrastIssues(in: viewController.view, issues: &issues)

        // Check for VoiceOver support
        checkVoiceOverSupport(in: viewController.view, issues: &issues)

        return issues
    }

    private func checkForMissingLabels(in view: UIView, issues: inout [String]) {
        if view.isAccessibilityElement && view.accessibilityLabel == nil {
            issues.append("Missing accessibility label for \(type(of: view))")
        }

        for subview in view.subviews {
            checkForMissingLabels(in: subview, issues: &issues)
        }
    }

    private func checkAccessibilityHierarchy(in view: UIView, issues: inout [String]) {
        // Check if accessibility elements are properly ordered
        if let accessibilityElements = view.accessibilityElements, !accessibilityElements.isEmpty {
            // Validate element order and relationships
            for (index, element) in accessibilityElements.enumerated() {
                if let accessibleElement = element as? UIAccessibilityElement {
                    if accessibleElement.accessibilityFrame.isNull {
                        issues.append("Accessibility element at index \(index) has invalid frame")
                    }
                }
            }
        }

        for subview in view.subviews {
            checkAccessibilityHierarchy(in: subview, issues: &issues)
        }
    }

    private func checkContrastIssues(in view: UIView, issues: inout [String]) {
        // Basic contrast checking (simplified version)
        if let backgroundColor = view.backgroundColor, !backgroundColor.cgColor.alpha.isZero {
            if let label = view as? UILabel, let textColor = label.textColor {
                let contrast = calculateContrastRatio(foreground: textColor, background: backgroundColor)
                if contrast < 4.5 {
                    issues.append("Low contrast ratio (\(String(format: "%.2f", contrast))) in label: \(label.text ?? "")")
                }
            }
        }

        for subview in view.subviews {
            checkContrastIssues(in: subview, issues: &issues)
        }
    }

    private func checkVoiceOverSupport(in view: UIView, issues: inout [String]) {
        // Check if interactive elements have proper VoiceOver support
        if let button = view as? UIButton, button.isAccessibilityElement {
            if button.accessibilityLabel == nil {
                issues.append("Button missing accessibility label: \(button.currentTitle ?? "Untitled")")
            }
            if button.accessibilityTraits.isEmpty {
                issues.append("Button missing accessibility traits: \(button.currentTitle ?? "Untitled")")
            }
        }

        for subview in view.subviews {
            checkVoiceOverSupport(in: subview, issues: &issues)
        }
    }

    private func calculateContrastRatio(foreground: UIColor, background: UIColor) -> CGFloat {
        // Simplified contrast ratio calculation
        let fgLuminance = calculateLuminance(foreground)
        let bgLuminance = calculateLuminance(background)

        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private func calculateLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate relative luminance
        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

// MARK: - Navigation Accessibility Delegate
private class NavigationAccessibilityDelegate: NSObject, UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // Announce navigation changes for VoiceOver users
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let title = viewController.title {
                let announcement = NSLocalizedString("Navigated to \(title)", comment: "VoiceOver announcement")
                UIAccessibility.post(notification: .screenChanged, argument: announcement)
            }
        }
    }
}

// MARK: - Accessibility Extensions
extension UIViewController {
    @objc func accessibilityPreviousPage() {
        // Override in specific view controllers
    }

    @objc func accessibilityNextPage() {
        // Override in specific view controllers
    }

    @objc func accessibilityToggleBookmark() {
        // Override in specific view controllers
    }

    @objc func accessibilityShare() {
        // Override in specific view controllers
    }

    @objc func accessibilityChangeTheme() {
        // Override in specific view controllers
    }

    @objc func accessibilityChapterNavigator() {
        // Override in specific view controllers
    }

    @objc func accessibilityBack() {
        // Override in specific view controllers
    }

    @objc func accessibilityNormalMode() {
        // Override in specific view controllers
    }

    @objc func accessibilityFocusMode() {
        // Override in specific view controllers
    }

    @objc func accessibilitySacredMode() {
        // Override in specific view controllers
    }
}

extension UIView {
    @objc func accessibilityNormalMode() {
        // Default implementation
    }

    @objc func accessibilityFocusMode() {
        // Default implementation
    }

    @objc func accessibilitySacredMode() {
        // Default implementation
    }
}