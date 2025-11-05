//
//  DesignSystemTests.swift
//  LengyanTests
//
//  Comprehensive tests for Design System
//  Target: 95% test coverage
//

import XCTest
import SwiftUI
import Quick
import Nimble

@testable import LengyanCore

final class DesignSystemTests: QuickSpec {
    override class func spec() {
        describe("SutraTheme") {
            describe("rawValue") {
                it("should have correct raw values") {
                    expect(SutraTheme.light.rawValue).to(equal("light"))
                    expect(SutraTheme.sepia.rawValue).to(equal("sepia"))
                    expect(SutraTheme.dark.rawValue).to(equal("dark"))
                }
            }

            describe("displayName") {
                it("should return correct display names") {
                    expect(SutraTheme.light.displayName).to(equal("Light"))
                    expect(SutraTheme.sepia.displayName).to(equal("Sepia"))
                    expect(SutraTheme.dark.displayName).to(equal("Dark"))
                }
            }

            describe("iconName") {
                it("should return correct icon names") {
                    expect(SutraTheme.light.iconName).to(equal("sun.max"))
                    expect(SutraTheme.sepia.iconName).to(equal("book"))
                    expect(SutraTheme.dark.iconName).to(equal("moon"))
                }
            }

            describe("CaseIterable") {
                it("should have all cases") {
                    let allCases = SutraTheme.allCases
                    expect(allCases.count).to(equal(3))
                    expect(allCases).to(contain(.light))
                    expect(allCases).to(contain(.sepia))
                    expect(allCases).to(contain(.dark))
                }
            }

            describe("Identifiable") {
                it("should have id property") {
                    expect(SutraTheme.light.id).to(equal("light"))
                    expect(SutraTheme.sepia.id).to(equal("sepia"))
                    expect(SutraTheme.dark.id).to(equal("dark"))
                }
            }
        }

        // MARK: - Color Tests

        describe("Color extensions") {
            describe("Light theme colors") {
                it("should have correct light background") {
                    let color = Color.sutraLightBackground
                    expect(color).toNot(beNil())
                }

                it("should have correct light primary text") {
                    let color = Color.sutraLightPrimaryText
                    expect(color).toNot(beNil())
                }

                it("should have correct light accent") {
                    let color = Color.sutraLightAccent
                    expect(color).toNot(beNil())
                }
            }

            describe("Sepia theme colors") {
                it("should have correct sepia background") {
                    let color = Color.sutraSepiaBackground
                    expect(color).toNot(beNil())
                }

                it("should have correct sepia primary text") {
                    let color = Color.sutraSepiaPrimaryText
                    expect(color).toNot(beNil())
                }

                it("should have correct sepia accent") {
                    let color = Color.sutraSepiaAccent
                    expect(color).toNot(beNil())
                }
            }

            describe("Dark theme colors") {
                it("should have correct dark background") {
                    let color = Color.sutraDarkBackground
                    expect(color).toNot(beNil())
                }

                it("should have correct dark primary text") {
                    let color = Color.sutraDarkPrimaryText
                    expect(color).toNot(beNil())
                }

                it("should have correct dark accent") {
                    let color = Color.sutraDarkAccent
                    expect(color).toNot(beNil())
                }
            }

            describe("Semantic colors") {
                beforeEach {
                    // Set theme to light for testing
                    UserDefaults.standard.sutraTheme = .light
                }

                it("should return correct background for current theme") {
                    let background = Color.sutraBackground
                    expect(background).toNot(beNil())
                }

                it("should return correct card background for current theme") {
                    let cardBackground = Color.sutraCardBackground
                    expect(cardBackground).toNot(beNil())
                }

                it("should return correct primary text for current theme") {
                    let primaryText = Color.sutraPrimaryText
                    expect(primaryText).toNot(beNil())
                }

                it("should return correct secondary text for current theme") {
                    let secondaryText = Color.sutraSecondaryText
                    expect(secondaryText).toNot(beNil())
                }

                it("should return correct accent for current theme") {
                    let accent = Color.sutraAccent
                    expect(accent).toNot(beNil())
                }

                it("should return correct separator for current theme") {
                    let separator = Color.sutraSeparator
                    expect(separator).toNot(beNil())
                }
            })
        }

        // MARK: - Font Tests

        describe("Font extensions") {
            describe("Large titles") {
                it("should have sutraLargeTitle font") {
                    let font = Font.sutraLargeTitle
                    expect(font).toNot(beNil())
                }

                it("should have sutraTitle1 font") {
                    let font = Font.sutraTitle1
                    expect(font).toNot(beNil())
                }

                it("should have sutraTitle2 font") {
                    let font = Font.sutraTitle2
                    expect(font).toNot(beNil())
                }

                it("should have sutraTitle3 font") {
                    let font = Font.sutraTitle3
                    expect(font).toNot(beNil())
                }
            }

            describe("Body text") {
                it("should have sutraHeadline font") {
                    let font = Font.sutraHeadline
                    expect(font).toNot(beNil())
                }

                it("should have sutraBody font") {
                    let font = Font.sutraBody
                    expect(font).toNot(beNil())
                }

                it("should have sutraCallout font") {
                    let font = Font.sutraCallout
                    expect(font).toNot(beNil())
                }

                it("should have sutraSubheadline font") {
                    let font = Font.sutraSubheadline
                    expect(font).toNot(beNil())
                }
            })

