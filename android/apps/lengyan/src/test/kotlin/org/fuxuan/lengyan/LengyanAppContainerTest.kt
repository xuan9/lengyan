package org.fuxuan.lengyan

import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.junit.Assert.assertEquals
import org.junit.Test

class LengyanAppContainerTest {
    @Test
    fun exposesThePermanentLengyanIdentity() {
        val product = LengyanAppContainer(UncalledBookRepository).product

        assertEquals("lengyan", product.productID)
        assertEquals("楞严经", product.displayName)
        assertEquals("大佛顶首楞严经", product.canonicalTitle)
    }

    private object UncalledBookRepository : BookRepository {
        override suspend fun product(): ProductManifest = error("not used by this test")

        override suspend fun book(): BookManifest = error("not used by this test")

        override suspend fun content(locale: String): ScriptureContent = error("not used by this test")

        override suspend fun audioCatalog(): AudioCatalog? = error("not used by this test")
    }
}
