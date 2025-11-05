//
//  SettingsViewModelTests.swift
//  LengyanTests
//
//  Comprehensive tests for SettingsViewModel
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class SettingsViewModelTests: QuickSpec {
    override class func spec() {
        describe("SettingsViewModel") {
            var mockPreferencesRepository: MockPreferencesRepository!
            var mockThemeRepository: MockThemeRepository!
            var viewModel: SettingsViewModel!

            beforeEach {
                mockPreferencesRepository = MockPreferencesRepository()
                mockThemeRepository = MockThemeRepository()
                viewModel = SettingsViewModel(
                    preferencesRepository: mockPreferencesRepository,
                    themeRepository: mockThemeRepository
                )
            }

            // MARK: - Initialization Tests

            describe("initialization") {
                it("should set default values") {
                    expect(viewModel.currentTheme).to(equal(.light))
                    expect(viewModel.isSimplifiedChinese).to(beFalse())
                    expect(viewModel.appVersion.isEmpty).to(beFalse())
                }

                it("should load app version from bundle") {
                    // App version should be loaded
                    expect(viewModel.appVersion).toNot(beEmpty())
                }
            }

            // MARK: - Load Settings Tests

            describe("loadSettings()") {
                it("should load settings from repositories") {
                    // Configure mock repositories
                    mockThemeRepository.currentTheme = "dark"
                    mockPreferencesRepository.isSimplifiedChinese = true

                    viewModel.loadSettings()

                    expect(viewModel.currentTheme).to(equal(.dark))
                    expect(viewModel.isSimplifiedChinese).to(beTrue())
                }

                it("should handle invalid theme gracefully") {
                    mockThemeRepository.currentTheme = "invalid_theme"

                    viewModel.loadSettings()

                    expect(viewModel.currentTheme).to(equal(.light)) // Default fallback
                }
            }

            // MARK: - Theme Tests

            describe("setTheme(_:)") {
                context("when setting theme to light") {
                    it("should update current theme") {
                        viewModel.setTheme(.light)

                        expect(viewModel.currentTheme).to(equal(.light))
                    }

                    it("should update repository") {
                        viewModel.setTheme(.light)

                        expect(mockThemeRepository.currentTheme).to(equal("light"))
                        expect(mockThemeRepository.toggleThemeCalled).to(beTrue())
                    }
                }

                context("when setting theme to sepia") {
                    it("should update current theme") {
                        viewModel.setTheme(.sepia)

                        expect(viewModel.currentTheme).to(equal(.sepia))
                    }

                    it("should update repository") {
                        viewModel.setTheme(.sepia)

                        expect(mockThemeRepository.currentTheme).to(equal("sepia"))
                    }
                }

                context("when setting theme to dark") {
                    it("should update current theme") {
                        viewModel.setTheme(.dark)

                        expect(viewModel.currentTheme).to(equal(.dark))
                    }

                    it("should update repository") {
                        viewModel.setTheme(.dark)

                        expect(mockThemeRepository.currentTheme).to(equal("dark"))
                    }
                }

                it("should handle all theme cases") {
                    viewModel.setTheme(.light)
                    expect(viewModel.currentTheme).to(equal(.light))

                    viewModel.setTheme(.sepia)
                    expect(viewModel.currentTheme).to(equal(.sepia))

                    viewModel.setTheme(.dark)
                    expect(viewModel.currentTheme).to(equal(.dark))
                }
            }

            // MARK: - Language Preference Tests

            describe("updateLanguagePreference(isSimplified:)") {
                it("should set simplified Chinese to true") {
                    viewModel.updateLanguagePreference(isSimplified: true)

                    expect(viewModel.isSimplifiedChinese).to(beTrue())
                    expect(mockPreferencesRepository.isSimplifiedChinese).to(beTrue())
                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }

                it("should set simplified Chinese to false") {
                    mockPreferencesRepository.isSimplifiedChinese = true

                    viewModel.updateLanguagePreference(isSimplified: false)

                    expect(viewModel.isSimplifiedChinese).to(beFalse())
                    expect(mockPreferencesRepository.isSimplifiedChinese).to(beFalse())
                }

                it("should persist changes immediately") {
                    viewModel.updateLanguagePreference(isSimplified: true)

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }
            }

            // MARK: - Reset Settings Tests

            describe("resetSettings()") {
                it("should reset theme to light") {
                    viewModel.setTheme(.dark)
                    mockThemeRepository.currentTheme = "dark"

                    viewModel.resetSettings()

                    expect(viewModel.currentTheme).to(equal(.light))
                    expect(mockThemeRepository.currentTheme).to(equal("light"))
                }

                it("should reset language to false") {
                    viewModel.updateLanguagePreference(isSimplified: true)

                    viewModel.resetSettings()

                    expect(viewModel.isSimplifiedChinese).to(beFalse())
                    expect(mockPreferencesRepository.isSimplifiedChinese).to(beFalse())
                }

                it("should persist reset settings") {
                    viewModel.resetSettings()

                    expect(mockPreferencesRepository.saveCalled).to(beTrue())
                }

                it("should reset all settings to defaults") {
                    // Set non-default values
                    viewModel.setTheme(.dark)
                    viewModel.updateLanguagePreference(isSimplified: true)

                    // Reset
                    viewModel.resetSettings()

                    // Verify all reset to defaults
                    expect(viewModel.currentTheme).to(equal(.light))
                    expect(viewModel.isSimplifiedChinese).to(beFalse())
                }
            }

            // MARK: - Theme Enum Tests

            describe("Theme enum") {
                describe("displayName") {
                    it("should return correct display names") {
                        expect(SettingsViewModel.Theme.light.displayName).to(equal("Light"))
                        expect(SettingsViewModel.Theme.sepia.displayName).to(equal("Sepia"))
                        expect(SettingsViewModel.Theme.dark.displayName).to(equal("Dark"))
                    }
                }

                describe("iconName") {
                    it("should return correct icon names") {
                        expect(SettingsViewModel.Theme.light.iconName).to(equal("sun.max"))
                        expect(SettingsViewModel.Theme.sepia.iconName).to(equal("book"))
                        expect(SettingsViewModel.Theme.dark.iconName).to(equal("moon"))
                    }
                }

                describe("rawValue") {
                    it("should have correct raw values") {
                        expect(SettingsViewModel.Theme.light.rawValue).to(equal("light"))
                        expect(SettingsViewModel.Theme.sepia.rawValue).to(equal("sepia"))
                        expect(SettingsViewModel.Theme.dark.rawValue).to(equal("dark"))
                    }
                }
            }

            // MARK: - Integration Tests

            describe("integration with repositories") {
                it("should work with real repository implementations") {
                    let preferencesRepo = PreferencesRepositoryImpl()
                    let themeRepo = ThemeRepositoryImpl()

                    let integratedViewModel = SettingsViewModel(
                        preferencesRepository: preferencesRepo,
                        themeRepository: themeRepo
                    )

                    integratedViewModel.setTheme(.dark)
                    expect(themeRepo.currentTheme).to(equal("dark"))

                    integratedViewModel.updateLanguagePreference(isSimplified: true)
                    expect(preferencesRepo.isSimplifiedChinese).to(beTrue())
                }
            }

            // MARK: - Edge Cases

            describe("edge cases") {
                it("should handle rapid theme changes") {
                    viewModel.setTheme(.light)
                    viewModel.setTheme(.dark)
                    viewModel.setTheme(.sepia)
                    viewModel.setTheme(.dark)

                    expect(viewModel.currentTheme).to(equal(.dark))
                }

                it("should handle rapid language changes") {
                    viewModel.updateLanguagePreference(isSimplified: true)
                    viewModel.updateLanguagePreference(isSimplified: false)
                    viewModel.updateLanguagePreference(isSimplified: true)

                    expect(viewModel.isSimplifiedChinese).to(beTrue())
                }

                it("should handle multiple resets") {
                    viewModel.resetSettings()
                    viewModel.resetSettings()
                    viewModel.resetSettings()

                    expect(viewModel.currentTheme).to(equal(.light))
                    expect(viewModel.isSimplifiedChinese).to(beFalse())
                }
            }

            // MARK: - Persistence Tests

            describe("settings persistence") {
                it("should persist theme changes") {
                    viewModel.setTheme(.dark)

                    // Simulate app restart
                    let newViewModel = SettingsViewModel(
                        preferencesRepository: mockPreferencesRepository,
                        themeRepository: mockThemeRepository
                    )
                    newViewModel.loadSettings()

                    expect(newViewModel.currentTheme).to(equal(.dark))
                }

                it("should persist language changes") {
                    viewModel.updateLanguagePreference(isSimplified: true)

                    // Simulate app restart
                    let newViewModel = SettingsViewModel(
                        preferencesRepository: mockPreferencesRepository,
                        themeRepository: mockThemeRepository
                    )
                    newViewModel.loadSettings()

                    expect(newViewModel.isSimplifiedChinese).to(beTrue())
                }
            }
        }
    }
}

// MARK: - Mock Implementations

class MockPreferencesRepository: PreferencesRepository {
    var isSimplifiedChinese: Bool = false
    var readingProgress: [String: Double] = [:]
    var bookmarks: [String] = []
    var saveCalled = false

    func save() {
        saveCalled = true
    }
}

class MockThemeRepository: ThemeRepository {
    var currentTheme: String = "light"
    var toggleThemeCalled = false

    func toggleTheme() {
        toggleThemeCalled = true
        currentTheme = currentTheme == "light" ? "dark" : "light"
    }
}
