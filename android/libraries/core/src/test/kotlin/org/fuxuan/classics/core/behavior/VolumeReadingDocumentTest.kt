package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VolumeReadingDocumentTest {
    @Test
    fun exposesVolumesByExplicitOrderInsteadOfJsonArrayOrder() {
        assertEquals(
            listOf(VOLUME_ID, SECOND_VOLUME_ID),
            content().volumesInReadingOrder().map { it.volumeID },
        )
    }

    @Test
    fun mapsComposeUtf16OffsetsToStableUnicodeCharacterAnchors() {
        val document = VolumeReadingDocument.from(content(), VOLUME_ID)

        assertEquals("甲𠀀乙\n\n第二段", document.text)
        assertEquals(ParagraphTextAnchor("test.p000001", 0), document.anchorAtUtf16Offset(0))
        assertEquals(ParagraphTextAnchor("test.p000001", 1), document.anchorAtUtf16Offset(1))
        assertEquals(ParagraphTextAnchor("test.p000001", 1), document.anchorAtUtf16Offset(2))
        assertEquals(ParagraphTextAnchor("test.p000001", 2), document.anchorAtUtf16Offset(3))
        assertEquals(ParagraphTextAnchor("test.p000001", 3), document.anchorAtUtf16Offset(5))
        assertEquals(ParagraphTextAnchor("test.p000002", 0), document.anchorAtUtf16Offset(6))
        assertEquals(3, document.utf16OffsetFor(ParagraphTextAnchor("test.p000001", 2)))
        assertEquals(6, document.utf16OffsetFor(ParagraphTextAnchor("test.p000002", 0)))
        assertNull(document.utf16OffsetFor(ParagraphTextAnchor("test.p999999", 0)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsUnknownVolume() {
        VolumeReadingDocument.from(content(), "test.v999999")
    }

    private fun content(): ScriptureContent {
        val source = SourceReference("test.source.primary", "fixture#1")
        return ScriptureContent(
            schemaVersion = 1,
            productID = "test",
            bookID = "test-book",
            editionID = "test-edition-v1",
            contentVersion = "2026.07.26",
            contentStatus = "legacy-migration",
            locale = "zh-Hant",
            normalization = "utf8-nfc-lf-v1",
            contentHash = "0".repeat(64),
            volumes = listOf(
                ScriptureVolume(SECOND_VOLUME_ID, 2, 1, "測試卷二", listOf(source)),
                ScriptureVolume(VOLUME_ID, 1, 0, "測試卷一", listOf(source)),
            ),
            sections = listOf(
                ScriptureSection("test.s000001", null, 0, "測試", null, listOf(source), emptyList()),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = "test.p000002",
                    sectionID = "test.s000001",
                    volumeID = VOLUME_ID,
                    order = 1,
                    textRole = "sutra",
                    text = "第二段",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
                ScriptureParagraph(
                    paragraphID = "test.p000001",
                    sectionID = "test.s000001",
                    volumeID = VOLUME_ID,
                    order = 0,
                    textRole = "sutra",
                    text = "甲𠀀乙",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
            ),
        )
    }

    private companion object {
        const val VOLUME_ID = "test.v000001"
        const val SECOND_VOLUME_ID = "test.v000002"
    }
}
