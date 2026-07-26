package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent

data class ScriptureSearchTarget(
    val volumeID: String,
    val anchor: ParagraphTextAnchor,
    val highlightCharacterCount: Int,
)

object ScriptureSearchNavigationPolicy {
    fun target(
        content: ScriptureContent,
        result: ScriptureSearchResult,
    ): ScriptureSearchTarget? {
        val paragraph = result.paragraphID
            ?.let(content::paragraph)
            ?: content.firstParagraphInSubtree(result.sectionID)
            ?: return null
        if (result.paragraphID != null && paragraph.sectionID != result.sectionID) return null
        val volumeID = paragraph.volumeID ?: return null
        val paragraphCharacterCount = paragraph.text.codePointCount(0, paragraph.text.length)
        val isParagraphMatch = result.paragraphID == paragraph.paragraphID
        val offset = if (isParagraphMatch) {
            result.matchCharacterOffset.coerceAtMost(paragraphCharacterCount)
        } else {
            0
        }
        val highlightCharacterCount = if (isParagraphMatch) {
            result.matchCharacterCount.coerceAtMost(paragraphCharacterCount - offset)
        } else {
            0
        }
        return ScriptureSearchTarget(
            volumeID = volumeID,
            anchor = ParagraphTextAnchor(
                paragraphID = paragraph.paragraphID,
                characterOffset = offset,
            ),
            highlightCharacterCount = highlightCharacterCount,
        )
    }
}
