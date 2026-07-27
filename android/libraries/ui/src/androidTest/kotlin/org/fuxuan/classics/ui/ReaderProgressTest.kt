package org.fuxuan.classics.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class ReaderProgressTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun programmaticRestoreKeepsExactAnchorUntilTheUserScrolls() {
        val paragraphID = "fixture.p000001"
        val document = VolumeReadingDocument.from(fixtureContent(paragraphID), VOLUME_ID)
        val initialAnchor = ParagraphTextAnchor(paragraphID, characterOffset = 7)
        val savedAnchor = AtomicReference<ParagraphTextAnchor?>()

        composeRule.setContent {
            ClassicsTheme(darkTheme = false) {
                ReaderScreen(
                    document = document,
                    fontSizeLevel = 2,
                    strings = AppStrings("zh-Hant"),
                    initialAnchor = initialAnchor,
                    showBackButton = false,
                    onBack = {},
                    onSaveProgress = savedAnchor::set,
                )
            }
        }

        composeRule.onNodeWithTag("reader.scroll", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.waitForIdle()
        Thread.sleep(500)
        composeRule.waitForIdle()
        assertEquals(null, savedAnchor.get())

        composeRule.onNodeWithTag("reader.scroll", useUnmergedTree = true)
            .performTouchInput { swipeUp(durationMillis = 250) }
        composeRule.waitUntil(timeoutMillis = 5_000) { savedAnchor.get() != null }
        assertNotNull(savedAnchor.get())
    }

    private fun fixtureContent(paragraphID: String): ScriptureContent {
        val source = SourceReference("fixture.source", "fixture")
        return ScriptureContent(
            schemaVersion = 1,
            productID = "fixture",
            bookID = "fixture",
            editionID = "fixture-edition-v1",
            contentVersion = "2026.07.27.1",
            contentStatus = "legacy-migration",
            locale = "zh-Hant",
            normalization = "utf8-nfc-lf-v1",
            contentHash = "0".repeat(64),
            volumes = listOf(
                ScriptureVolume(
                    volumeID = VOLUME_ID,
                    number = 1,
                    order = 0,
                    title = "卷一",
                    sourceReferences = listOf(source),
                ),
            ),
            sections = listOf(
                ScriptureSection(
                    sectionID = "fixture.s000001",
                    parentSectionID = null,
                    order = 0,
                    title = "正文",
                    subtitle = null,
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                ),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = paragraphID,
                    sectionID = "fixture.s000001",
                    volumeID = VOLUME_ID,
                    order = 0,
                    textRole = "sutra",
                    text = "甲乙丙丁戊己庚辛壬癸".repeat(500),
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = null,
                ),
            ),
        )
    }

    private companion object {
        const val VOLUME_ID = "fixture.v000001"
    }
}