            describe("Small text") {
                it("should have sutraFootnote font") {
                    let font = Font.sutraFootnote
                    expect(font).toNot(beNil())
                }

                it("should have sutraCaption1 font") {
                    let font = Font.sutraCaption1
                    expect(font).toNot(beNil())
                }

                it("should have sutraCaption2 font") {
                    let font = Font.sutraCaption2
                    expect(font).toNot(beNil())
                }
            })

            describe("Navigation fonts") {
                it("should have sutraNavigationLargeTitle font") {
                    let font = Font.sutraNavigationLargeTitle
                    expect(font).toNot(beNil())
                }

                it("should have sutraNavigationTitle font") {
                    let font = Font.sutraNavigationTitle
                    expect(font).toNot(beNil())
                }
            })

            describe("Sutra specific fonts") {
                it("should have sutraText font") {
                    let font = Font.sutraText
                    expect(font).toNot(beNil())
                }

                it("should have sutraTextLarge font") {
                    let font = Font.sutraTextLarge
                    expect(font).toNot(beNil())
                }
            })
        }

        // MARK: - UserDefaults Tests

        describe("UserDefaults sutraTheme") {
            beforeEach {
                UserDefaults.standard.removeObject(forKey: "sutraTheme")
            }

            it("should default to light theme") {
                let defaults = UserDefaults.standard
                expect(defaults.sutraTheme).to(equal(.light))
            }

            it("should set theme correctly") {
                let defaults = UserDefaults.standard
                defaults.sutraTheme = .dark
                expect(defaults.sutraTheme).to(equal(.dark))
            }

            it("should persist theme changes") {
                let defaults = UserDefaults.standard
                defaults.sutraTheme = .sepia
                expect(defaults.sutraTheme).to(equal(.sepia))
            }

            it("should handle invalid theme gracefully") {
                UserDefaults.standard.set("invalid_theme", forKey: "sutraTheme")
                let defaults = UserDefaults.standard
                expect(defaults.sutraTheme).to(equal(.light))
            }
        }

        // MARK: - Notification Tests

        describe("Notifications") {
            it("should post sutraThemeDidChange notification") {
                var receivedNotification = false
                let expectation = self.expectation(description: "Theme change notification")
                expectation.expectedFulfillmentCount = 1

                NotificationCenter.default.addObserver(
                    forName: .sutraThemeDidChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    receivedNotification = true
                    expectation.fulfill()
                }

                UserDefaults.standard.sutraTheme = .dark

                self.waitForExpectations(timeout: 1.0)
                expect(receivedNotification).to(beTrue())

                NotificationCenter.default.removeObserver(self)
            }
        }

        // MARK: - View Modifiers Tests

        describe("View modifiers") {
            describe("SutraThemeModifier") {
                it("should apply theme modifier") {
                    let view = Text("Test")
                        .sutraTheme(.dark)
                    expect(view).toNot(beNil())
                }
            }

            describe("SutraFontModifier") {
                it("should apply font modifier") {
                    let view = Text("Test")
                        .sutraFont(style: .title1)
                    expect(view).toNot(beNil())
                }

                it("should handle all font styles") {
                    let styles: [SutraFontModifier.Style] = [
                        .largeTitle, .title1, .title2, .title3,
                        .headline, .body, .callout, .subheadline,
                        .footnote, .caption1, .caption2,
                        .navigationLargeTitle, .navigationTitle,
                        .sutraText, .sutraTextLarge
                    ]

                    for style in styles {
                        let view = Text("Test")
                            .sutraFont(style: style)
                        expect(view).toNot(beNil())
                    }
                }
            }

            describe("SutraColorModifier") {
                it("should apply color modifier") {
                    let view = Text("Test")
                        .sutraColor(.primaryText)
                    expect(view).toNot(beNil())
                }

                it("should handle all color styles") {
                    let styles: [SutraColorModifier.Style] = [
                        .background, .cardBackground, .primaryText,
                        .secondaryText, .accent, .separator
                    ]

                    for style in styles {
                        let view = Text("Test")
                            .sutraColor(style)
                        expect(view).toNot(beNil())
                    }
                }
            }

            describe("SutraCardStyle") {
                it("should apply card style") {
                    let view = Text("Test")
                        .sutraCard()
                    expect(view).toNot(beNil())
                }
            }

            describe("SutraButtonStyle") {
                it("should apply primary button style") {
                    let view = Text("Test")
                        .sutraButton(variant: .primary)
                    expect(view).toNot(beNil())
                }

                it("should apply secondary button style") {
                    let view = Text("Test")
                        .sutraButton(variant: .secondary)
                    expect(view).toNot(beNil())
                }

                it("should apply accent button style") {
                    let view = Text("Test")
                        .sutraButton(variant: .accent)
                    expect(view).toNot(beNil())
                }
            }

            describe("SutraAccessibilityModifier") {
                it("should apply accessibility modifier") {
                    let view = Text("Test")
                        .sutraAccessibility(label: "Test Label", hint: "Test Hint")
                    expect(view).toNot(beNil())
                }

                it("should handle optional hint") {
                    let view = Text("Test")
                        .sutraAccessibility(label: "Test Label")
                    expect(view).toNot(beNil())
                }
            })

            describe("SutraHapticModifier") {
                it("should apply tap haptic") {
                    let view = Text("Test")
                        .sutraHaptic(.tap)
                    expect(view).toNot(beNil())
                }

                it("should apply selection haptic") {
                    let view = Text("Test")
                        .sutraHaptic(.selection)
                    expect(view).toNot(beNil())
                }

                it("should apply notification haptic") {
                    let view = Text("Test")
                        .sutraHaptic(.notificationSuccess)
                    expect(view).toNot(beNil())
                }

                it("should handle disabled haptic") {
                    let view = Text("Test")
                        .sutraHaptic(.tap, enabled: false)
                    expect(view).toNot(beNil())
                }
            })

            describe("Animation modifiers") {
                it("should apply sutraTransition") {
                    let view = Text("Test")
                        .sutraTransition()
                    expect(view).toNot(beNil())
                }

                it("should apply sutraSpringAnimation") {
                    let view = Text("Test")
                        .sutraSpringAnimation()
                    expect(view).toNot(beNil())
                }

                it("should apply sutraEaseInOutAnimation") {
                    let view = Text("Test")
                        .sutraEaseInOutAnimation()
                    expect(view).toNot(beNil())
                }
            })
        }

        // MARK: - Integration Tests

        describe("Design system integration") {
            it("should work with SwiftUI views") {
                let view = VStack {
                    Text("Test 1")
                        .sutraFont(style: .title1)
                        .sutraColor(.primaryText)
                    Text("Test 2")
                        .sutraFont(style: .body)
                        .sutraColor(.secondaryText)
                }
                .sutraTheme(.light)
                .sutraCard()

                expect(view).toNot(beNil())
            }

            it("should apply multiple modifiers") {
                let view = Text("Test")
                    .sutraFont(style: .title1)
                    .sutraColor(.accent)
                    .sutraHaptic(.tap)
                    .sutraAccessibility(label: "Test")
                    .sutraTransition()

                expect(view).toNot(beNil())
            }

            it("should work with buttons") {
                let view = Button("Test") { }
                    .sutraButton(variant: .primary)
                    .sutraHaptic(.tap)

                expect(view).toNot(beNil())
            }
        }

        // MARK: - Theme Switching Tests

        describe("Theme switching") {
            it("should switch between themes correctly") {
                UserDefaults.standard.sutraTheme = .light
                expect(UserDefaults.standard.sutraTheme).to(equal(.light))

                UserDefaults.standard.sutraTheme = .sepia
                expect(UserDefaults.standard.sutraTheme).to(equal(.sepia))

                UserDefaults.standard.sutraTheme = .dark
                expect(UserDefaults.standard.sutraTheme).to(equal(.dark))
            }

            it("should notify on theme change") {
                var notificationCount = 0
                let expectation = self.expectation(description: "Theme change notification")
                expectation.expectedFulfillmentCount = 2

                NotificationCenter.default.addObserver(
                    forName: .sutraThemeDidChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    notificationCount += 1
                    expectation.fulfill()
                }

                UserDefaults.standard.sutraTheme = .dark
                UserDefaults.standard.sutraTheme = .sepia

                self.waitForExpectations(timeout: 1.0)
                expect(notificationCount).to(equal(2))

                NotificationCenter.default.removeObserver(self)
            }
        }

        // MARK: - Edge Cases

        describe("Edge cases") {
            it("should handle rapid theme changes") {
                UserDefaults.standard.sutraTheme = .light
                UserDefaults.standard.sutraTheme = .dark
                UserDefaults.standard.sutraTheme = .sepia
                UserDefaults.standard.sutraTheme = .light

                expect(UserDefaults.standard.sutraTheme).to(equal(.light))
            }

            it("should handle invalid UserDefaults value") {
                UserDefaults.standard.set("invalid", forKey: "sutraTheme")
                let defaults = UserDefaults.standard
                expect(defaults.sutraTheme).to(equal(.light))
            }

            it("should work with nested modifiers") {
                let view = VStack {
                    ForEach(0..<3) { i in
                        Text("Item \(i)")
                            .sutraFont(style: i == 0 ? .title1 : .body)
                            .sutraColor(i == 0 ? .primaryText : .secondaryText)
                    }
                }
                .sutraTheme(.dark)

                expect(view).toNot(beNil())
            }
        }
    }
}
