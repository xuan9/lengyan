package org.fuxuan.classics.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ProductIdentityTest {
    @Test
    fun acceptsStableProductIdentity() {
        val product = ProductIdentity(
            productID = "lengyan",
            displayName = "楞严经",
            canonicalTitle = "大佛顶首楞严经",
        )

        assertEquals("lengyan", product.productID)
    }

    @Test
    fun rejectsAProductIDThatCannotBeUsedAsAStableKey() {
        assertThrows(IllegalArgumentException::class.java) {
            ProductIdentity(
                productID = "Lengyan App",
                displayName = "楞严经",
                canonicalTitle = "大佛顶首楞严经",
            )
        }
    }
}
