package org.fuxuan.lengyan

import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.net.Uri
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.SearchDocumentKind
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ThemePreference
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

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
        composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).assertIsDisplayed()
    }

    @Test
    fun launchesWithLengyanProductIdentity() {
        composeRule.onNodeWithText("楞嚴經").assertIsDisplayed()
        composeRule.onNodeWithText("大佛頂如來密因修證了義諸菩薩萬行首楞嚴經").assertIsDisplayed()
    }

    @Test
    fun opensTheFirstRealVolumeFromTheHomeScreen() {
        composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("directory.tab.volumes", useUnmergedTree = true)
            .performClick()
        composeRule.onNodeWithText("楞嚴經 卷一").performClick()

        composeRule.onNodeWithText(
            "如是我聞，一時佛在室羅筏城，祇桓精舍。",
            substring = true,
        ).assertIsDisplayed()
    }

    @Test
    fun outlineExpansionPersistsAndInvalidIDsAreRemoved() {
        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val root = content.rootSections().first()
        val firstChild = content.childrenOf(root.sectionID).first()
        runBlocking {
            container.userPreferencesRepository.setExpandedSectionIDs(
                setOf("lengyan.s999999"),
            )
        }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.userPreferencesRepository.preferences.first().expandedSectionIDs.isEmpty()
            }
        }

        composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("outline.row.${root.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()
        assertTrue(
            composeRule.onAllNodesWithTag(
                "outline.row.${firstChild.sectionID}",
                useUnmergedTree = true,
            ).fetchSemanticsNodes().isEmpty(),
        )

        composeRule.onNodeWithTag("outline.row.${root.sectionID}", useUnmergedTree = true)
            .performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                root.sectionID in container.userPreferencesRepository.preferences.first()
                    .expandedSectionIDs
            }
        }
        composeRule.onNodeWithTag("outline.row.${firstChild.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()

        composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("bottom.reading", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("outline.row.${firstChild.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()

        composeRule.activityRule.scenario.recreate()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            outlineIsDisplayed() || homeIsDisplayed()
        }
        if (homeIsDisplayed()) {
            composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).performClick()
        }
        composeRule.onNodeWithTag("outline.row.${firstChild.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()
    }

    @Test
    fun deepOutlineLeafOpensItsExactFirstParagraphAndReturnsToTheBranch() {
        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val leaf = content.leafSections().last()
        val expectedParagraph = requireNotNull(content.firstParagraphInSubtree(leaf.sectionID))
        val expandedAncestors = content.sectionPath(leaf.sectionID)
            .dropLast(1)
            .mapTo(linkedSetOf()) { it.sectionID }
        runBlocking {
            container.userPreferencesRepository.setExpandedSectionIDs(expandedAncestors)
        }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.userPreferencesRepository.preferences.first().expandedSectionIDs ==
                    expandedAncestors
            }
        }

        composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("outline.list", useUnmergedTree = true)
            .performScrollToNode(hasTestTag("outline.row.${leaf.sectionID}"))
        composeRule.onNodeWithTag("outline.row.${leaf.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()
            .performClick()

        composeRule.waitUntil(timeoutMillis = 10_000) {
            currentProgress()?.paragraphID == expectedParagraph.paragraphID
        }
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) { outlineIsDisplayed() }
        composeRule.onNodeWithTag("outline.list", useUnmergedTree = true)
            .performScrollToNode(hasTestTag("outline.row.${leaf.sectionID}"))
        composeRule.onNodeWithTag("outline.row.${leaf.sectionID}", useUnmergedTree = true)
            .assertIsDisplayed()
        assertEquals(
            expandedAncestors,
            runBlocking {
                container.userPreferencesRepository.preferences.first().expandedSectionIDs
            },
        )
    }

    @Test
    fun acceptedVerseIntentOpensTheResolvedParagraphInTheExistingActivity() {
        val container = (composeRule.activity.application as LengyanApplication).container
        val legacyPath = "/A2/B1/C1"
        val resolution = runBlocking {
            container.bookRepository.resolveLegacyLocation(
                legacyPath = legacyPath,
                usage = LegacyLocationUsage.RESUME,
            )
        } as LegacyLocationResolution.Mapped
        val expectedParagraphID = requireNotNull(resolution.paragraphID)
        runBlocking { container.userPreferencesRepository.saveReadingProgress(null) }

        val deepLink = Uri.Builder()
            .scheme("lengyan")
            .authority("verse")
            .appendQueryParameter("path", legacyPath)
            .build()
        composeRule.activity.startActivity(
            Intent(Intent.ACTION_VIEW, deepLink)
                .setPackage(composeRule.activity.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )

        composeRule.waitUntil(timeoutMillis = 10_000) {
            currentProgress()?.paragraphID == expectedParagraphID
        }
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
        assertEquals(
            expectedParagraphID,
            currentProgress()?.paragraphID,
        )
    }

    @Test
    fun favoritesCurrentParagraphAndReturnsToItFromTheFavoritesTab() {
        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val expectedParagraph = content.paragraphsInReadingOrder().first()
        runBlocking {
            container.favoriteRepository.replace(content.editionID, emptyList())
            container.userPreferencesRepository.saveReadingProgress(null)
        }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                composeRule.onNodeWithText("開始閱讀", useUnmergedTree = true)
                    .assertIsDisplayed()
            }.isSuccess
        }

        composeRule.onNodeWithText("開始閱讀", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
        composeRule.onNodeWithTag("reader.favorite", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.favoriteRepository.favorites(content.editionID).first().singleOrNull()
                    ?.paragraphID == expectedParagraph.paragraphID
            }
        }

        composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true).performClick()
        composeRule.onNodeWithText(
            expectedParagraph.text,
            substring = true,
            useUnmergedTree = true,
        ).assertIsDisplayed().performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            currentProgress()?.paragraphID == expectedParagraph.paragraphID
        }
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }

        composeRule.onNodeWithTag("reader.favorite", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.favoriteRepository.favorites(content.editionID).first().isEmpty()
            }
        }
        composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true).performClick()
        composeRule.onNodeWithTag("favorites.empty", useUnmergedTree = true).assertIsDisplayed()

        runBlocking {
            container.favoriteRepository.add(
                Favorite.section(
                    productID = content.productID,
                    editionID = content.editionID,
                    sectionID = expectedParagraph.sectionID,
                    anchorParagraphID = expectedParagraph.paragraphID,
                    createdAtEpochMilliseconds = System.currentTimeMillis(),
                ),
            )
        }
        composeRule.onNodeWithTag("bottom.reading", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                composeRule.onNodeWithContentDescription(
                    "取消收藏",
                    useUnmergedTree = true,
                ).assertIsDisplayed()
            }.isSuccess
        }
        composeRule.onNodeWithTag("reader.favorite", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runBlocking {
                container.favoriteRepository.favorites(content.editionID).first().isEmpty()
            }
        }
    }

    @Test
    fun sharePageOpensBeforeAnyImageFileIsGenerated() {
        val shareCache = File(
            composeRule.activity.cacheDir,
            "classics-shares",
        )
        shareCache.deleteRecursively()
        val readingAction = hasText("開始閱讀") or hasText("繼續閱讀")

        composeRule.onNode(readingAction, useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
        composeRule.onNodeWithTag("reader.share", useUnmergedTree = true)
            .assertIsDisplayed()
            .performClick()

        composeRule.onNodeWithTag("share.screen", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithTag("share.preview", useUnmergedTree = true)
            .assertIsDisplayed()
        assertTrue(shareCache.listFiles().isNullOrEmpty())

        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
    }

    @Test
    fun settingsApplyImmediatelyAndDoNotExposeUnsupportedWidgetStyles() {
        val container = (composeRule.activity.application as LengyanApplication).container
        runBlocking {
            container.userPreferencesRepository.setTheme(ThemePreference.SYSTEM)
            container.userPreferencesRepository.setLocale("zh-Hant")
            container.userPreferencesRepository.setFontSizeLevel(2)
        }

        try {
            composeRule.onNodeWithTag("bottom.settings", useUnmergedTree = true).performClick()
            composeRule.onNodeWithTag("settings.screen", useUnmergedTree = true)
                .assertIsDisplayed()
            composeRule.onNode(
                hasText("設定") and
                    SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading),
                useUnmergedTree = true,
            ).assertIsDisplayed()
            composeRule.onNodeWithText("外觀", useUnmergedTree = true).assert(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading),
            )
            assertTrue(
                composeRule.onAllNodesWithText("經文卡片", useUnmergedTree = true)
                    .fetchSemanticsNodes().isEmpty(),
            )

            composeRule.onNodeWithTag("settings.theme.dark", useUnmergedTree = true).performClick()
            composeRule.waitUntil(timeoutMillis = 10_000) {
                runBlocking {
                    container.userPreferencesRepository.preferences.first().theme ==
                        ThemePreference.DARK
                }
            }

            composeRule.onNodeWithTag("settings.locale.zh-Hans", useUnmergedTree = true)
                .performClick()
            composeRule.waitUntil(timeoutMillis = 10_000) {
                runBlocking {
                    container.userPreferencesRepository.preferences.first().locale == "zh-Hans"
                }
            }
            composeRule.onNodeWithTag("settings.screen", useUnmergedTree = true)
                .assertIsDisplayed()
            assertTrue(
                composeRule.onAllNodesWithText("经文卡片", useUnmergedTree = true)
                    .fetchSemanticsNodes().isEmpty(),
            )
            composeRule.onNodeWithTag("settings.font-size", useUnmergedTree = true)
                .performScrollTo()
                .assertIsDisplayed()
            composeRule.onNodeWithTag("settings.font-size.slider", useUnmergedTree = true)
                .assert(
                    SemanticsMatcher.expectValue(
                        SemanticsProperties.StateDescription,
                        "第 3 级，共 5 级",
                    ),
                )
        } finally {
            runBlocking {
                container.userPreferencesRepository.setTheme(ThemePreference.SYSTEM)
                container.userPreferencesRepository.setLocale("zh-Hant")
                container.userPreferencesRepository.setFontSizeLevel(2)
            }
        }
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
        composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
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
            composeRule.waitUntil(timeoutMillis = 10_000) { readerIsDisplayed() }
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

    @Test
    fun searchInTheResumeVolumeOpensAndHighlightsTheExactParagraph() {
        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val paragraphResult = runBlocking {
            container.bookRepository.searchIndex()
                .search(query = "转物", displayLocale = "zh-Hant")
                .first { it.kind == SearchDocumentKind.PARAGRAPH }
        }
        val target = requireNotNull(
            ScriptureSearchNavigationPolicy.target(content, paragraphResult),
        )
        val volumeStart = content.paragraphsInReadingOrder()
            .first { it.volumeID == target.volumeID }
        assertNotEquals(volumeStart.paragraphID, target.anchor.paragraphID)
        runBlocking {
            container.userPreferencesRepository.saveReadingProgress(
                ReadingProgress(
                    productID = content.productID,
                    editionID = content.editionID,
                    paragraphID = volumeStart.paragraphID,
                    characterOffset = 0,
                    mode = ReadingMode.CHAPTER,
                    updatedAtEpochMilliseconds = System.currentTimeMillis() - 10_000,
                ),
            )
        }

        composeRule.onNodeWithText("搜索", useUnmergedTree = true).performClick()
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                composeRule.onNode(hasSetTextAction(), useUnmergedTree = true)
                    .assertIsDisplayed()
            }.isSuccess
        }
        composeRule.onNode(hasSetTextAction(), useUnmergedTree = true)
            .performTextInput("转物")
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                composeRule.onNodeWithText(
                    "若能轉物，則同如來",
                    substring = true,
                    useUnmergedTree = true,
                ).assertIsDisplayed()
            }.isSuccess
        }
        composeRule.onNodeWithTag("search.result-count", useUnmergedTree = true).assert(
            SemanticsMatcher.expectValue(
                SemanticsProperties.LiveRegion,
                LiveRegionMode.Polite,
            ),
        )
        composeRule.onNodeWithText(
            "若能轉物，則同如來",
            substring = true,
            useUnmergedTree = true,
        ).performClick()

        composeRule.waitUntil(timeoutMillis = 10_000) {
            currentProgress()?.paragraphID == target.anchor.paragraphID
        }
        composeRule.waitUntil(timeoutMillis = 10_000) {
            runCatching {
                val scrollRange = composeRule.onNodeWithTag("reader.scroll")
                    .fetchSemanticsNode()
                    .config[SemanticsProperties.VerticalScrollAxisRange]
                scrollRange.value() > 0f
            }.getOrDefault(false)
        }
        val readerText = composeRule.onNodeWithText(
            "若能轉物，則同如來",
            substring = true,
            useUnmergedTree = true,
        ).fetchSemanticsNode().config[SemanticsProperties.Text].single()
        assertTrue(
            "search match was not highlighted in the reader",
            readerText.spanStyles.any { range -> range.item.background != Color.Unspecified },
        )
    }

    private fun currentProgress(): ReadingProgress? {
        val container = (composeRule.activity.application as LengyanApplication).container
        return runBlocking { container.userPreferencesRepository.preferences.first().readingProgress }
    }

    private fun homeIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithText("經文目錄", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun outlineIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithTag("outline.list", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun backIsDisplayed(): Boolean = runCatching {
        composeRule.onNodeWithContentDescription("返回", useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun readerIsDisplayed(): Boolean = runCatching {
        composeRule.onNode(hasScrollAction(), useUnmergedTree = true).assertIsDisplayed()
    }.isSuccess

    private fun org.fuxuan.classics.core.content.ScriptureContent.paragraphIndex(
        paragraphID: String?,
    ): Int = paragraphsInReadingOrder().indexOfFirst { it.paragraphID == paragraphID }
}
