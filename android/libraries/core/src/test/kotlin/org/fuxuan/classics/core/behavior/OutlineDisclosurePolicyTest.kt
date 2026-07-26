package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.junit.Assert.assertEquals
import org.junit.Test

class OutlineDisclosurePolicyTest {
    @Test
    fun showsOnlyExpandedBranchesInCanonicalOrder() {
        val rows = OutlineDisclosurePolicy.visibleRows(
            content(),
            setOf(ROOT_ID, SECOND_PARENT_ID),
        )

        assertEquals(
            listOf(ROOT_ID, FIRST_LEAF_ID, SECOND_PARENT_ID, SECOND_LEAF_ID),
            rows.map { it.section.sectionID },
        )
        assertEquals(listOf(0, 1, 1, 2), rows.map(OutlineDisclosureRow::depth))
        assertEquals(listOf(true, false, true, false), rows.map(OutlineDisclosureRow::isExpanded))
    }

    @Test
    fun removesUnknownAndLeafIDsFromPersistedExpansion() {
        assertEquals(
            setOf(ROOT_ID, SECOND_PARENT_ID),
            OutlineDisclosurePolicy.sanitizeExpandedSectionIDs(
                content(),
                setOf(ROOT_ID, FIRST_LEAF_ID, SECOND_PARENT_ID, "test.s999999"),
            ),
        )
    }

    @Test
    fun expandingEveryParentExposesEverySectionExactlyOnce() {
        val content = content()
        val rows = OutlineDisclosurePolicy.visibleRows(
            content,
            OutlineDisclosurePolicy.expandableSectionIDs(content),
        )

        assertEquals(content.sections.size, rows.size)
        assertEquals(content.sections.map { it.sectionID }.toSet(), rows.map { it.section.sectionID }.toSet())
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
                ScriptureVolume(VOLUME_ID, 1, 0, "測試卷一", listOf(source)),
            ),
            sections = listOf(
                section(ROOT_ID, parentID = null, order = 0, source = source),
                section(FIRST_LEAF_ID, parentID = ROOT_ID, order = 0, source = source),
                section(SECOND_PARENT_ID, parentID = ROOT_ID, order = 1, source = source),
                section(SECOND_LEAF_ID, parentID = SECOND_PARENT_ID, order = 0, source = source),
            ),
            paragraphs = listOf(
                paragraph("test.p000001", FIRST_LEAF_ID, order = 0, source = source),
                paragraph("test.p000002", SECOND_LEAF_ID, order = 0, source = source),
            ),
        )
    }

    private fun section(
        id: String,
        parentID: String?,
        order: Int,
        source: SourceReference,
    ) = ScriptureSection(
        sectionID = id,
        parentSectionID = parentID,
        order = order,
        title = id,
        subtitle = null,
        sourceReferences = listOf(source),
        legacyIDs = emptyList(),
    )

    private fun paragraph(
        id: String,
        sectionID: String,
        order: Int,
        source: SourceReference,
    ) = ScriptureParagraph(
        paragraphID = id,
        sectionID = sectionID,
        volumeID = VOLUME_ID,
        order = order,
        textRole = "sutra",
        text = id,
        sourceReferences = listOf(source),
        legacyIDs = emptyList(),
        legacyVolumeHint = 1,
    )

    private companion object {
        const val VOLUME_ID = "test.v000001"
        const val ROOT_ID = "test.s000001"
        const val FIRST_LEAF_ID = "test.s000002"
        const val SECOND_PARENT_ID = "test.s000003"
        const val SECOND_LEAF_ID = "test.s000004"
    }
}
