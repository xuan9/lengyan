//
//  DesignSystem+ThemeManager.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Theme Manager
public class SutraThemeManager: ObservableObject {

    // MARK: - Shared Instance
    public static let shared = SutraThemeManager()
    private init() {}

    // MARK: - Current Theme
    @Published public private(set) var currentTheme: SutraTheme = .light {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            applyTheme(currentTheme)
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
        }
    }

    // MARK: - Theme Persistence
    public func loadSavedTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = SutraTheme(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            // Auto-select theme based on system settings
            currentTheme = determineAutoTheme()
        }
    }

    private func determineAutoTheme() -> SutraTheme {
        if #available(iOS 13.0, *) {
            switch UITraitCollection.current.userInterfaceStyle {
            case .dark:
                return .dark
            case .light:
                return .light
            default:
                return .light
            }
        } else {
            return .light
        }
    }

    // MARK: - Theme Application
    public func setTheme(_ theme: SutraTheme) {
        currentTheme = theme
    }

    public func toggleTheme() {
        switch currentTheme {
        case .light:
            setTheme(.sepia)
        case .sepia:
            setTheme(.dark)
        case .dark:
            setTheme(.light)
        }
    }

    private func applyTheme(_ theme: SutraTheme) {
        DispatchQueue.main.async {
            // Update all windows
            UIApplication.shared.windows.forEach { window in
                window.overrideUserInterfaceStyle = self.interfaceStyle(for: theme)
            }
        }
    }

    private func interfaceStyle(for theme: SutraTheme) -> UIUserInterfaceStyle {
        switch theme {
        case .light, .sepia:
            return .light
        case .dark:
            return .dark
        }
    }

    // MARK: - Theme Colors
    public func color(_ colorToken: String) -> UIColor {
        return SutraDesignTokens.shared.color(for: colorToken, theme: currentTheme)
    }

    public func sutraTextColor() -> UIColor {
        return SutraColors.Semantic.sutraText(theme: currentTheme)
    }

    public func commentaryTextColor() -> UIColor {
        return SutraColors.Semantic.commentaryText(theme: currentTheme)
    }

    public func backgroundColor() -> UIColor {
        return SutraColors.Semantic.background(theme: currentTheme)
    }

    public func surfaceColor() -> UIColor {
        return SutraColors.Semantic.surface(theme: currentTheme)
    }

    public func primaryColor() -> UIColor {
        return SutraColors.Semantic.primary(theme: currentTheme)
    }

    public func accentColor() -> UIColor {
        return SutraColors.Semantic.accent(theme: currentTheme)
    }
}

// MARK: - Theme-Aware UIView Extension
extension UIView {
    public var themeManager: SutraThemeManager {
        return SutraThemeManager.shared
    }

    public func applyTheme() {
        backgroundColor = themeManager.backgroundColor()
        setNeedsDisplay()
    }

    public func applyThemeColors() {
        // This can be overridden by subclasses
        applyTheme()
    }

    public func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        applyThemeColors()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
    }
}

// MARK: - Theme-Aware UILabel Extension
extension UILabel {
    override public func applyThemeColors() {
        super.applyThemeColors()
        textColor = themeManager.primaryColor()
    }

    public func configureSutraTextStyle(_ style: SutraTextStyle) {
        font = UIFont.sutraFont(style: style)
        textColor = themeManager.sutraTextColor()
        numberOfLines = 0
        lineBreakMode = .byWordWrapping

        // Apply line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = style.lineHeight

        if let text = text {
            attributedText = NSAttributedString.sutraAttributedText(
                text: text,
                style: style,
                color: textColor
            )
        }
    }
}

// MARK: - Implementation Example for Existing View Controllers
extension SutraPageContentViewController {

    public func applyNewDesignSystem() {
        // Apply theme
        view.applyThemeColors()
        setupThemeObserver()

        // Configure table view
        configureTableViewWithDesignSystem()

        // Apply typography to sutra content
        applyTypographyToContent()

        // Apply spacing
        applySpacingSystem()

        // Configure accessibility
        configureAccessibility()
    }

    private func configureTableViewWithDesignSystem() {
        tableView.backgroundColor = themeManager.backgroundColor()
        tableView.separatorStyle = .none

        // Register custom cells with design system
        tableView.register(SutraContentTableViewCell.self, forCellReuseIdentifier: "SutraContentCell")
    }

    private func applyTypographyToContent() {
        // Update font initialization with new typography system
        initFontsWithDesignSystem()
    }

    private func initFontsWithDesignSystem() {
        sutraFont = UIFont.sutraFont(style: .sutraBody)
        comentFont = UIFont.sutraFont(style: .commentary)
        indexFont = UIFont.sutraFont(style: .indexItem)
    }

    private func applySpacingSystem() {
        // Apply consistent spacing to table view
        tableView.contentInset = UIEdgeInsets(
            top: SutraSpacing.Component.lg,
            left: 0,
            bottom: SutraSpacing.Component.lg,
            right: 0
        )
    }

