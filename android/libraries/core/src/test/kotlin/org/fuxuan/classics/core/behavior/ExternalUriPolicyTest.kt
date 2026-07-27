package org.fuxuan.classics.core.behavior

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExternalUriPolicyTest {
    @Test
    fun acceptsOnlyAbsoluteHttpsWithoutCredentials() {
        assertEquals(
            "https://example.org/source",
            ExternalUriPolicy.normalizedHttps("https://example.org/source"),
        )
        assertNull(ExternalUriPolicy.normalizedHttps("http://example.org/source"))
        assertNull(ExternalUriPolicy.normalizedHttps("repo://lengyan-app"))
        assertNull(ExternalUriPolicy.normalizedHttps("https://user@example.org/source"))
        assertNull(ExternalUriPolicy.normalizedHttps("/relative/source"))
    }
}
