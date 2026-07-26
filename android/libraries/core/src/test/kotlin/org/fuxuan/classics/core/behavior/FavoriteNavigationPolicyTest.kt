package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.fuxuan.classics.core.persistence.Favorite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FavoriteNavigationPolicyTest {
    @Test
    fun paragraphFavoriteResolvesByStableID() {
        val target = FavoriteNavigationPolicy.target(
            content(),
            Favorite.paragraph(
                productID = PRODUCT_ID,
                editionID = EDITION_ID,
                sectionID = CHILD_SECTION_ID,
                paragraphID = SECOND_PARAGRAPH_ID,
                createdAtEpochMilliseconds = 1,
            ),
        )

        assertEquals(
            FavoriteNavigationTarget(
                volumeID = VOLUME_ID,
                anchor = ParagraphTextAnchor(SECOND_PARAGRAPH_ID, 0),
            ),
            target,
        )
    }

    @Test
    fun sectionFavoriteUsesItsValidPreferredAnchor() {
        val target = FavoriteNavigationPolicy.target(
            content(),
            Favorite.section(
                productID = PRODUCT_ID,
                editionID = EDITION_ID,
                sectionID = ROOT_SECTION_ID,
                anchorParagraphID = SECOND_PARAGRAPH_ID,
                createdAtEpochMilliseconds = 1,
            ),
        )

        assertEquals(SECOND_PARAGRAPH_ID, target?.anchor?.paragraphID)
    }

    @Test
    fun sectionFavoriteFallsBackToFirstReadableDescendant() {
        val target = FavoriteNavigationPolicy.target(
            content(),
            Favorite.section(
                productID = PRODUCT_ID,
                editionID = EDITION_ID,
                sectionID = ROOT_SECTION_ID,
                anchorParagraphID = "test.p999999",
                createdAtEpochMilliseconds = 1,
            ),
        )

        assertEquals(FIRST_PARAGRAPH_ID, target?.anchor?.paragraphID)
    }

    @Test
    fun rejectsForeignAndUnresolvedFavorites() {
        val foreign = Favorite.paragraph(
            productID = "other",
            editionID = EDITION_ID,
            sectionID = CHILD_SECTION_ID,
            paragraphID = FIRST_PARAGRAPH_ID,
            createdAtEpochMilliseconds = 1,
        )
        val unresolved = Favorite.unresolvedLegacy(
            productID = PRODUCT_ID,
            editionID = EDITION_ID,
            legacyPath = "/legacy/path",
            createdAtEpochMilliseconds = 1,
        )

        assertNull(FavoriteNavigationPolicy.target(content(), foreign))
        assertNull(FavoriteNavigationPolicy.target(content(), unresolved))
    }

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
                    ROOT_SECTION_ID,
                    null,
                    0,
                    "根章節",
                    null,
                    listOf(source),
                    emptyList(),
                ),
                ScriptureSection(
                    CHILD_SECTION_ID,
                    ROOT_SECTION_ID,
                    0,
                    "子章節",
                    null,
                    listOf(source),
                    emptyList(),
                ),
            ),
            paragraphs = listOf(
                ScriptureParagraph(
                    paragraphID = FIRST_PARAGRAPH_ID,
                    sectionID = CHILD_SECTION_ID,
                    volumeID = VOLUME_ID,
                    order = 0,
                    textRole = "sutra",
                    text = "第一段",
                    sourceReferences = listOf(source),
                    legacyIDs = emptyList(),
                    legacyVolumeHint = 1,
                ),
                ScriptureParagraph(
                    paragraphID = SECOND_PARAGRAPH_ID,
                    sectionID = CHILD_SECTION_ID,
                    volumeID = VOLUME_ID,
                    order = 1,
                    textRole = "sutra",
                    text = "第二段",
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
        const val ROOT_SECTION_ID = "test.s000001"
        const val CHILD_SECTION_ID = "test.s000002"
        const val FIRST_PARAGRAPH_ID = "test.p000001"
        const val SECOND_PARAGRAPH_ID = "test.p000002"
    }
}
