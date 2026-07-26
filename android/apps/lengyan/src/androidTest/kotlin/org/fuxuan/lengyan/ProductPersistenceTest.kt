package org.fuxuan.lengyan

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.fuxuan.classics.core.persistence.AudioProgress
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import org.fuxuan.classics.data.persistence.ProductPersistence
import org.fuxuan.classics.data.persistence.ProductPersistenceFactory
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class ProductPersistenceTest {
    private lateinit var context: Context
    private lateinit var productID: String
    private lateinit var persistence: ProductPersistence

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        productID = "test-${UUID.randomUUID()}"
        persistence = createPersistence()
    }

    @After
    fun tearDown() {
        persistence.close()
        context.deleteDatabase(databaseName())
        File(context.filesDir, "datastore/classics-$productID.preferences_pb").delete()
    }

    @Test
    fun dataStorePersistsTypedProductSettingsAndStableProgress() = runBlocking {
        val repository = persistence.userPreferencesRepository
        val initial = repository.preferences.first()

        assertEquals(ThemePreference.SYSTEM, initial.theme)
        assertEquals("zh-Hant", initial.locale)
        assertEquals(2, initial.fontSizeLevel)
        assertEquals(ReadingMode.CHAPTER, initial.readingMode)
        assertFalse(initial.reminder.enabled)
        assertNull(initial.readingProgress)
        assertNull(initial.audioProgress)

        repository.setTheme(ThemePreference.DARK)
        repository.setLocale("zh-Hans")
        repository.setFontSizeLevel(4)
        repository.setReadingMode(ReadingMode.PAGED)
        repository.setReminder(ReminderPreferences(enabled = true, hour = 6, minute = 30))
        repository.setAudioPreferences(
            AudioPreferences(
                playbackSpeed = 1.25f,
                automaticNextVolumePrefetch = true,
                unmeteredPrefetchOnly = false,
            ),
        )
        repository.saveReadingProgress(
            ReadingProgress(
                productID = productID,
                editionID = "edition-v1",
                paragraphID = "test.p000042",
                characterOffset = 73,
                mode = ReadingMode.PAGED,
                updatedAtEpochMilliseconds = 1_721_600_000_000,
            ),
        )
        repository.saveAudioProgress(
            AudioProgress(
                productID = productID,
                artifactID = "test.audio.volume-02",
                positionMilliseconds = 75_250,
                durationMilliseconds = 3_600_000,
                updatedAtEpochMilliseconds = 1_721_600_001_000,
            ),
        )
        repository.setExpandedSectionIDs(setOf("test.s000001", "test.s000042"))

        persistence.close()
        persistence = createPersistence()
        val stored = persistence.userPreferencesRepository.preferences.first {
            it.theme == ThemePreference.DARK
        }
        assertEquals("zh-Hans", stored.locale)
        assertEquals(4, stored.fontSizeLevel)
        assertEquals(ReadingMode.PAGED, stored.readingMode)
        assertEquals(ReminderPreferences(enabled = true, hour = 6, minute = 30), stored.reminder)
        assertEquals(1.25f, stored.audio.playbackSpeed, 0f)
        assertFalse(stored.audio.unmeteredPrefetchOnly)
        assertEquals("test.p000042", stored.readingProgress?.paragraphID)
        assertEquals(73, stored.readingProgress?.characterOffset)
        assertEquals("test.audio.volume-02", stored.audioProgress?.artifactID)
        assertEquals(75_250L, stored.audioProgress?.positionMilliseconds)
        assertEquals(setOf("test.s000001", "test.s000042"), stored.expandedSectionIDs)
    }

    @Test
    fun roomV1PreservesFavoriteOrderAndSurvivesDatabaseReopen() = runBlocking {
        val editionID = "edition-v1"
        val first = Favorite.section(
            productID = productID,
            editionID = editionID,
            sectionID = "test.s000001",
            createdAtEpochMilliseconds = 1_000,
        )
        val second = Favorite.paragraph(
            productID = productID,
            editionID = editionID,
            sectionID = "test.s000002",
            paragraphID = "test.p000002",
            createdAtEpochMilliseconds = 2_000,
        )
        val repository = persistence.favoriteRepository

        assertTrue(repository.add(first))
        assertTrue(repository.add(second))
        assertFalse(repository.add(first))
        assertEquals(
            listOf(second.favoriteID, first.favoriteID),
            repository.favorites(editionID).first { it.size == 2 }.map(Favorite::favoriteID),
        )

        assertTrue(repository.remove(editionID, second.favoriteID))
        assertFalse(repository.remove(editionID, second.favoriteID))
        assertEquals(0, repository.favorites(editionID).first { it.size == 1 }.single().position)

        repository.replace(editionID, listOf(second, first))
        assertEquals(
            listOf(0, 1),
            repository.favorites(editionID).first { it.size == 2 }.map(Favorite::position),
        )

        persistence.close()
        persistence = createPersistence()
        assertEquals(
            listOf(second.favoriteID, first.favoriteID),
            persistence.favoriteRepository
                .favorites(editionID)
                .first { it.size == 2 }
                .map(Favorite::favoriteID),
        )
    }

    private fun createPersistence(): ProductPersistence = ProductPersistenceFactory.create(
        context = context,
        productID = productID,
        defaults = ProductPreferenceDefaults(
            locale = "zh-Hant",
            supportedLocales = setOf("zh-Hant", "zh-Hans"),
        ),
    )

    private fun databaseName() = "classics-$productID.db"
}
