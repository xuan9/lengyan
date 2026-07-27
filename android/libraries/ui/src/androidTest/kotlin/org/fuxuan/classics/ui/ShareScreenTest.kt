package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun longDocumentOpensWithALightweightPreviewAndNoEagerImageAction() {
        var imageActionCount = 0
        val document = longDocument()
        assertEquals("楞嚴經-卷十-經文.txt", document.textFileName)
        assertEquals(20_000, document.text.codePointCount(0, document.text.length))
        assertEquals(document.text, document.completeText.substringAfter("\n\n").substringBeforeLast("\n\n"))
        assertEquals(421, document.preview().codePointCount(0, document.preview().length))
        assertTrue(document.preview().endsWith("…"))

        composeRule.setContent {
            ClassicsTheme(darkTheme = false) {
                ShareScreenContent(
                    document = document,
                    strings = AppStrings("zh-Hant"),
                    generationState = ShareImageGenerationState.Idle,
                    statusMessage = null,
                    onBack = {},
                    onShareImage = { imageActionCount += 1 },
                    onShareText = {},
                    onSaveText = {},
                    onCopyText = {},
                    onCancelImageExport = {},
                )
            }
        }

        composeRule.onNodeWithTag("share.screen").assertIsDisplayed()
        composeRule.onNodeWithTag("share.preview.body")
            .assertIsDisplayed()
            .assertTextContains("…", substring = true)
        composeRule.onNodeWithText("全文 20000 字").fetchSemanticsNode()
        composeRule.runOnIdle { assertEquals(0, imageActionCount) }

        composeRule.onNodeWithTag("share.action.image").performClick()
        composeRule.runOnIdle { assertEquals(1, imageActionCount) }
    }

    @Test
    fun allActionsRemainVisibleAtDoubleSystemFontScale() {
        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(
                    density = deviceDensity.density,
                    fontScale = 2f,
                ),
            ) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(320.dp)
                            .height(700.dp),
                    ) {
                        ShareScreenContent(
                            document = longDocument(),
                            strings = AppStrings("zh-Hant"),
                            generationState = ShareImageGenerationState.Idle,
                            statusMessage = null,
                            onBack = {},
                            onShareImage = {},
                            onShareText = {},
                            onSaveText = {},
                            onCopyText = {},
                            onCancelImageExport = {},
                        )
                    }
                }
            }
        }

        listOf("image", "text", "save", "copy").forEach { action ->
            composeRule.onNodeWithTag("share.action.$action").assertIsDisplayed()
        }
    }

    private fun longDocument(): ShareDocument = ShareDocument(
        locale = "zh-Hant",
        productTitle = "楞嚴經",
        volumeTitle = "楞嚴經 卷十",
        text = "如是我聞".repeat(5_000),
        fontSizeLevel = 2,
    )
}
