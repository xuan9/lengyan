package org.fuxuan.classics.core.behavior

import java.net.URI
import java.net.URLDecoder

data class ScriptureDeepLink(
    val productID: String,
    val legacyPath: String,
)

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
