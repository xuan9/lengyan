package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureVolume

data class ParagraphTextAnchor(
    val paragraphID: String,
    val characterOffset: Int,
) {
    init {
        require(paragraphID.isNotBlank()) { "anchor paragraphID must not be blank" }
        require(characterOffset >= 0) { "anchor character offset must not be negative" }
    }
}

class VolumeReadingDocument private constructor(
    val volume: ScriptureVolume,
    val text: String,
    private val spans: List<ParagraphSpan>,
) {
    private val spansByParagraphID = spans.associateBy { it.paragraph.paragraphID }

    init {
        require(text.isNotEmpty()) { "volume reading text must not be empty" }
        require(spans.isNotEmpty()) { "volume reading document must contain a paragraph" }
        require(spansByParagraphID.size == spans.size) {
            "volume reading paragraph IDs must be unique"
        }
    }

    fun anchorAtUtf16Offset(utf16Offset: Int): ParagraphTextAnchor {
        val clampedOffset = utf16Offset.coerceIn(0, text.length)
        val span = spans.lastOrNull { it.startUtf16Offset <= clampedOffset } ?: spans.first()
        val paragraphText = span.paragraph.text
        val relativeOffset = normalizeUtf16Boundary(
            text = paragraphText,
            offset = (clampedOffset - span.startUtf16Offset).coerceIn(0, paragraphText.length),
        )
        return ParagraphTextAnchor(
            paragraphID = span.paragraph.paragraphID,
            characterOffset = paragraphText.codePointCount(0, relativeOffset),
        )
    }

    fun utf16OffsetFor(anchor: ParagraphTextAnchor): Int? {
        val span = spansByParagraphID[anchor.paragraphID] ?: return null
        val paragraphText = span.paragraph.text
        val codePointOffset = anchor.characterOffset.coerceAtMost(
            paragraphText.codePointCount(0, paragraphText.length),
        )
        return span.startUtf16Offset + paragraphText.offsetByCodePoints(0, codePointOffset)
    }

    companion object {
        private const val PARAGRAPH_SEPARATOR = "\n\n"

        fun from(content: ScriptureContent, volumeID: String): VolumeReadingDocument {
            val volume = requireNotNull(content.volume(volumeID)) {
                "volume does not exist in content: $volumeID"
            }
            val paragraphs = content.paragraphsInReadingOrder().filter { it.volumeID == volumeID }
            require(paragraphs.isNotEmpty()) { "volume contains no readable paragraphs: $volumeID" }

            val text = buildString {
                paragraphs.forEachIndexed { index, paragraph ->
                    if (index > 0) append(PARAGRAPH_SEPARATOR)
                    append(paragraph.text)
                }
            }
            var startOffset = 0
            val spans = paragraphs.mapIndexed { index, paragraph ->
                if (index > 0) startOffset += PARAGRAPH_SEPARATOR.length
                ParagraphSpan(
                    paragraph = paragraph,
                    startUtf16Offset = startOffset,
                ).also { startOffset += paragraph.text.length }
            }
            return VolumeReadingDocument(volume = volume, text = text, spans = spans)
        }
    }
}

private data class ParagraphSpan(
    val paragraph: ScriptureParagraph,
    val startUtf16Offset: Int,
)

private fun normalizeUtf16Boundary(text: String, offset: Int): Int {
    if (offset <= 0 || offset >= text.length) return offset
    return if (text[offset].isLowSurrogate() && text[offset - 1].isHighSurrogate()) {
        offset - 1
    } else {
        offset
    }
}
