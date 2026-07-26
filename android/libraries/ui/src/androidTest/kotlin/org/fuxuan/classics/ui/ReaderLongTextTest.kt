package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ReaderLongTextTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun laysOutAndReachesAllTwentyThousandCharactersAtDefaultScale() {
        verifyCompleteLongText(fontScale = 1f)
    }

    @Test
    fun enlargesWithoutTruncatingTwentyThousandCharactersAtDoubleScale() {
        verifyCompleteLongText(fontScale = 2f)
    }

    private fun verifyCompleteLongText(fontScale: Float) {
        val text = "甲乙丙丁".repeat(5_000)
        var layoutResult: TextLayoutResult? = null
        lateinit var scrollState: androidx.compose.foundation.ScrollState

        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(
                    density = deviceDensity.density,
                    fontScale = fontScale,
                ),
            ) {
                ClassicsTheme(darkTheme = false) {
                    scrollState = rememberScrollState()
                    Column(
                        modifier = Modifier
                            .width(320.dp)
                            .height(600.dp)
                            .verticalScroll(scrollState),
                    ) {
                        ReaderText(
                            text = text,
                            fontSizeLevel = 2,
                            onTextLayout = { layoutResult = it },
                        )
                        Text(text = "END", modifier = Modifier.testTag(END_TAG))
                    }
                }
            }
        }

        composeRule.waitUntil(timeoutMillis = 20_000) {
            layoutResult != null && scrollState.maxValue > 0
        }
        val layout = requireNotNull(layoutResult)
        assertEquals(text, layout.layoutInput.text.text)
        assertEquals(24.sp, layout.layoutInput.style.fontSize)
        assertEquals(42.sp, layout.layoutInput.style.lineHeight)
        assertEquals(fontScale, layout.layoutInput.density.fontScale, 0f)
        assertTrue(layout.lineCount > 100)
        assertEquals(text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = false))
        assertFalse(layout.didOverflowWidth)
        assertFalse(layout.didOverflowHeight)

        runBlocking { scrollState.scrollTo(scrollState.maxValue) }
        composeRule.waitForIdle()
        composeRule.onNodeWithTag(END_TAG).assertIsDisplayed()
    }

    private companion object {
        const val END_TAG = "reader-long-text-end"
    }
}
