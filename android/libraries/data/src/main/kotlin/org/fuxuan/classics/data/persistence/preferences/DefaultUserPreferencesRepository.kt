package org.fuxuan.classics.data.persistence.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.fuxuan.classics.core.persistence.AudioProgress
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import org.fuxuan.classics.core.persistence.UserPreferencesRepository
import java.io.IOException

internal class DefaultUserPreferencesRepository(
    private val productID: String,
    private val defaults: ProductPreferenceDefaults,
    private val dataStore: DataStore<Preferences>,
) : UserPreferencesRepository {
    override val preferences: Flow<ProductPreferences> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map(::toDomain)
        .distinctUntilChanged()

    init {
        require(productID.isNotBlank()) { "preferences productID must not be blank" }
    }

    override suspend fun setTheme(theme: ThemePreference) {
        update { preferences -> preferences[Keys.theme] = theme.name }
    }

    override suspend fun setLocale(locale: String) {
        require(locale in defaults.supportedLocales) { "preferred locale is not supported" }
        update { preferences -> preferences[Keys.locale] = locale }
    }

    override suspend fun setFontSizeLevel(level: Int) {
        require(level in 0..4) { "font size level must be between 0 and 4" }
        update { preferences -> preferences[Keys.fontSizeLevel] = level }
    }

    override suspend fun setReadingMode(mode: ReadingMode) {
        update { preferences -> preferences[Keys.readingMode] = mode.name }
    }

    override suspend fun setReminder(reminder: ReminderPreferences) {
        update { preferences ->
            preferences[Keys.reminderEnabled] = reminder.enabled
            preferences[Keys.reminderHour] = reminder.hour
            preferences[Keys.reminderMinute] = reminder.minute
        }
    }

    override suspend fun setAudioPreferences(audio: AudioPreferences) {
        update { preferences ->
            preferences[Keys.audioPlaybackSpeed] = audio.playbackSpeed
            preferences[Keys.audioAutomaticPrefetch] = audio.automaticNextVolumePrefetch
            preferences[Keys.audioUnmeteredPrefetchOnly] = audio.unmeteredPrefetchOnly
        }
    }

    override suspend fun saveReadingProgress(progress: ReadingProgress?) {
        require(progress == null || progress.productID == productID) {
            "reading progress belongs to a different product"
        }
        update { preferences ->
            if (progress == null) {
                preferences.removeReadingProgress()
            } else {
                preferences[Keys.readingEditionID] = progress.editionID
                preferences[Keys.readingParagraphID] = progress.paragraphID
                preferences[Keys.readingCharacterOffset] = progress.characterOffset
                preferences[Keys.readingProgressMode] = progress.mode.name
                preferences[Keys.readingUpdatedAt] = progress.updatedAtEpochMilliseconds
            }
        }
    }

    override suspend fun saveAudioProgress(progress: AudioProgress?) {
        require(progress == null || progress.productID == productID) {
            "audio progress belongs to a different product"
        }
        update { preferences ->
            if (progress == null) {
                preferences.removeAudioProgress()
            } else {
                preferences[Keys.audioArtifactID] = progress.artifactID
                preferences[Keys.audioPosition] = progress.positionMilliseconds
                val duration = progress.durationMilliseconds
                if (duration != null) {
                    preferences[Keys.audioDuration] = duration
                } else {
                    preferences.remove(Keys.audioDuration)
                }
                preferences[Keys.audioUpdatedAt] = progress.updatedAtEpochMilliseconds
            }
        }
    }

    override suspend fun setExpandedSectionIDs(sectionIDs: Set<String>) {
        require(sectionIDs.none(String::isBlank)) { "expanded section IDs must not be blank" }
        update { preferences -> preferences[Keys.expandedSectionIDs] = sectionIDs.toSet() }
    }

    private suspend fun update(transform: (MutablePreferences) -> Unit) {
        dataStore.edit { preferences ->
            preferences[Keys.schemaVersion] = SCHEMA_VERSION
            transform(preferences)
        }
    }

    private fun toDomain(preferences: Preferences): ProductPreferences {
        val schemaVersion = preferences[Keys.schemaVersion] ?: 0
        require(schemaVersion in 0..SCHEMA_VERSION) {
            "unsupported preferences schema version: $schemaVersion"
        }
        return ProductPreferences(
            theme = preferences[Keys.theme].enumOrDefault(ThemePreference.SYSTEM),
            locale = preferences[Keys.locale]
                ?.takeIf(defaults.supportedLocales::contains)
                ?: defaults.locale,
            fontSizeLevel = preferences[Keys.fontSizeLevel]
                ?.takeIf { it in 0..4 }
                ?: defaults.fontSizeLevel,
            readingMode = preferences[Keys.readingMode].enumOrDefault(defaults.readingMode),
            reminder = ReminderPreferences(
                enabled = preferences[Keys.reminderEnabled] ?: defaults.reminder.enabled,
                hour = preferences[Keys.reminderHour]
                    ?.takeIf { it in 0..23 }
                    ?: defaults.reminder.hour,
                minute = preferences[Keys.reminderMinute]
                    ?.takeIf { it in 0..59 }
                    ?: defaults.reminder.minute,
            ),
            audio = AudioPreferences(
                playbackSpeed = preferences[Keys.audioPlaybackSpeed]
                    ?.takeIf { it.isFinite() && it in 0.5f..3f }
                    ?: defaults.audio.playbackSpeed,
                automaticNextVolumePrefetch = preferences[Keys.audioAutomaticPrefetch]
                    ?: defaults.audio.automaticNextVolumePrefetch,
                unmeteredPrefetchOnly = preferences[Keys.audioUnmeteredPrefetchOnly]
                    ?: defaults.audio.unmeteredPrefetchOnly,
            ),
            readingProgress = preferences.readingProgress(),
            audioProgress = preferences.audioProgress(),
            expandedSectionIDs = preferences[Keys.expandedSectionIDs]
                .orEmpty()
                .filterTo(linkedSetOf(), String::isNotBlank),
        )
    }

    private fun Preferences.readingProgress(): ReadingProgress? {
        val editionID = this[Keys.readingEditionID] ?: return null
        val paragraphID = this[Keys.readingParagraphID] ?: return null
        val offset = this[Keys.readingCharacterOffset] ?: return null
        val mode = this[Keys.readingProgressMode].enumOrNull<ReadingMode>() ?: return null
        val updatedAt = this[Keys.readingUpdatedAt] ?: return null
        return runCatching {
            ReadingProgress(
                productID = productID,
                editionID = editionID,
                paragraphID = paragraphID,
                characterOffset = offset,
                mode = mode,
                updatedAtEpochMilliseconds = updatedAt,
            )
        }.getOrNull()
    }

    private fun Preferences.audioProgress(): AudioProgress? {
        val artifactID = this[Keys.audioArtifactID] ?: return null
        val position = this[Keys.audioPosition] ?: return null
        val updatedAt = this[Keys.audioUpdatedAt] ?: return null
        return runCatching {
            AudioProgress(
                productID = productID,
                artifactID = artifactID,
                positionMilliseconds = position,
                durationMilliseconds = this[Keys.audioDuration],
                updatedAtEpochMilliseconds = updatedAt,
            )
        }.getOrNull()
    }

    private fun MutablePreferences.removeReadingProgress() {
        remove(Keys.readingEditionID)
        remove(Keys.readingParagraphID)
        remove(Keys.readingCharacterOffset)
        remove(Keys.readingProgressMode)
        remove(Keys.readingUpdatedAt)
    }

    private fun MutablePreferences.removeAudioProgress() {
        remove(Keys.audioArtifactID)
        remove(Keys.audioPosition)
        remove(Keys.audioDuration)
        remove(Keys.audioUpdatedAt)
    }

    private object Keys {
        val schemaVersion = intPreferencesKey("storage_schema_version")
        val theme = stringPreferencesKey("theme")
        val locale = stringPreferencesKey("locale")
        val fontSizeLevel = intPreferencesKey("font_size_level")
        val readingMode = stringPreferencesKey("reading_mode")
        val reminderEnabled = booleanPreferencesKey("reminder_enabled")
        val reminderHour = intPreferencesKey("reminder_hour")
        val reminderMinute = intPreferencesKey("reminder_minute")
        val audioPlaybackSpeed = floatPreferencesKey("audio_playback_speed")
        val audioAutomaticPrefetch = booleanPreferencesKey("audio_automatic_prefetch")
        val audioUnmeteredPrefetchOnly = booleanPreferencesKey("audio_unmetered_prefetch_only")
        val readingEditionID = stringPreferencesKey("reading_edition_id")
        val readingParagraphID = stringPreferencesKey("reading_paragraph_id")
        val readingCharacterOffset = intPreferencesKey("reading_character_offset")
        val readingProgressMode = stringPreferencesKey("reading_progress_mode")
        val readingUpdatedAt = longPreferencesKey("reading_updated_at_epoch_ms")
        val audioArtifactID = stringPreferencesKey("audio_artifact_id")
        val audioPosition = longPreferencesKey("audio_position_ms")
        val audioDuration = longPreferencesKey("audio_duration_ms")
        val audioUpdatedAt = longPreferencesKey("audio_updated_at_epoch_ms")
        val expandedSectionIDs = stringSetPreferencesKey("expanded_section_ids")
    }

    private companion object {
        const val SCHEMA_VERSION = 1
    }
}

private inline fun <reified T : Enum<T>> String?.enumOrNull(): T? =
    this?.let { rawValue -> enumValues<T>().firstOrNull { it.name == rawValue } }

private inline fun <reified T : Enum<T>> String?.enumOrDefault(default: T): T =
    enumOrNull<T>() ?: default
