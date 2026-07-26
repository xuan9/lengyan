package org.fuxuan.lengyan

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LengyanShellTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun returnToPortraitHome() {
        composeRule.activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        composeRule.waitUntil(timeoutMillis = 10_000) {
            composeRule.activity.resources.configuration.orientation ==
                Configuration.ORIENTATION_PORTRAIT
        }

        repeat(3) {
            composeRule.waitUntil(timeoutMillis = 10_000) {
                homeIsDisplayed() || backIsDisplayed()
            }
            if (homeIsDisplayed()) return
            composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()
            composeRule.waitForIdle()
        }
        composeRule.onNodeWithText("選擇卷目", useUnmergedTree = true).assertIsDisplayed()
    }

    @Test
    fun launchesWithLengyanProductIdentity() {
        composeRule.onNodeWithText("楞嚴經").assertIsDisplayed()
        composeRule.onNodeWithText("大佛頂如來密因修證了義諸菩薩萬行首楞嚴經").assertIsDisplayed()
    }

    @Test
    fun opensTheFirstRealVolumeFromTheHomeScreen() {
        composeRule.onNodeWithText("選擇卷目", useUnmergedTree = true).performClick()
        composeRule.onNodeWithText("楞嚴經 卷一").performClick()

        composeRule.onNodeWithText(
            "如是我聞，一時佛在室羅筏城，祇桓精舍。",
            substring = true,
        ).assertIsDisplayed()
    }

    @Test
    fun readerRestoresAStableTextAnchorAcrossRotation() {
        val container = (composeRule.activity.application as LengyanApplication).container
        runBlocking { container.userPreferencesRepository.saveReadingProgress(null) }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                composeRule.onNodeWithText("開始閱讀", useUnmergedTree = true).assertIsDisplayed()
            }.isSuccess
        }
        composeRule.onNodeWithText("開始閱讀", useUnmergedTree = true).performClick()
        val reader = composeRule.onNode(hasScrollAction(), useUnmergedTree = true)

        repeat(6) {
            reader.performTouchInput { swipeUp(durationMillis = 180) }
            composeRule.waitForIdle()
        }

        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            content.paragraphIndex(currentProgress()?.paragraphID) >= 5
        }
        val beforeRotation = requireNotNull(currentProgress())
        val beforeIndex = content.paragraphIndex(beforeRotation.paragraphID)

        try {
            composeRule.activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            composeRule.waitUntil(timeoutMillis = 10_000) {
                composeRule.activity.resources.configuration.orientation ==
                    Configuration.ORIENTATION_LANDSCAPE
            }
            composeRule.onNode(hasScrollAction(), useUnmergedTree = true).performTouchInput {
                swipeUp(durationMillis = 180)
            }
            composeRule.waitUntil(timeoutMillis = 10_000) {
                (currentProgress()?.updatedAtEpochMilliseconds ?: 0) >
                    beforeRotation.updatedAtEpochMilliseconds
            }

            val afterIndex = content.paragraphIndex(requireNotNull(currentProgress()).paragraphID)
            assertTrue(
                "rotation returned from paragraph $beforeIndex to $afterIndex",
                afterIndex >= beforeIndex - 2,
            )
        } finally {
            composeRule.activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            composeRule.waitUntil(timeoutMillis = 10_000) {
                composeRule.activity.resources.configuration.orientation ==
                    Configuration.ORIENTATION_PORTRAIT
            }
        }
    }

    private fun currentProgress(): ReadingProgress? {
        val container = (composeRule.activity.application as LengyanApplication).container
        return runBlocking { container.userPreferencesRepository.preferences.first().readingProgress }
    }

    private fun homeIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithText("選擇卷目", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun backIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun org.fuxuan.classics.core.content.ScriptureContent.paragraphIndex(
        paragraphID: String?,
    ): Int = paragraphsInReadingOrder().indexOfFirst { it.paragraphID == paragraphID }
}
