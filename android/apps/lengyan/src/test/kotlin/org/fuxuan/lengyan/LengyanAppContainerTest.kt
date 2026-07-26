package org.fuxuan.lengyan

import org.junit.Assert.assertEquals
import org.junit.Test

class LengyanAppContainerTest {
    @Test
    fun exposesThePermanentLengyanIdentity() {
        val product = LengyanAppContainer().product

        assertEquals("lengyan", product.productID)
        assertEquals("楞严经", product.displayName)
        assertEquals("大佛顶首楞严经", product.canonicalTitle)
    }
}
