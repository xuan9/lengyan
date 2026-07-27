package org.fuxuan.classics.core.behavior

enum class ShareFileKind {
    IMAGE,
    TEXT,
}

object ShareFileNamePolicy {
    fun fileName(
        locale: String,
        defaultBaseName: String,
        source: String?,
        kind: ShareFileKind,
        uniqueSuffix: String? = null,
        pageNumber: Int? = null,
        pageCount: Int? = null,
    ): String {
        require(defaultBaseName.isNotBlank()) { "default share file name must not be blank" }
        require(
            uniqueSuffix == null ||
                uniqueSuffix.isNotBlank() && uniqueSuffix.matches(SAFE_SUFFIX),
        ) { "share file suffix must be file-name safe" }
        require((pageNumber == null) == (pageCount == null)) {
            "share page number and count must be supplied together"
        }

        val baseName = sanitizedComponent(source.orEmpty()).ifEmpty {
            sanitizedComponent(defaultBaseName)
        }
        require(baseName.isNotEmpty()) { "share file name must contain a base name" }

        val simplified = locale == "zh-Hans"
        val descriptor = when (kind) {
            ShareFileKind.IMAGE -> if (simplified) "分享图" else "分享圖"
            ShareFileKind.TEXT -> if (simplified) "经文" else "經文"
        }
        val pagedDescriptor = if (pageNumber != null && pageCount != null) {
            require(pageNumber > 0 && pageCount > 0 && pageNumber <= pageCount) {
                "share page must be within page count"
            }
            val width = maxOf(2, pageCount.toString().length)
            "$descriptor-${pageNumber.toString().padStart(width, '0')}-${pageCount.toString().padStart(width, '0')}"
        } else {
            descriptor
        }
        val extension = if (kind == ShareFileKind.IMAGE) "jpg" else "txt"
        val suffix = uniqueSuffix?.let { "-$it" }.orEmpty()
        return "$baseName-$pagedDescriptor$suffix.$extension"
    }

    fun sanitizedComponent(rawValue: String): String = rawValue
        .replace(REMOVED_PUNCTUATION, "")
        .replace(INVALID_CHARACTERS, "-")
        .replace(WHITESPACE, "-")
        .replace(REPEATED_DASH, "-")
        .trim(' ', '-')

    private val REMOVED_PUNCTUATION = Regex("[《》「」]")
    private val INVALID_CHARACTERS = Regex("[/\\\\?%*|\"<>:：\\n\\r\\t]")
    private val WHITESPACE = Regex("\\s+")
    private val REPEATED_DASH = Regex("-+")
    private val SAFE_SUFFIX = Regex("[A-Za-z0-9._-]+")
}
