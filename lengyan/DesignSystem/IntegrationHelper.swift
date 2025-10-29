//
//  IntegrationHelper.swift
//  lengyan
//
//  Created by Claude on 2025/10/28.
//  Copyright © 2025年 xuan. All rights reserved.
//

import UIKit

// MARK: - Integration Helper for Design System
class IntegrationHelper {

    static func integrateDesignSystem() {
        // Apply the design system globally
        SutraColors.setTheme(.light)
        SutraThemeManager.shared.setTheme(.light)
    }

    static func enhanceSutraFrontViewController(_ viewController: SutraFrontViewController) {
        // Apply enhanced design to existing view controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewController.applyEnhancedDesign()
        }
    }

    static func addThemeToggleToViewController(_ viewController: UIViewController) {
        // Add theme toggle button
        let themeButton = UIBarButtonItem(
            image: UIImage(systemName: "paintbrush"),
            style: .plain,
            target: self,
            action: #selector(toggleTheme)
        )
        themeButton.tintColor = SutraColors.currentColors.accent

        if let navController = viewController.navigationController {
            // Add to right side with existing items
            if var rightItems = navController.navigationItem.rightBarButtonItems {
                rightItems.append(themeButton)
                navController.navigationItem.rightBarButtonItems = rightItems
            } else {
                navController.navigationItem.rightBarButtonItem = themeButton
            }
        }
    }

    @objc private static func toggleTheme() {
        SutraThemeManager.shared.cycleTheme()

        // Notify view controllers to update their design
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}