package org.fuxuan.classics.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.fuxuan.classics.core.persistence.ThemePreference

class DailyVerseWidgetPolicyTest {
    @Test
    fun semanticClippingPrefersACompleteSentence() {
        val text = "第一句完整。第二句仍在继续，后面还有很多文字。"

        assertEquals(
            "第一句完整。",
            DailyVerseWidgetTextPolicy.displayText(text, limit = 14),
        )
    }

    @Test
    fun semanticClippingUsesOneEllipsisAfterAPhraseBoundary() {
        val text = "前段文字较长，后段文字仍在继续而且超过限制"
        val clipped = DailyVerseWidgetTextPolicy.displayText(text, limit = 12)

        assertEquals("前段文字较长…", clipped)
        assertFalse(clipped.endsWith("，…"))
    }

    @Test
    fun clippingDoesNotSplitSupplementaryUnicodeCharacters() {
        val text = "甲𠀀乙丙丁戊己庚辛壬癸"
        val clipped = DailyVerseWidgetTextPolicy.displayText(text, limit = 6)

        assertEquals("甲𠀀乙丙丁…", clipped)
        assertTrue(clipped.toByteArray(Charsets.UTF_8).toString(Charsets.UTF_8) == clipped)
    }

    @Test
    fun responsiveLayoutKeepsReadableBodySizes() {
        assertEquals(DailyVerseWidgetLayout.COMPACT, DailyVerseWidgetLayout.forSize(180f, 110f))
        assertEquals(DailyVerseWidgetLayout.MEDIUM, DailyVerseWidgetLayout.forSize(320f, 160f))
        assertEquals(DailyVerseWidgetLayout.TALL, DailyVerseWidgetLayout.forSize(196f, 240f))
        assertEquals(DailyVerseWidgetLayout.EXPANDED, DailyVerseWidgetLayout.forSize(320f, 320f))
        assertTrue(DailyVerseWidgetLayout.entries.all { it.bodyFontSize >= 17 })
    }

    @Test
    fun accessibilityDescriptionDoesNotDuplicateExistingPunctuation() {
        val content = DailyVerseWidgetContent(
            productTitle = "楞嚴經",
            header = "今日讀經",
            text = "根緒。",
            source = "楞嚴經 卷九",
            paragraphID = "p-lengyan-test",
            theme = ThemePreference.SYSTEM,
            tapHint = "點按閱讀",
        )

        assertEquals(
            "楞嚴經。根緒。楞嚴經 卷九。點按閱讀",
            content.accessibilityDescription(),
        )
        assertFalse(content.accessibilityDescription().contains("。。"))
    }
}