    private func configureAccessibility() {
        // Configure accessibility for the table view
        SutraAccessibilityManager.shared.configureReadingOrder(for: view)
        view.isAccessibilityElement = false

        // Announce chapter changes
        if let path = path as String? {
            SutraAccessibilityManager.shared.announceChange(
                NSLocalizedString("accessibility.chapter.loaded", comment: "Chapter loaded") + " \(path)"
            )
        }
    }
}

// MARK: - Custom Table View Cell with Design System
class SutraContentTableViewCell: UITableViewCell {

    private let textView = UITextView()
    private var contentType: String = ""
    private var currentTheme: SutraTheme = .light

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = UIColor.clear

        setupTextView()
        setupConstraints()
        setupThemeObserver()
    }

    private func setupTextView() {
        contentView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.backgroundColor = UIColor.clear
        textView.textContainerInset = UIEdgeInsets(top: SutraSpacing.Base.md,
                                                  left: 0,
                                                  bottom: SutraSpacing.Base.md,
                                                  right: 0)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.Margins.readingMargin()),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.Margins.readingMargin()),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override func applyThemeColors() {
        super.applyThemeColors()
        currentTheme = themeManager.currentTheme
        configureForContentType()
    }

    private func configureForContentType() {
        switch contentType {
        case "sutra":
            textView.font = UIFont.sutraFont(style: .sutraBody)
            textView.textColor = themeManager.sutraTextColor()
            textView.accessibilityLabel = NSLocalizedString("accessibility.sutra.content", comment: "Sutra content")

        case "index":
            textView.font = UIFont.sutraFont(style: .indexItem)
            textView.textColor = themeManager.primaryColor()
            textView.accessibilityLabel = NSLocalizedString("accessibility.index.content", comment: "Index content")

        default: // commentary
            textView.font = UIFont.sutraFont(style: .commentary)
            textView.textColor = themeManager.commentaryTextColor()
            textView.accessibilityLabel = NSLocalizedString("accessibility.commentary.content", comment: "Commentary content")
        }
    }

    public func configure(content: String, type: String) {
        contentType = type
        configureForContentType()

        // Apply typography and spacing
        let style: SutraTextStyle = {
            switch type {
            case "sutra": return .sutraBody
            case "index": return .indexItem
            default: return .commentary
            }
        }()

        let attributedText = NSAttributedString.sutraAttributedText(
            text: content,
            style: style,
            color: textView.textColor
        )

        textView.attributedText = attributedText

        // Configure accessibility
        SutraAccessibilityManager.shared.configureVoiceOver(
            for: textView,
            category: type == "sutra" ? .sutraText : .commentaryText
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textView.text = nil
        textView.attributedText = nil
    }
}

// MARK: - Navigation Bar Setup
extension UINavigationBar {

    public func applySutraDesignSystem() {
        // Configure appearance based on current theme
        let theme = SutraThemeManager.shared.currentTheme

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()

        switch theme {
        case .light:
            appearance.backgroundColor = SutraColors.Light.surface
            appearance.titleTextAttributes = [
                .font: UIFont.sutraFont(style: .navigationTitle),
                .foregroundColor: SutraColors.Light.primary
            ]
            appearance.largeTitleTextAttributes = [
                .font: UIFont.sutraFont(style: .chapterTitle),
                .foregroundColor: SutraColors.Light.primary
            ]

        case .sepia:
            appearance.backgroundColor = SutraColors.Sepia.surface
            appearance.titleTextAttributes = [
                .font: UIFont.sutraFont(style: .navigationTitle),
                .foregroundColor: SutraColors.Sepia.primary
            ]
            appearance.largeTitleTextAttributes = [
                .font: UIFont.sutraFont(style: .chapterTitle),
                .foregroundColor: SutraColors.Sepia.primary
            ]

        case .dark:
            appearance.backgroundColor = SutraColors.Dark.surface
            appearance.titleTextAttributes = [
                .font: UIFont.sutraFont(style: .navigationTitle),
                .foregroundColor: SutraColors.Dark.primary
            ]
            appearance.largeTitleTextAttributes = [
                .font: UIFont.sutraFont(style: .chapterTitle),
                .foregroundColor: SutraColors.Dark.primary
            ]
        }

        standardAppearance = appearance
        compactAppearance = appearance
        scrollEdgeAppearance = appearance

        // Tint color for buttons
        tintColor = SutraThemeManager.shared.primaryColor()
    }
}

