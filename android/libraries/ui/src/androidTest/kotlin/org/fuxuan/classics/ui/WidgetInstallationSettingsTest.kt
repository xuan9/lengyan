package org.fuxuan.classics.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class WidgetInstallationSettingsTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun supportedLauncherRequestsAnotherWidgetWithoutShowingTheGuide() {
        var requestCount = 0
        setSettingsContent(
            locale = "zh-Hant",
            installed = true,
            pinRequestSupported = true,
            onRequestPin = {
                requestCount += 1
                true
            },
        )

        composeRule.onNodeWithTag("settings.widget", useUnmergedTree = true)
            .performScrollTo()
            .assertIsDisplayed()
        composeRule.onNodeWithText("已加入，可再次加入", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithTag("settings.widget", useUnmergedTree = true).performClick()

        composeRule.runOnIdle { assertEquals(1, requestCount) }
        composeRule.onNodeWithTag("settings.widget.guide", useUnmergedTree = true)
            .assertDoesNotExist()
    }

    @Test
    fun failedSystemPinRequestFallsBackToReadableStepsAtLargeType() {
        var requestCount = 0
        setSettingsContent(
            locale = "zh-Hans",
            installed = false,
            pinRequestSupported = true,
            fontScale = 2f,
            onRequestPin = {
                requestCount += 1
                false
            },
        )

        composeRule.onNodeWithTag("settings.widget", useUnmergedTree = true)
            .performScrollTo()
            .performClick()

        composeRule.runOnIdle { assertEquals(1, requestCount) }
        composeRule.onNodeWithTag("settings.widget.guide", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithText("添加“今日读经”", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithText("1. 长按桌面空白处。", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithText(
            "3. 找到《楞严经》的“今日读经”，拖到桌面。",
            useUnmergedTree = true,
        ).assertIsDisplayed()
        composeRule.onNodeWithText("经文卡片", useUnmergedTree = true).assertDoesNotExist()
    }

    @Test
    fun unsupportedLauncherShowsTheGuideWithoutAttemptingARequest() {
        var requestCount = 0
        setSettingsContent(
            locale = "zh-Hant",
            installed = false,
            pinRequestSupported = false,
            onRequestPin = {
                requestCount += 1
                true
            },
        )

        composeRule.onNodeWithTag("settings.widget", useUnmergedTree = true)
            .performScrollTo()
            .performClick()

        composeRule.runOnIdle { assertEquals(0, requestCount) }
        composeRule.onNodeWithTag("settings.widget.guide", useUnmergedTree = true)
            .assertIsDisplayed()
    }

    private fun setSettingsContent(
        locale: String,
        installed: Boolean,
        pinRequestSupported: Boolean,
        fontScale: Float = 1f,
        onRequestPin: () -> Boolean,
    ) {
        composeRule.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(density.density, fontScale),
            ) {
                ClassicsTheme(darkTheme = false) {
                    SettingsScreen(
                        preferences = preferences(locale),
                        supportedLocales = listOf("zh-Hant", "zh-Hans"),
                        productTitle = if (locale == "zh-Hans") "楞严经" else "楞嚴經",
                        strings = AppStrings(locale),
                        dailyVerseWidgetInstalled = installed,
                        dailyVerseWidgetPinSupported = pinRequestSupported,
                        onRequestDailyVerseWidgetPin = onRequestPin,
                        onSelectTheme = {},
                        onSelectLocale = {},
                        onSelectFontSize = {},
                        onSetReminder = {},
                    )
                }
            }
        }
    }

    private fun preferences(locale: String) = ProductPreferences(
        theme = ThemePreference.SYSTEM,
        locale = locale,
        fontSizeLevel = 2,
        readingMode = ReadingMode.CHAPTER,
        reminder = ReminderPreferences(),
        audio = AudioPreferences(),
        readingProgress = null,
        audioProgress = null,
        expandedSectionIDs = emptySet(),
    )
}
