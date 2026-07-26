package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ContentBrowserLargeTextTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun longOutlineRemainsReadableAndActionableAtDoubleFontScale() {
        var openedParagraphID: String? = null
        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(
                    density = deviceDensity.density,
                    fontScale = 2f,
                ),
            ) {
                ClassicsTheme(darkTheme = false) {
                    var expandedSectionIDs by remember { mutableStateOf(emptySet<String>()) }
                    Box(
                        modifier = Modifier
                            .width(320.dp)
                            .height(700.dp),
                    ) {
                        ContentBrowserScreen(
                            content = fixtureContent(),
                            strings = AppStrings("zh-Hant"),
                            resumeRoute = null,
                            expandedSectionIDs = expandedSectionIDs,
                            onExpandedSectionIDsChanged = { expandedSectionIDs = it },
                            onBack = {},
                            onOpenVolume = {},
                            onOpenParagraph = { openedParagraphID = it.paragraphID },
                        )
                    }
                }
            }
        }

        val tabsBounds = composeRule.onNodeWithTag("directory.tabs")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val root = composeRule.onNodeWithTag("outline.row.test.s000001")
            .assertIsDisplayed()
        val rootBounds = root.fetchSemanticsNode().boundsInRoot
        assertTrue("outline overlaps its tabs", rootBounds.top >= tabsBounds.bottom)
        assertEquals(
            "已收合",
            root.fetchSemanticsNode().config[SemanticsProperties.StateDescription],
        )

        root.performClick()
        val leaf = composeRule.onNodeWithTag("outline.row.test.s000002")
            .assertIsDisplayed()
        leaf.performClick()
        composeRule.runOnIdle { assertEquals("test.p000001", openedParagraphID) }
    }

    private fun fixtureContent(): ScriptureContent {
        val source = SourceReference("test.source.primary", "fixture#1")
        return ScriptureContent(
            schemaVersion = 1,
            productID = "test",
            bookID = "test",
            editionID = "test-edition-v1",
            contentVersion = "2026.07.26",
            contentStatus = "legacy-migration",
            locale = "zh-Hant",
            normalization = "utf8-nfc-lf-v1",
            contentHash = "0".repeat(64),
            volumes = listOf(
                ScriptureVolume(
                    volumeID = "test.v000001",
                    number = 1,
                    order = 0,
                    title = "測試卷一",
                    sourceReferences = listOf(source),
                ),
            ),
            sections = listOf(
                ScriptureSection(
                    sectionID = "test.s000001",
                    parentSectionID = null,
                    order = 0,
                    title = "大佛頂如來密因修證了義諸菩薩萬行首楞嚴經",
                    subtitle = null,
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                ),
                ScriptureSection(
                    sectionID = "test.s000002",
                    parentSectionID = "test.s000001",
                    order = 0,
                    title = "序分",
                    subtitle = null,
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                ),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = "test.p000001",
                    sectionID = "test.s000002",
                    volumeID = "test.v000001",
                    order = 0,
                    textRole = "sutra",
                    text = "如是我聞",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
            ),
        )
    }
}
