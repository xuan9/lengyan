package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BottomRegionLayoutTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun miniPlayerTouchesNavigationAndTabsDoNotOverlapAtDoubleFontScale() {
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
                        BottomRegion(
                            selected = TopLevelDestination.FAVORITES,
                            strings = AppStrings("zh-Hant"),
                            onSelect = {},
                            miniPlayer = {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(44.dp)
                                        .testTag("bottom.mini-player"),
                                )
                            },
                        )
                    }
                }
            }
        }

        val miniPlayer = composeRule.onNodeWithTag("bottom.mini-player")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val navigation = composeRule.onNodeWithTag("bottom.navigation")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val reading = composeRule.onNodeWithTag("bottom.reading")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val favorites = composeRule.onNodeWithTag("bottom.favorites")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot
        val settings = composeRule.onNodeWithTag("bottom.settings")
            .assertIsDisplayed()
            .fetchSemanticsNode()
            .boundsInRoot

        assertEquals(miniPlayer.bottom, navigation.top, 0.5f)
        assertTrue("reading and favorites tabs overlap", reading.right <= favorites.left)
        assertTrue("favorites and settings tabs overlap", favorites.right <= settings.left)
    }
}
