package org.fuxuan.classics.core.content

import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ScriptureSearchIndex

interface BookRepository {
    suspend fun product(): ProductManifest

    suspend fun book(): BookManifest

    suspend fun content(locale: String): ScriptureContent

    suspend fun audioCatalog(): AudioCatalog?

    suspend fun searchIndex(): ScriptureSearchIndex

    suspend fun resolveLegacyLocation(
        legacyPath: String,
        usage: LegacyLocationUsage,
    ): LegacyLocationResolution
}
