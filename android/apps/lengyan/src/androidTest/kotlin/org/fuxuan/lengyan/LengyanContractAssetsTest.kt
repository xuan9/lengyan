package org.fuxuan.lengyan

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LengyanContractAssetsTest {
    @Test
    fun packagedAssetsLoadThroughTheProductionRepository() = runBlocking {
        val application = InstrumentationRegistry.getInstrumentation()
            .targetContext
            .applicationContext as LengyanApplication
        val repository = application.container.bookRepository

        val product = repository.product()
        val book = repository.book()
        val content = repository.content("zh-Hant")
        val audio = repository.audioCatalog()
        val searchResults = repository.searchIndex().search(
            query = "转物",
            displayLocale = "zh-Hant",
        )

        assertEquals("lengyan", product.productID)
        assertEquals("legacy-repository-v1", book.editionID)
        assertEquals("29bbc91813ba88ab6dea6b3b3344bcc85671df2f4c1f90771f395645456a5ad0", content.contentHash)
        assertEquals(10, content.volumes.size)
        assertEquals(1_669, content.sections.size)
        assertEquals(1_262, content.paragraphs.size)
        assertEquals("如是我聞，一時佛在室羅筏城，祇桓精舍。", content.paragraphs.first().text)
        assertNotNull(audio)
        assertEquals(11, audio?.artifacts?.size)
        assertTrue(searchResults.any { result -> "轉物" in result.displayText })
    }
}
