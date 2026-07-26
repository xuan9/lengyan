package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductFeatures
import org.fuxuan.classics.core.content.ProductManifest
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
class HomeLargeTextTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun secondaryActionsRemainVisibleAndSeparatedAtDoubleFontScale() {
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
                        HomeScreen(
                            loaded = fixtureContent(),
                            strings = AppStrings("zh-Hant"),
                            resumeRoute = null,
                            onRead = {},
                            onBrowseVolumes = {},
                            onSearch = {},
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithText("選擇卷目").assertIsDisplayed()
        composeRule.onNodeWithText("搜索").assertIsDisplayed()
        val volumeBounds = composeRule.onNodeWithTag("home.volumes")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val searchBounds = composeRule.onNodeWithTag("home.search")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot

        assertEquals(volumeBounds.top, searchBounds.top, 0.5f)
        assertEquals(volumeBounds.bottom, searchBounds.bottom, 0.5f)
        assertTrue("home actions overlap", volumeBounds.right <= searchBounds.left)
    }

    private fun fixtureContent(): LoadedContent {
        val source = SourceReference("test-source", "test:1")
        val product = ProductManifest(
            schemaVersion = 1,
            productID = "test",
            lifecycle = "development",
            titles = mapOf("zh-Hant" to "楞嚴經"),
            defaultLocale = "zh-Hant",
            supportedLocales = listOf("zh-Hant"),
            navigationMode = "hierarchy-and-volumes",
            bookManifestPath = "Book/book.json",
            sourceManifestPath = "Sources/source.json",
            audioManifestPath = null,
            androidAudioDeliveryPath = null,
            features = ProductFeatures(
                audio = false,
                dailyVerse = false,
                guidedReading = false,
                personIndex = false,
            ),
        )
        val book = BookManifest(
            schemaVersion = 1,
            productID = "test",
            bookID = "testbook",
            editionID = "test-edition",
            contractState = "legacy-migration",
            titles = mapOf("zh-Hant" to "大佛頂如來密因修證了義諸菩薩萬行首楞嚴經"),
            canonicalLocale = "zh-Hant",
            supportedLocales = listOf("zh-Hant"),
            contentVersion = "test-1",
            stableIDScheme = "fuxuan-classics-v1",
            normalization = "utf8-nfc-lf-v1",
            sourceManifestPath = "Sources/source.json",
            contentPackagePaths = mapOf("zh-Hant" to "Content/content.json"),
            legacyMapPath = null,
        )
        val content = ScriptureContent(
            schemaVersion = 1,
            productID = "test",
            bookID = "testbook",
            editionID = "test-edition",
            contentVersion = "test-1",
            contentStatus = "legacy-migration",
            locale = "zh-Hant",
            normalization = "utf8-nfc-lf-v1",
            contentHash = "0".repeat(64),
            volumes = listOf(
                ScriptureVolume(
                    volumeID = "testbook.v000001",
                    number = 1,
                    order = 0,
                    title = "楞嚴經 卷一",
                    sourceReferences = listOf(source),
                ),
            ),
            sections = listOf(
                ScriptureSection(
                    sectionID = "testbook.s000001",
                    parentSectionID = null,
                    order = 0,
                    title = "序分",
                    subtitle = null,
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                ),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = "testbook.p000001",
                    sectionID = "testbook.s000001",
                    volumeID = "testbook.v000001",
                    order = 0,
                    textRole = "scripture",
                    text = "如是我聞。",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = null,
                ),
            ),
        )
        return LoadedContent(product = product, book = book, content = content)
    }
}
