package org.fuxuan.classics.core.behavior

import java.net.URI

object ExternalUriPolicy {
    fun normalizedHttps(value: String?): String? {
        if (value.isNullOrBlank()) return null
        val uri = runCatching { URI(value).normalize() }.getOrNull() ?: return null
        if (!uri.scheme.equals("https", ignoreCase = true)) return null
        if (uri.host.isNullOrBlank() || uri.userInfo != null) return null
        return uri.toASCIIString()
    }
}