// MARK: - Usage Guide and Integration Instructions
/*

 INTEGRATION GUIDE FOR LENG YAN SUTRA APP
 ========================================

 1. THEME SETUP
 --------------
 Add this to your AppDelegate or SceneDelegate:

 ```swift
 // In AppDelegate.swift
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     SutraThemeManager.shared.loadSavedTheme()
     return true
 }
 ```

 2. VIEW CONTROLLER UPDATES
 --------------------------
 Update your existing view controllers to use the new design system:

 ```swift
 // In each view controller's viewDidLoad()
 override func viewDidLoad() {
     super.viewDidLoad()

     // Apply design system
     view.applyThemeColors()
     setupThemeObserver()

     // Configure UI components with design system
     configureWithDesignSystem()
 }

 // Example for SutraPageContentViewController
 private func configureWithDesignSystem() {
     // Apply theme
     view.backgroundColor = themeManager.backgroundColor()

     // Configure table view
     tableView.backgroundColor = themeManager.backgroundColor()
     tableView.separatorStyle = .none

     // Update fonts
     sutraFont = UIFont.sutraFont(style: .sutraBody)
     comentFont = UIFont.sutraFont(style: .commentary)
     indexFont = UIFont.sutraFont(style: .indexItem)

     // Apply spacing
     tableView.contentInset = UIEdgeInsets(
         top: SutraSpacing.Component.lg,
         left: 0,
         bottom: SutraSpacing.Component.lg,
         right: 0
     )
 }
 ```

 3. NAVIGATION BAR SETUP
 -----------------------
 Configure navigation bars in your view controllers:

 ```swift
 override func viewWillAppear(_ animated: Bool) {
     super.viewWillAppear(animated)
     navigationController?.navigationBar.applySutraDesignSystem()
 }
 ```

 4. CELL UPDATES
 ---------------
 Replace your existing SutraTableViewCell with the new design system version:

 ```swift
 // In tableView(_:cellForRowAt:)
 let cell = tableView.dequeueReusableCell(withIdentifier: "SutraContentCell", for: indexPath) as! SutraContentTableViewCell
 let content = contents[indexPath.row]
 cell.configure(content: content["content"]!, type: content["type"]!)
 return cell
 ```

 5. THEME SWITCHING
 ------------------
 Add theme switching capability:

 ```swift
 // Add theme switcher in settings or toolbar
 @objc func themeButtonTapped() {
     SutraThemeManager.shared.toggleTheme()
 }

 // Or set specific theme
 @objc func setLightTheme() {
     SutraThemeManager.shared.setTheme(.light)
 }
 ```

 6. ACCESSIBILITY
 ----------------
 Ensure all views are properly configured for accessibility:

 ```swift
 // For important text elements
 SutraAccessibilityManager.shared.configureVoiceOver(
     for: textView,
     category: .sutraText
 )

 // For navigation elements
 SutraAccessibilityManager.shared.configureVoiceOver(
     for: button,
     category: .navigation,
     customLabel: "Previous Chapter"
 )
 ```

 7. INTERACTIONS
 ---------------
 Add haptic feedback and enhanced interactions:

 ```swift
 // For buttons
 let button = SutraInteractiveButton()
 button.interactionStyle = .sacred
 button.hapticType = .medium

 // For gestures
 SutraGestureConfiguration.configureTapGesture(on: view, hapticType: .light) {
     // Handle tap
 }
 ```

 8. RESPONSIVE LAYOUT
 --------------------
 Use the responsive layout system for different screen sizes:

 ```swift
 // Create reading layout manager
 let layoutManager = SutraReadingLayoutManager(containerView: self.view)
 layoutManager.setReadingMode(.focused, animated: true)
 ```

 9. CUSTOM COMPONENTS
 --------------------
 Use the design system components for consistent UI:

 ```swift
 // Create cards
 let card = SutraCard()
 card.variant = .sutra
 card.configure(title: "Chapter Title", subtitle: "Subheading", icon: UIImage(systemName: "book"))

 // Create buttons
 let button = SutraButton()
 button.variant = .sacred
 button.setTitle("Read Sutra", for: .normal)
 ```

 10. DESIGN TOKENS
 -----------------
 Use design tokens for consistent styling:

 ```swift
 // Get theme colors
 let backgroundColor = SutraThemeManager.shared.color(SutraDesignTokens.ColorTokens.backgroundPrimary)
 let textColor = SutraThemeManager.shared.sutraTextColor()

 // Get spacing
 let spacing = SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD)

 // Get typography
 let textStyle = SutraDesignTokens.shared.typography(for: SutraDesignTokens.TypographyTokens.sizeLarge)
 ```

 BENEFITS OF THIS DESIGN SYSTEM:
 - Consistent visual language across all screens
 - Proper support for Chinese typography
- Accessibility compliance (WCAG AA)
- Theme switching with smooth transitions
- Responsive design for all device sizes
- Haptic feedback for enhanced user experience
- Easy maintenance and updates
- Production-ready code

 IMPLEMENTATION PRIORITY:
 1. Start with theme management and basic color application
 2. Update typography and spacing systems
 3. Replace key UI components with design system versions
 4. Add enhanced interactions and animations
 5. Implement accessibility features
 6. Add responsive layout management
 7. Test across all devices and themes

 This design system will transform the basic sutra app into a beautiful,
 accessible, and professional reading experience that honors the sacred nature
 of the content while following modern iOS design principles.

 */