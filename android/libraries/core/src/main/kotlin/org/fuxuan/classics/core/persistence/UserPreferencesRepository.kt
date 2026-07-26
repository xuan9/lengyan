package org.fuxuan.classics.core.persistence

import kotlinx.coroutines.flow.Flow
import org.fuxuan.classics.core.behavior.ReadingMode

enum class ThemePreference {
    SYSTEM,
    LIGHT,
    DARK,
}

data class ReminderPreferences(
    val enabled: Boolean = false,
    val hour: Int = 8,
    val minute: Int = 0,
) {
    init {
        require(hour in 0..23) { "reminder hour must be within the local day" }
        require(minute in 0..59) { "reminder minute must be within the hour" }
    }
}

data class AudioPreferences(
    val playbackSpeed: Float = 1f,
    val automaticNextVolumePrefetch: Boolean = true,
    val unmeteredPrefetchOnly: Boolean = true,
) {
    init {
        require(playbackSpeed.isFinite() && playbackSpeed in 0.5f..3f) {
            "audio playback speed must be between 0.5 and 3"
        }
    }
}

data class ReadingProgress(
    val productID: String,
    val editionID: String,
    val paragraphID: String,
    val characterOffset: Int,
    val mode: ReadingMode,
    val updatedAtEpochMilliseconds: Long,
) {
    init {
        require(productID.isNotBlank()) { "reading progress productID must not be blank" }
        require(editionID.isNotBlank()) { "reading progress editionID must not be blank" }
        require(paragraphID.isNotBlank()) { "reading progress paragraphID must not be blank" }
        require(characterOffset >= 0) { "reading progress offset must not be negative" }
        require(updatedAtEpochMilliseconds >= 0) { "reading progress timestamp must not be negative" }
    }
}

data class AudioProgress(
    val productID: String,
    val artifactID: String,
    val positionMilliseconds: Long,
    val durationMilliseconds: Long?,
    val updatedAtEpochMilliseconds: Long,
) {
    init {
        require(productID.isNotBlank()) { "audio progress productID must not be blank" }
        require(artifactID.isNotBlank()) { "audio progress artifactID must not be blank" }
        require(positionMilliseconds >= 0) { "audio position must not be negative" }
        require(durationMilliseconds == null || durationMilliseconds > 0) {
            "known audio duration must be positive"
        }
        require(updatedAtEpochMilliseconds >= 0) { "audio progress timestamp must not be negative" }
    }
}

data class ProductPreferences(
    val theme: ThemePreference,
    val locale: String,
    val fontSizeLevel: Int,
    val readingMode: ReadingMode,
    val reminder: ReminderPreferences,
    val audio: AudioPreferences,
    val readingProgress: ReadingProgress?,
    val audioProgress: AudioProgress?,
    val expandedSectionIDs: Set<String>,
) {
    init {
        require(locale.isNotBlank()) { "preferred locale must not be blank" }
        require(fontSizeLevel in 0..4) { "font size level must be between 0 and 4" }
        require(expandedSectionIDs.none(String::isBlank)) {
            "expanded section IDs must not be blank"
        }
    }
}

data class ProductPreferenceDefaults(
    val locale: String,
    val supportedLocales: Set<String> = setOf(locale),
    val fontSizeLevel: Int = 2,
    val readingMode: ReadingMode = ReadingMode.CHAPTER,
    val reminder: ReminderPreferences = ReminderPreferences(),
    val audio: AudioPreferences = AudioPreferences(),
) {
    init {
        require(locale.isNotBlank()) { "default locale must not be blank" }
        require(supportedLocales.isNotEmpty() && supportedLocales.none(String::isBlank)) {
            "supported locales must not be empty or blank"
        }
        require(locale in supportedLocales) { "default locale must be supported" }
        require(fontSizeLevel in 0..4) { "default font size level must be between 0 and 4" }
    }
}

interface UserPreferencesRepository {
    val preferences: Flow<ProductPreferences>

    suspend fun setTheme(theme: ThemePreference)

    suspend fun setLocale(locale: String)

    suspend fun setFontSizeLevel(level: Int)

    suspend fun setReadingMode(mode: ReadingMode)

    suspend fun setReminder(reminder: ReminderPreferences)

    suspend fun setAudioPreferences(audio: AudioPreferences)

    suspend fun saveReadingProgress(progress: ReadingProgress?)

    suspend fun saveAudioProgress(progress: AudioProgress?)

    suspend fun setExpandedSectionIDs(sectionIDs: Set<String>)
}
