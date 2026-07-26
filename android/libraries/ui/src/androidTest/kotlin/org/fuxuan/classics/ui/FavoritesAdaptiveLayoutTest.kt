package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.fuxuan.classics.core.behavior.FavoriteNavigationTarget
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.fuxuan.classics.core.persistence.Favorite
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FavoritesAdaptiveLayoutTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun wideLayoutKeepsSelectedDetailAfterRemovingFavoriteAtDoubleFontScale() {
        val content = content()
        val firstFavorite = favorite(PARAGRAPH_ID, createdAt = 1)
        val secondFavorite = favorite(SECOND_PARAGRAPH_ID, createdAt = 2)
        val currentFavorites = mutableStateOf(listOf(firstFavorite, secondFavorite))

        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(1f, 2f)) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(1_000.dp)
                            .height(700.dp),
                    ) {
                        FavoritesScreen(
                            content = content,
                            favorites = currentFavorites.value,
                            strings = AppStrings("zh-Hant"),
                            onOpenFavorite = {},
                            onRemoveFavorite = { removed ->
                                currentFavorites.value = currentFavorites.value - removed
                            },
                            detailContent = { target -> DetailProbe(target) },
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithTag("favorites.split").assertIsDisplayed()
        composeRule.onNodeWithTag("favorites.list-pane").assertIsDisplayed()
        composeRule.onNodeWithTag("favorites.detail").assertIsDisplayed()
        composeRule.onNodeWithTag("favorite.row.$FIRST_FAVORITE_ID").assert(
            SemanticsMatcher.expectValue(SemanticsProperties.Selected, true),
        )
        composeRule.onNodeWithTag("test.detail.$PARAGRAPH_ID").assertIsDisplayed()

        composeRule.onNodeWithTag("favorite.row.$SECOND_FAVORITE_ID").performClick()
        composeRule.onNodeWithTag("favorite.row.$FIRST_FAVORITE_ID").assert(
            SemanticsMatcher.expectValue(SemanticsProperties.Selected, false),
        )
        composeRule.onNodeWithTag("favorite.row.$SECOND_FAVORITE_ID").assert(
            SemanticsMatcher.expectValue(SemanticsProperties.Selected, true),
        )
        composeRule.onNodeWithTag("test.detail.$SECOND_PARAGRAPH_ID").assertIsDisplayed()

        composeRule.onNodeWithTag("favorite.remove.$SECOND_FAVORITE_ID").performClick()

        composeRule.onNodeWithTag("favorite.row.$SECOND_FAVORITE_ID").assertDoesNotExist()
        composeRule.onNodeWithTag("favorite.row.$FIRST_FAVORITE_ID").assertIsDisplayed()
        composeRule.onNodeWithTag("favorites.empty").assertDoesNotExist()
        composeRule.onNodeWithTag("favorites.detail").assertIsDisplayed()
        composeRule.onNodeWithTag("test.detail.$SECOND_PARAGRAPH_ID").assertIsDisplayed()
    }

    @Test
    fun compactLayoutKeepsTheExistingSinglePaneNavigation() {
        val content = content()
        var openedTarget: FavoriteNavigationTarget? = null

        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(1f, 1f)) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(480.dp)
                            .height(700.dp),
                    ) {
                        FavoritesScreen(
                            content = content,
                            favorites = listOf(favorite(PARAGRAPH_ID, createdAt = 1)),
                            strings = AppStrings("zh-Hant"),
                            onOpenFavorite = { openedTarget = it },
                            onRemoveFavorite = {},
                            detailContent = { target -> DetailProbe(target) },
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithTag("favorites.split").assertDoesNotExist()
        composeRule.onNodeWithTag("favorites.detail").assertDoesNotExist()
        composeRule.onNodeWithTag("favorite.row.$FIRST_FAVORITE_ID").performClick()
        composeRule.runOnIdle {
            assertEquals(PARAGRAPH_ID, openedTarget?.anchor?.paragraphID)
        }
    }

    @androidx.compose.runtime.Composable
    private fun DetailProbe(target: FavoriteNavigationTarget) {
        androidx.compose.material3.Text(
            text = target.anchor.paragraphID,
            modifier = Modifier.testTag("test.detail.${target.anchor.paragraphID}"),
        )
    }

    private fun favorite(
        paragraphID: String,
        createdAt: Long,
    ): Favorite = Favorite.paragraph(
        productID = PRODUCT_ID,
        editionID = EDITION_ID,
        sectionID = SECTION_ID,
        paragraphID = paragraphID,
        createdAtEpochMilliseconds = createdAt,
    )

    private fun content(): ScriptureContent {
        val source = SourceReference("test.source.primary", "fixture#1")
        return ScriptureContent(
            schemaVersion = 1,
            productID = PRODUCT_ID,
            bookID = "test-book",
            editionID = EDITION_ID,
            contentVersion = "2026.07.26",
            contentStatus = "legacy-migration",
            locale = "zh-Hant",
            normalization = "utf8-nfc-lf-v1",
            contentHash = "0".repeat(64),
            volumes = listOf(
                ScriptureVolume(VOLUME_ID, 1, 0, "測試卷一", listOf(source)),
            ),
            sections = listOf(
                ScriptureSection(
                    sectionID = SECTION_ID,
                    parentSectionID = null,
                    order = 0,
                    title = "測試章節",
                    subtitle = null,
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                ),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = PARAGRAPH_ID,
                    sectionID = SECTION_ID,
                    volumeID = VOLUME_ID,
                    order = 0,
                    textRole = "sutra",
                    text = "如是我聞，一時佛在測試處。",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
                ScriptureParagraph(
                    paragraphID = SECOND_PARAGRAPH_ID,
                    sectionID = SECTION_ID,
                    volumeID = VOLUME_ID,
                    order = 1,
                    textRole = "sutra",
                    text = "與大比丘眾，千二百五十人俱。",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
            ),
        )
    }

    private companion object {
        const val PRODUCT_ID = "test"
        const val EDITION_ID = "test-edition-v1"
        const val VOLUME_ID = "test.v000001"
        const val SECTION_ID = "test.s000001"
        const val PARAGRAPH_ID = "test.p000001"
        const val SECOND_PARAGRAPH_ID = "test.p000002"
        const val FIRST_FAVORITE_ID = "paragraph:$PARAGRAPH_ID"
        const val SECOND_FAVORITE_ID = "paragraph:$SECOND_PARAGRAPH_ID"
    }
}
