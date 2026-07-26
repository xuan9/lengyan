package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.FavoriteTargetKind

data class FavoriteNavigationTarget(
    val volumeID: String,
    val anchor: ParagraphTextAnchor,
)

object FavoriteNavigationPolicy {
    fun target(
        content: ScriptureContent,
        favorite: Favorite,
    ): FavoriteNavigationTarget? {
        if (favorite.productID != content.productID || favorite.editionID != content.editionID) {
            return null
        }

        val paragraph = when (favorite.targetKind) {
            FavoriteTargetKind.PARAGRAPH -> favorite.paragraphID?.let(content::paragraph)
            FavoriteTargetKind.SECTION -> resolveSectionFavorite(content, favorite)
            FavoriteTargetKind.UNRESOLVED_LEGACY -> null
        } ?: return null
        val volumeID = paragraph.volumeID ?: return null

        return FavoriteNavigationTarget(
            volumeID = volumeID,
            anchor = ParagraphTextAnchor(paragraph.paragraphID, characterOffset = 0),
        )
    }

    private fun resolveSectionFavorite(
        content: ScriptureContent,
        favorite: Favorite,
    ): ScriptureParagraph? {
        val sectionID = favorite.sectionID ?: return null
        if (content.section(sectionID) == null) return null

        val preferred = favorite.paragraphID?.let(content::paragraph)
        if (
            preferred != null &&
            content.sectionPath(preferred.sectionID).any { it.sectionID == sectionID }
        ) {
            return preferred
        }
        return content.firstParagraphInSubtree(sectionID)
    }
}
