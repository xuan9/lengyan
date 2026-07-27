package org.fuxuan.classics.data.repository

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationResolver
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ScriptureSearchIndex
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.SourceManifest
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
    private val sourceManifestCache = AtomicReference<SourceManifest?>()
    private val audioCache = AtomicReference<LoadedAudioCatalog?>()
    private val legacyResolverCache = AtomicReference<LoadedLegacyResolver?>()
    private val searchIndexCache = AtomicReference<ScriptureSearchIndex?>()
    private val contentCache = ConcurrentHashMap<String, ScriptureContent>()

    override suspend fun product(): ProductManifest = withContext(ioDispatcher) {
        loadProduct()
    }

    override suspend fun book(): BookManifest = withContext(ioDispatcher) {
        loadBook()
    }

    override suspend fun sourceManifest(): SourceManifest = withContext(ioDispatcher) {
        loadSourceManifest()
    }

    override suspend fun content(locale: String): ScriptureContent = withContext(ioDispatcher) {
        loadCachedContent(locale)
    }

    override suspend fun audioCatalog(): AudioCatalog? = withContext(ioDispatcher) {
        audioCache.get()?.let { return@withContext it.catalog }
        val loaded = LoadedAudioCatalog(loadAudioCatalog())
        audioCache.compareAndSet(null, loaded)
        audioCache.get()!!.catalog
    }

    override suspend fun searchIndex(): ScriptureSearchIndex = withContext(ioDispatcher) {
        searchIndexCache.get()?.let { return@withContext it }
        val loaded = ScriptureSearchIndex(
            traditional = loadCachedContent(TRADITIONAL_LOCALE),
            simplified = loadCachedContent(SIMPLIFIED_LOCALE),
        )
        searchIndexCache.compareAndSet(null, loaded)
        searchIndexCache.get()!!
    }

    override suspend fun resolveLegacyLocation(
        legacyPath: String,
        usage: LegacyLocationUsage,
    ): LegacyLocationResolution = withContext(ioDispatcher) {
        val resolver = loadLegacyResolver()
        resolver?.resolve(legacyPath, usage)
            ?: if (legacyPath.isEmpty() || legacyPath == "/") {
                LegacyLocationResolution.Invalid
            } else {
                LegacyLocationResolution.Unresolved
            }
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

    private fun loadSourceManifest(): SourceManifest = sourceManifestCache.get() ?: run {
        val product = loadProduct()
        val book = loadBook()
        val loaded = parser.parseSourceManifest(
            source.readText(safeRelativePath(product.sourceManifestPath)),
        )
        require(loaded.productID == product.productID) {
            "source manifest belongs to a different product"
        }
        require(loaded.bookID == book.bookID) {
            "source manifest belongs to a different book"
        }
        require(loaded.editionID == book.editionID) {
            "source manifest belongs to a different edition"
        }
        sourceManifestCache.compareAndSet(null, loaded)
        sourceManifestCache.get()!!
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
        val documentedSourceIDs = loadSourceManifest().sources.mapTo(mutableSetOf()) { it.sourceID }
        val referencedSourceIDs = buildSet {
            loaded.volumes.flatMapTo(this) { volume ->
                volume.sourceReferences.map { it.sourceID }
            }
            loaded.sections.flatMapTo(this) { section ->
                section.sourceReferences.map { it.sourceID }
            }
            loaded.paragraphs.flatMapTo(this) { paragraph ->
                paragraph.sourceReferences.map { it.sourceID }
            }
        }
        val undocumentedSourceIDs = referencedSourceIDs - documentedSourceIDs
        require(undocumentedSourceIDs.isEmpty()) {
            "content references undocumented sources: ${undocumentedSourceIDs.sorted().joinToString()}"
        }
        val unknownFeaturedParagraphs = loadProduct().featuredParagraphIDs.filter {
            loaded.paragraph(it) == null
        }
        require(unknownFeaturedParagraphs.isEmpty()) {
            "featured paragraphs are missing from $locale content: ${unknownFeaturedParagraphs.joinToString()}"
        }
        return loaded
    }

    private fun loadCachedContent(locale: String): ScriptureContent =
        contentCache[locale] ?: loadContent(locale).let { loaded ->
            contentCache.putIfAbsent(locale, loaded) ?: loaded
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

    private fun loadLegacyResolver(): LegacyLocationResolver? {
        legacyResolverCache.get()?.let { return it.resolver }
        val book = loadBook()
        val loaded = book.legacyMapPath?.let { path ->
            val map = parser.parseLegacyPathMap(source.readText(safeRelativePath(path)))
            require(map.productID == book.productID) { "legacy map belongs to a different product" }
            require(map.bookID == book.bookID) { "legacy map belongs to a different book" }
            require(map.editionID == book.editionID) { "legacy map belongs to a different edition" }
            map.resolver()
        }
        val cached = LoadedLegacyResolver(loaded)
        legacyResolverCache.compareAndSet(null, cached)
        return legacyResolverCache.get()!!.resolver
    }

    private data class LoadedAudioCatalog(val catalog: AudioCatalog?)
    private data class LoadedLegacyResolver(val resolver: LegacyLocationResolver?)

    private companion object {
        const val PRODUCT_MANIFEST_PATH = "product.json"
        const val TRADITIONAL_LOCALE = "zh-Hant"
        const val SIMPLIFIED_LOCALE = "zh-Hans"
    }
}
