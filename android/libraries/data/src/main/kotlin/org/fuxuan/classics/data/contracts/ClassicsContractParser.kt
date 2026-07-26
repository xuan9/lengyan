package org.fuxuan.classics.data.contracts

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent

class ClassicsContractParser {
    private val json = Json {
        ignoreUnknownKeys = false
        isLenient = false
        explicitNulls = false
    }

    fun parseProduct(text: String): ProductManifest =
        json.decodeFromString<ProductManifestDto>(requirePlainUtf8Text(text)).toDomain()

    fun parseBook(text: String): BookManifest =
        json.decodeFromString<BookManifestDto>(requirePlainUtf8Text(text)).toDomain()

    fun parseContent(text: String): ScriptureContent {
        val source = requirePlainUtf8Text(text)
        val document = json.parseToJsonElement(source).jsonObject
        val expectedHash = document["contentHash"]?.jsonPrimitive?.content
            ?: error("content package is missing contentHash")
        val actualHash = CanonicalJson.sha256Omitting(document, "contentHash")
        require(expectedHash == actualHash) {
            "contentHash does not match canonical payload"
        }
        return json.decodeFromJsonElement(ContentPackageDto.serializer(), document).toDomain()
    }

    fun parseAudioCatalog(text: String): AudioCatalog =
        json.decodeFromString<AudioCatalogDto>(requirePlainUtf8Text(text)).toDomain()

    private fun requirePlainUtf8Text(text: String): String {
        require(!text.startsWith('\uFEFF')) { "contract JSON must not contain a byte-order mark" }
        return text
    }
}
