package org.fuxuan.classics.core.content

interface BookRepository {
    suspend fun product(): ProductManifest

    suspend fun book(): BookManifest

    suspend fun content(locale: String): ScriptureContent

    suspend fun audioCatalog(): AudioCatalog?
}
