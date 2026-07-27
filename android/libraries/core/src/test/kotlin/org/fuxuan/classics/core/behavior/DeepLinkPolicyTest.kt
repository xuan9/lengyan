package org.fuxuan.classics.core.behavior

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class DeepLinkPolicyTest {
    @Test
    fun stableParagraphTargetPreservesAUnicodeCharacterOffset() {
        val deepLink = ScriptureDeepLink(
            productID = "lengyan",
            paragraphID = "paragraph-1",
            characterOffset = 37,
        )

        assertEquals(37, deepLink.characterOffset)
    }

    @Test
    fun legacyTargetCannotCarryACharacterOffset() {
        assertThrows(IllegalArgumentException::class.java) {
            ScriptureDeepLink(
                productID = "lengyan",
                legacyPath = "/legacy/path",
                characterOffset = 1,
            )
        }
    }

    @Test
    fun characterOffsetCannotBeNegative() {
        assertThrows(IllegalArgumentException::class.java) {
            ScriptureDeepLink(
                productID = "lengyan",
                paragraphID = "paragraph-1",
                characterOffset = -1,
            )
        }
    }
}
