package org.fuxuan.lengyan

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LengyanShellTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun launchesWithLengyanProductIdentity() {
        composeRule.onNodeWithText("楞严经").assertIsDisplayed()
        composeRule.onNodeWithText("大佛顶首楞严经").assertIsDisplayed()
    }
}
