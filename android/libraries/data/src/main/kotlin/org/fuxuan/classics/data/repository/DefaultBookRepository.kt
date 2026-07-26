package org.fuxuan.classics.data.repository

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.data.contracts.ClassicsContractParser
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicReference

class DefaultBookRepository(
    private val source: ContractSource,
    private val parser: ClassicsContractParser = ClassicsContractParser(),
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : BookRepository {
    private val productCache = AtomicReference<ProductManifest?>()
    private val bookCache = AtomicReference<BookManifest?>()
    private val audioCache = AtomicReference<LoadedAudioCatalog?>()
    private val contentCache = ConcurrentHashMap<String, ScriptureContent>()

    override suspend fun product(): ProductManifest = withContext(ioDispatcher) {
        loadProduct()
    }

    override suspend fun book(): BookManifest = withContext(ioDispatcher) {
        loadBook()
    }

    override suspend fun content(locale: String): ScriptureContent = withContext(ioDispatcher) {
        contentCache[locale] ?: loadContent(locale).let { loaded ->
            contentCache.putIfAbsent(locale, loaded) ?: loaded
        }
    }

    override suspend fun audioCatalog(): AudioCatalog? = withContext(ioDispatcher) {
        audioCache.get()?.let { return@withContext it.catalog }
        val loaded = LoadedAudioCatalog(loadAudioCatalog())
        audioCache.compareAndSet(null, loaded)
        audioCache.get()!!.catalog
    }

    private fun loadProduct(): ProductManifest = productCache.get() ?: run {
        val loaded = parser.parseProduct(source.readText(PRODUCT_MANIFEST_PATH))
        productCache.compareAndSet(null, loaded)
        productCache.get()!!
    }

    private fun loadBook(): BookManifest = bookCache.get() ?: run {
        val product = loadProduct()
        val loaded = parser.parseBook(source.readText(safeRelativePath(product.bookManifestPath)))
        require(loaded.productID == product.productID) {
            "book manifest belongs to a different product"
        }
        require(loaded.sourceManifestPath == product.sourceManifestPath) {
            "product and book source manifest paths disagree"
        }
        require(loaded.supportedLocales == product.supportedLocales) {
            "product and book supported locales disagree"
        }
        bookCache.compareAndSet(null, loaded)
        bookCache.get()!!
    }

    private fun loadContent(locale: String): ScriptureContent {
        val book = loadBook()
        val path = book.contentPackagePaths[locale]
            ?: error("no content package is available for locale $locale")
        val loaded = parser.parseContent(source.readText(safeRelativePath(path)))
        require(loaded.productID == book.productID) { "content belongs to a different product" }
        require(loaded.bookID == book.bookID) { "content belongs to a different book" }
        require(loaded.editionID == book.editionID) { "content belongs to a different edition" }
        require(loaded.contentVersion == book.contentVersion) { "content version does not match book" }
        require(loaded.locale == locale) { "content locale does not match requested locale" }
        require(loaded.normalization == book.normalization) { "content normalization does not match book" }
        return loaded
    }

    private fun loadAudioCatalog(): AudioCatalog? {
        val product = loadProduct()
        val path = product.audioManifestPath ?: return null
        val book = loadBook()
        val loaded = parser.parseAudioCatalog(source.readText(safeRelativePath(path)))
        require(loaded.productID == product.productID) { "audio catalog belongs to a different product" }
        require(loaded.contentVersion == book.contentVersion) {
            "audio catalog content version does not match book"
        }
        require(loaded.supportedLocales == product.supportedLocales) {
            "audio catalog supported locales disagree with product"
        }
        require(loaded.artifacts.all { it.contentMapping.bookID == book.bookID }) {
            "audio artifact belongs to a different book"
        }
        return loaded
    }

    private data class LoadedAudioCatalog(val catalog: AudioCatalog?)

    private companion object {
        const val PRODUCT_MANIFEST_PATH = "product.json"
    }
}
