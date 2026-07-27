package org.fuxuan.classics.ui

import org.fuxuan.classics.core.behavior.ShareFileKind
import org.fuxuan.classics.core.behavior.ShareFileNamePolicy

internal data class ShareDocument(
    val locale: String,
    val productTitle: String,
    val volumeTitle: String,
    val text: String,
    val fontSizeLevel: Int,
) {
    init {
        require(locale.isNotBlank()) { "share locale must not be blank" }
        require(productTitle.isNotBlank()) { "share product title must not be blank" }
        require(volumeTitle.isNotBlank()) { "share volume title must not be blank" }
        require(text.isNotEmpty()) { "share text must not be empty" }
        readerTypography(fontSizeLevel)
    }

    val characterCount: Int
        get() = text.codePointCount(0, text.length)

    val completeText: String
        get() = "$volumeTitle\n\n$text\n\n$productTitle"

    val semanticSource: String
        get() = if (volumeTitle.contains(productTitle)) {
            volumeTitle
        } else {
            "$productTitle $volumeTitle"
        }

    val textFileName: String
        get() = ShareFileNamePolicy.fileName(
            locale = locale,
            defaultBaseName = productTitle,
            source = semanticSource,
            kind = ShareFileKind.TEXT,
        )

    fun imageFileName(pageNumber: Int, pageCount: Int): String =
        ShareFileNamePolicy.fileName(
            locale = locale,
            defaultBaseName = productTitle,
            source = semanticSource,
            kind = ShareFileKind.IMAGE,
            pageNumber = pageNumber,
            pageCount = pageCount,
        )

    fun preview(maximumCodePoints: Int = 420): String {
        require(maximumCodePoints > 0) { "share preview limit must be positive" }
        if (characterCount <= maximumCodePoints) return text
        val end = text.offsetByCodePoints(0, maximumCodePoints)
        return text.substring(0, end).trimEnd() + "…"
    }
}
