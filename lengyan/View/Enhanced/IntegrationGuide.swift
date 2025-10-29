//
//  IntegrationGuide.swift
//  lengyan
//
//  Integration utilities for enhanced view controllers
//

import UIKit

// MARK: - Integration Manager
class EnhancedViewControllerIntegrationManager {

    static let shared = EnhancedViewControllerIntegrationManager()

    private init() {}

    // MARK: - Migration Methods

    /// Migrate from original to enhanced view controllers
    func migrateToEnhancedViewControllers(in navigationController: UINavigationController) {
        // Replace existing view controllers with enhanced versions
        replaceViewControllers(in: navigationController)
    }

    private func replaceViewControllers(in navigationController: UINavigationController) {
        guard let viewControllers = navigationController.viewControllers as? [UIViewController] else { return }

        let enhancedViewControllers = viewControllers.map { viewController in
            return enhanceViewController(viewController)
        }

        navigationController.setViewControllers(enhancedViewControllers, animated: false)
    }

    private func enhanceViewController(_ viewController: UIViewController) -> UIViewController {
        // Replace based on class type
        if viewController is SutraFrontViewController {
            return EnhancedSutraFrontViewController()
        } else if viewController is SutraPageViewController {
            return EnhancedSutraPageViewController()
        } else if viewController is SutraIndexViewController {
            return EnhancedSutraIndexViewController()
        } else if viewController is MediaTableViewController {
            return EnhancedMediaTableViewController()
        }

        return viewController
    }

    // MARK: - Setup Methods

    /// Setup enhanced view controllers with proper configuration
    func setupEnhancedViewControllers() {
        setupDesignSystem()
        setupThemeManager()
        setupNavigationController()
        setupAccessibility()
    }

    private func setupDesignSystem() {
        // Initialize design system components
        _ = SutraThemeManager.shared
    }

    private func setupThemeManager() {
        // Configure theme manager with user preferences
        let savedTheme = UserDefaults.standard.string(forKey: "SelectedTheme") ?? "light"
        if let theme = SutraTheme(rawValue: savedTheme) {
            SutraThemeManager.shared.switchTheme(to: theme)
        }
    }

    private func setupNavigationController() {
        // Configure navigation controller appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SutraColors.Semantic.surface(theme: .light)

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private func setupAccessibility() {
        // Configure global accessibility settings
        UIAccessibility.post(notification: .layoutChanged, argument: "Enhanced view controllers loaded")
    }

    // MARK: - Factory Methods

    /// Create enhanced view controller based on type
    func createEnhancedViewController(type: ViewControllerType) -> UIViewController {
        switch type {
        case .front:
            return EnhancedSutraFrontViewController()
        case .page:
            return EnhancedSutraPageViewController()
        case .index:
            return EnhancedSutraIndexViewController()
        case .media:
            return EnhancedMediaTableViewController()
        }
    }

    /// Create enhanced navigation controller with root view controller
    func createEnhancedNavigationController(rootType: ViewControllerType) -> UINavigationController {
        let rootViewController = createEnhancedViewController(type: rootType)
        let navigationController = SutraNavigationController(rootViewController: rootViewController)
        return navigationController
    }
}

// MARK: - View Controller Types
enum ViewControllerType {
    case front
    case page
    case index
    case media
}

// MARK: - Transition Coordinator
class EnhancedViewTransitionCoordinator {

    /// Animate transition from original to enhanced view controller
    static func animateTransition(from originalVC: UIViewController, to enhancedVC: UIViewController, in navigationController: UINavigationController) {
        // Prepare enhanced view controller
        enhancedVC.loadViewIfNeeded()

        // Create transition animation
        UIView.transition(with: navigationController.view, duration: 0.5, options: .transitionCrossDissolve) {
            let viewControllers = navigationController.viewControllers.map { vc in
                return vc === originalVC ? enhancedVC : vc
            }
            navigationController.setViewControllers(viewControllers, animated: false)
        } completion: { _ in
            // Post transition setup
            if let enhancedVC = enhancedVC as? EnhancedSutraFrontViewController {
                enhancedVC.animateEntrance()
            }
        }
    }
}

// MARK: - Data Migration Utilities
class EnhancedDataMigrationManager {

    /// Migrate user preferences to enhanced view controllers
    static func migrateUserPreferences() {
        // Migrate theme preferences
        migrateThemePreferences()

        // Migrate reading preferences
        migrateReadingPreferences()

        // Migrate media preferences
        migrateMediaPreferences()
    }

    private static func migrateThemePreferences() {
        // Check if theme preference exists
        if UserDefaults.standard.object(forKey: "SelectedTheme") == nil {
            // Set default theme based on system
            let systemTheme = UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
            UserDefaults.standard.set(systemTheme, forKey: "SelectedTheme")
        }
    }

    private static func migrateReadingPreferences() {
        // Migrate reading settings
        if UserDefaults.standard.object(forKey: "ReadingFontSize") == nil {
            UserDefaults.standard.set(16.0, forKey: "ReadingFontSize")
        }
    }

    private static func migrateMediaPreferences() {
        // Migrate media settings
        if UserDefaults.standard.object(forKey: "AutoPlayMedia") == nil {
            UserDefaults.standard.set(false, forKey: "AutoPlayMedia")
        }
    }
}

// MARK: - Performance Monitor
class EnhancedViewControllerPerformanceMonitor {

    static func monitorPerformance(of viewController: UIViewController, completion: @escaping (PerformanceMetrics) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Load view controller
        viewController.loadViewIfNeeded()

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        // Measure memory usage
        let memoryUsage = getMemoryUsage()

        // Create metrics
        let metrics = PerformanceMetrics(
            loadTime: loadTime,
            memoryUsage: memoryUsage,
            viewComplexity: analyzeViewComplexity(viewController)
        )

        completion(metrics)
    }

