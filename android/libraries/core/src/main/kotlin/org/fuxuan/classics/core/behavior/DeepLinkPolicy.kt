package org.fuxuan.classics.core.behavior

import java.net.URI
import java.net.URLDecoder

data class ScriptureDeepLink(
    val productID: String,
    val legacyPath: String? = null,
    val paragraphID: String? = null,
    val characterOffset: Int = 0,
) {
    init {
        require(productID.isNotBlank()) { "deep-link productID must not be blank" }
        require((legacyPath == null) != (paragraphID == null)) {
            "deep link must contain exactly one scripture target"
        }
        require(legacyPath == null || legacyPath.isNotBlank()) {
            "deep-link legacy path must not be blank"
        }
        require(paragraphID == null || paragraphID.isNotBlank()) {
            "deep-link paragraph ID must not be blank"
        }
        require(characterOffset >= 0) { "deep-link character offset must not be negative" }
        require(characterOffset == 0 || paragraphID != null) {
            "only a stable paragraph deep link may contain a character offset"
        }
    }
}

class LegacyVerseDeepLinkParser(
    private val productID: String,
    private val scheme: String,
) {
    fun parse(rawURL: String): ScriptureDeepLink? {
        val uri = runCatching { URI(rawURL) }.getOrNull() ?: return null
        if (uri.scheme != scheme || uri.host != VERSE_HOST) return null

        val path = uri.rawQuery
            ?.split('&')
            ?.asSequence()
            ?.map { queryItem -> queryItem.substringBefore('=') to queryItem.substringAfter('=', "") }
            ?.firstOrNull { (name, _) -> decode(name) == PATH_QUERY_ITEM }
            ?.second
            ?.let(::decode)
            ?.takeIf(String::isNotEmpty)
            ?: return null

        return ScriptureDeepLink(productID = productID, legacyPath = path)
    }

    private fun decode(value: String): String? = runCatching {
        URLDecoder.decode(value, Charsets.UTF_8.name())
    }.getOrNull()

    private companion object {
        const val VERSE_HOST = "verse"
        const val PATH_QUERY_ITEM = "path"
    }
}
