//
//  SettingsViewModel.swift
//  Lengyan
//
//  ViewModel for settings view
//  Manages theme, language, and app preferences
//

import SwiftUI

/// ViewModel for settings view
/// Handles app configuration
@MainActor
public final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentTheme: Theme = .light
    @Published var isSimplifiedChinese: Bool = false
    @Published var appVersion: String = "1.0.0"

    // MARK: - Dependencies

    private let preferencesRepository: PreferencesRepository
    private let themeRepository: ThemeRepository

    // MARK: - Initialization

    public init(
        preferencesRepository: PreferencesRepository,
        themeRepository: ThemeRepository
    ) {
        self.preferencesRepository = preferencesRepository
        self.themeRepository = themeRepository
        loadAppVersion()
    }

    // MARK: - Public Methods

    /// Load settings from repositories
    public func loadSettings() {
        currentTheme = Theme(rawValue: themeRepository.currentTheme) ?? .light
        isSimplifiedChinese = preferencesRepository.isSimplifiedChinese
    }

    /// Set theme
    public func setTheme(_ theme: Theme) {
        currentTheme = theme
        themeRepository.currentTheme = theme.rawValue
        themeRepository.toggleTheme()
    }

    /// Update language preference
    public func updateLanguagePreference(isSimplified: Bool) {
        isSimplifiedChinese = isSimplified
        preferencesRepository.isSimplifiedChinese = isSimplified
        preferencesRepository.save()
    }

    /// Reset all settings to defaults
    public func resetSettings() {
        currentTheme = .light
        isSimplifiedChinese = false

        themeRepository.currentTheme = Theme.light.rawValue
        preferencesRepository.isSimplifiedChinese = false
        preferencesRepository.save()
    }

    // MARK: - Private Methods

    private func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
    }
}

// MARK: - Theme Enum

extension SettingsViewModel {
    public enum Theme: String, CaseIterable {
        case light = "light"
        case sepia = "sepia"
        case dark = "dark"

        public var displayName: String {
            switch self {
            case .light:
                return "Light"
            case .sepia:
                return "Sepia"
            case .dark:
                return "Dark"
            }
        }

        public var iconName: String {
            switch self {
            case .light:
                return "sun.max"
            case .sepia:
                return "book"
            case .dark:
                return "moon"
            }
        }
    }
}