    private static func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        return 0.0
    }

    private static func analyzeViewComplexity(_ viewController: UIViewController) -> Int {
        var complexity = 0

        func analyzeView(_ view: UIView) {
            complexity += 1
            view.subviews.forEach(analyzeView)
        }

        analyzeView(viewController.view)
        return complexity
    }
}

// MARK: - Performance Metrics
struct PerformanceMetrics {
    let loadTime: CFAbsoluteTime
    let memoryUsage: Double
    let viewComplexity: Int

    var isAcceptable: Bool {
        return loadTime < 0.5 && memoryUsage < 100 && viewComplexity < 1000
    }
}

// MARK: - Configuration Builder
class EnhancedViewControllerConfigurationBuilder {

    private var configuration = EnhancedViewControllerConfiguration()

    func withTheme(_ theme: SutraTheme) -> EnhancedViewControllerConfigurationBuilder {
        configuration.theme = theme
        return self
    }

    func withAnimations(_ enabled: Bool) -> EnhancedViewControllerConfigurationBuilder {
        configuration.animationsEnabled = enabled
        return self
    }

    func withAccessibility(_ enabled: Bool) -> EnhancedViewControllerConfigurationBuilder {
        configuration.accessibilityEnabled = enabled
        return self
    }

    func withHapticFeedback(_ enabled: Bool) -> EnhancedViewControllerConfigurationBuilder {
        configuration.hapticFeedbackEnabled = enabled
        return self
    }

    func build() -> EnhancedViewControllerConfiguration {
        return configuration
    }
}

// MARK: - Configuration
struct EnhancedViewControllerConfiguration {
    var theme: SutraTheme = .light
    var animationsEnabled: Bool = true
    var accessibilityEnabled: Bool = true
    var hapticFeedbackEnabled: Bool = true
}

// MARK: - Validation Utilities
class EnhancedViewControllerValidator {

    /// Validate that enhanced view controllers are properly configured
    static func validateEnhancedViewControllers() -> ValidationResult {
        var issues: [String] = []

        // Check design system availability
        if SutraThemeManager.shared.currentTheme == nil {
            issues.append("Design system not properly initialized")
        }

        // Check required files
        if !checkRequiredFiles() {
            issues.append("Required design system files missing")
        }

        // Check accessibility
        if !UIAccessibility.isVoiceOverRunning {
            // Note: This is not an error, just informational
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }

    private static func checkRequiredFiles() -> Bool {
        // Check that required design system files exist
        let requiredClasses: [AnyClass] = [
            SutraColors.self,
            SutraTypography.self,
            SutraSpacing.self,
            SutraComponents.self,
            SutraThemeManager.self
        ]

        return requiredClasses.allSatisfy { $0.self != nil }
    }
}

// MARK: - Validation Result
struct ValidationResult {
    let isValid: Bool
    let issues: [String]

    var errorMessage: String? {
        return issues.isEmpty ? nil : issues.joined(separator: "; ")
    }
}

// MARK: - Integration Extension for UIViewController
extension UIViewController {

    /// Convert current view controller to enhanced version
    func toEnhancedVersion() -> UIViewController {
        switch self {
        case is SutraFrontViewController:
            return EnhancedSutraFrontViewController()
        case is SutraPageViewController:
            return EnhancedSutraPageViewController()
        case is SutraIndexViewController:
            return EnhancedSutraIndexViewController()
        case is MediaTableViewController:
            return EnhancedMediaTableViewController()
        default:
            return self
        }
    }

    /// Check if view controller is enhanced
    var isEnhanced: Bool {
        return self is EnhancedSutraFrontViewController ||
               self is EnhancedSutraPageViewController ||
               self is EnhancedSutraIndexViewController ||
               self is EnhancedMediaTableViewController
    }
}

// MARK: - Navigation Controller Extension
extension UINavigationController {

    /// Replace all view controllers with enhanced versions
    func replaceWithEnhancedViewControllers(animated: Bool = true) {
        let enhancedViewControllers = viewControllers.map { $0.toEnhancedVersion() }

        if animated {
            EnhancedViewTransitionCoordinator.animateTransition(
                from: viewControllers.first!,
                to: enhancedViewControllers.first!,
                in: self
            )
        } else {
            setViewControllers(enhancedViewControllers, animated: false)
        }
    }

    /// Check if all view controllers are enhanced
    var hasEnhancedViewControllers: Bool {
        return viewControllers.allSatisfy { $0.isEnhanced }
    }
}

// MARK: - Usage Examples
/*

 // Basic Usage
 let integrationManager = EnhancedViewControllerIntegrationManager.shared
 integrationManager.setupEnhancedViewControllers()

 // Create Enhanced Navigation Controller
 let navController = integrationManager.createEnhancedNavigationController(rootType: .front)

 // Migrate Existing Navigation Controller
 integrationManager.migrateToEnhancedViewControllers(in: existingNavController)

 // Validate Configuration
 let validation = EnhancedViewControllerValidator.validateEnhancedViewControllers()
 if !validation.isValid {
     print("Issues found: \(validation.errorMessage ?? "Unknown")")
 }

 // Monitor Performance
 EnhancedViewControllerPerformanceMonitor.monitorPerformance(of: viewController) { metrics in
     print("Load time: \(metrics.loadTime)s")
     print("Memory usage: \(metrics.memoryUsage)MB")
     print("View complexity: \(metrics.viewComplexity)")
 }

 // Build Custom Configuration
 let config = EnhancedViewControllerConfigurationBuilder()
     .withTheme(.sepia)
     .withAnimations(true)
     .withAccessibility(true)
     .withHapticFeedback(true)
     .build()

 */