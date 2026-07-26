package org.fuxuan.lengyan

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.ScriptureSearchIndex
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.fuxuan.classics.core.persistence.AudioProgress
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import org.fuxuan.classics.core.persistence.UserPreferencesRepository
import org.junit.Assert.assertEquals
import org.junit.Test

class LengyanAppContainerTest {
    @Test
    fun exposesThePermanentLengyanIdentity() {
        val product = LengyanAppContainer(
            bookRepository = UncalledBookRepository,
            userPreferencesRepository = UncalledUserPreferencesRepository,
            favoriteRepository = UncalledFavoriteRepository,
        ).product

        assertEquals("lengyan", product.productID)
        assertEquals("楞严经", product.displayName)
        assertEquals("大佛顶首楞严经", product.canonicalTitle)
    }

    private object UncalledBookRepository : BookRepository {
        override suspend fun product(): ProductManifest = error("not used by this test")

        override suspend fun book(): BookManifest = error("not used by this test")

        override suspend fun content(locale: String): ScriptureContent = error("not used by this test")

        override suspend fun audioCatalog(): AudioCatalog? = error("not used by this test")

        override suspend fun searchIndex(): ScriptureSearchIndex = error("not used by this test")

        override suspend fun resolveLegacyLocation(
            legacyPath: String,
            usage: LegacyLocationUsage,
        ): LegacyLocationResolution = error("not used by this test")
    }

    private object UncalledUserPreferencesRepository : UserPreferencesRepository {
        override val preferences: Flow<ProductPreferences> = emptyFlow()

        override suspend fun setTheme(theme: ThemePreference) = unused()
        override suspend fun setLocale(locale: String) = unused()
        override suspend fun setFontSizeLevel(level: Int) = unused()
        override suspend fun setReadingMode(mode: ReadingMode) = unused()
        override suspend fun setReminder(reminder: ReminderPreferences) = unused()
        override suspend fun setAudioPreferences(audio: AudioPreferences) = unused()
        override suspend fun saveReadingProgress(progress: ReadingProgress?) = unused()
        override suspend fun saveAudioProgress(progress: AudioProgress?) = unused()
        override suspend fun setExpandedSectionIDs(sectionIDs: Set<String>) = unused()
    }

    private object UncalledFavoriteRepository : FavoriteRepository {
        override fun favorites(editionID: String): Flow<List<Favorite>> = emptyFlow()
        override suspend fun add(favorite: Favorite): Boolean = unused()
        override suspend fun remove(editionID: String, favoriteID: String): Boolean = unused()
        override suspend fun replace(editionID: String, favorites: List<Favorite>) = unused()
    }

}

private fun unused(): Nothing = error("not used by this test")
