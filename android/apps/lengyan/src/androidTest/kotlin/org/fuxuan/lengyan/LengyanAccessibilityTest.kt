package org.fuxuan.lengyan

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.tryPerformAccessibilityChecks
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.content.DocumentedSourceRole
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.ThemePreference
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 34)
class LengyanAccessibilityTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun prepareApp() {
        composeRule.activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        composeRule.waitUntil(timeoutMillis = 10_000) {
            composeRule.activity.resources.configuration.orientation ==
                Configuration.ORIENTATION_PORTRAIT
        }
        val container = (composeRule.activity.application as LengyanApplication).container
        runBlocking {
            container.userPreferencesRepository.setTheme(ThemePreference.SYSTEM)
            container.userPreferencesRepository.setLocale("zh-Hant")
            container.userPreferencesRepository.setFontSizeLevel(2)
            container.userPreferencesRepository.saveReadingProgress(null)
            container.favoriteRepository.replace(
                editionID = container.bookRepository.book().editionID,
                favorites = emptyList(),
            )
        }
        composeRule.activityRule.scenario.recreate()
        composeRule.waitUntil(timeoutMillis = 10_000) { homeIsDisplayed() }
        composeRule.enableAccessibilityChecks()
    }

    @Test
    fun primaryReadingFlowPassesAutomatedAccessibilityChecks() {
        checkCurrentScreen()

        composeRule.onNodeWithTag("home.directory", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("outline.list", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()
        composeRule.onNodeWithText("開始閱讀", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("reader.scroll", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("home.search", useUnmergedTree = true).performClick()
        composeRule.onNode(hasSetTextAction(), useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()
    }

    @Test
    fun topLevelDestinationsAndDarkThemePassAutomatedAccessibilityChecks() {
        composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("favorites.empty", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()

        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val paragraph = content.paragraphsInReadingOrder().first()
        runBlocking {
            container.favoriteRepository.add(
                Favorite.paragraph(
                    productID = content.productID,
                    editionID = content.editionID,
                    sectionID = paragraph.sectionID,
                    paragraphID = paragraph.paragraphID,
                    createdAtEpochMilliseconds = 1,
                ),
            )
        }
        composeRule.onNodeWithTag(
            "favorite.row.paragraph:${paragraph.paragraphID}",
            useUnmergedTree = true,
        ).assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithTag("bottom.settings", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("settings.screen", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithTag("settings.widget", useUnmergedTree = true)
            .performScrollTo()
            .assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithTag("settings.reminder.enabled", useUnmergedTree = true)
            .performScrollTo()
            .assertIsDisplayed()
        checkCurrentScreen()

        composeRule.onNodeWithTag("settings.source", useUnmergedTree = true)
            .performScrollTo()
            .performClick()
        composeRule.onNodeWithTag("source.screen", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()
        val collationSource = runBlocking { container.bookRepository.sourceManifest() }
            .sources
            .first { it.role == DocumentedSourceRole.COLLATION_REFERENCE }
        composeRule.onNodeWithTag("source.list", useUnmergedTree = true)
            .performScrollToNode(
                hasTestTag("source.record.${collationSource.sourceID}"),
            )
        checkCurrentScreen()
        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()

        composeRule.onNodeWithTag("settings.privacy", useUnmergedTree = true)
            .performScrollTo()
            .performClick()
        composeRule.onNodeWithTag("privacy.screen", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()
        composeRule.onNodeWithText("解除安裝與備份", useUnmergedTree = true)
            .performScrollTo()
            .assertIsDisplayed()
        checkCurrentScreen()
        composeRule.onNodeWithTag("privacy.open-policy", useUnmergedTree = true)
            .assertDoesNotExist()
        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()

        composeRule.onNodeWithTag("settings.theme.dark", useUnmergedTree = true)
            .performScrollTo()
            .performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.userPreferencesRepository.preferences.first().theme ==
                    ThemePreference.DARK
            }
        }
        composeRule.onNodeWithTag("settings.theme.dark", useUnmergedTree = true)
            .assertIsSelected()
        checkCurrentScreen()

        composeRule.onNodeWithTag("bottom.reading", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("home.directory", useUnmergedTree = true).assertIsDisplayed()
        checkCurrentScreen()
    }

    private fun checkCurrentScreen() {
        composeRule.onRoot().tryPerformAccessibilityChecks()
    }

    private fun homeIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithTag("home.directory", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess
}
