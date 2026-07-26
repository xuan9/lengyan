package org.fuxuan.lengyan

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.persistence.Favorite
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LengyanTabletFavoritesTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun removingSelectedFavoriteKeepsTabletDetailAndReadingRootAvailable() {
        assumeTrue(
            "managed device must provide the split-detail width",
            composeRule.activity.resources.configuration.screenWidthDp >= 720,
        )
        val container = (composeRule.activity.application as LengyanApplication).container
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val paragraph = content.paragraphsInReadingOrder().first()
        val favorite = Favorite.paragraph(
            productID = content.productID,
            editionID = content.editionID,
            sectionID = paragraph.sectionID,
            paragraphID = paragraph.paragraphID,
            createdAtEpochMilliseconds = System.currentTimeMillis(),
        )
        runBlocking {
            container.userPreferencesRepository.saveReadingProgress(null)
            container.favoriteRepository.replace(content.editionID, listOf(favorite))
        }

        try {
            composeRule.waitUntil(timeoutMillis = 10_000) {
                runCatching {
                    composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true)
                        .assertIsDisplayed()
                }.isSuccess
            }
            composeRule.onNodeWithTag("bottom.favorites", useUnmergedTree = true)
                .assertIsDisplayed()
                .performClick()
            composeRule.onNodeWithTag("favorites.split", useUnmergedTree = true)
                .assertIsDisplayed()
            composeRule.onNodeWithTag("favorites.detail", useUnmergedTree = true)
                .assertIsDisplayed()
            composeRule.onNodeWithTag("reader.scroll", useUnmergedTree = true)
                .assertIsDisplayed()

            composeRule.onNodeWithTag("reader.favorite", useUnmergedTree = true)
                .assertIsDisplayed()
                .performClick()
            composeRule.waitUntil(timeoutMillis = 10_000) {
                runBlocking {
                    container.favoriteRepository.favorites(content.editionID).first().isEmpty()
                }
            }

            composeRule.onNodeWithTag("favorites.detail", useUnmergedTree = true)
                .assertIsDisplayed()
            composeRule.onNodeWithTag("reader.scroll", useUnmergedTree = true)
                .assertIsDisplayed()
            composeRule.onNodeWithTag("favorites.empty", useUnmergedTree = true)
                .assertIsDisplayed()

            composeRule.onNodeWithTag("bottom.reading", useUnmergedTree = true)
                .performClick()
            composeRule.onNodeWithText("經文目錄", useUnmergedTree = true)
                .assertIsDisplayed()
        } finally {
            runBlocking {
                container.favoriteRepository.replace(content.editionID, emptyList())
                container.userPreferencesRepository.saveReadingProgress(null)
            }
        }
    }
}
