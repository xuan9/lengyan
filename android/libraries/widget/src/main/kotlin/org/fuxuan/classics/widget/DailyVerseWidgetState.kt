package org.fuxuan.classics.widget

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import org.fuxuan.classics.core.persistence.ThemePreference
import java.time.LocalDate

private val Context.dailyVerseWidgetStateDataStore by preferencesDataStore(
    name = "daily_verse_widget_state",
)

class DailyVerseWidgetStateStore(context: Context) {
    private val dataStore = context.applicationContext.dailyVerseWidgetStateDataStore

    suspend fun lockedSelectionID(
        productID: String,
        contentVersion: String,
        localDate: LocalDate,
        proposedID: String,
        isParagraphAvailable: (String) -> Boolean,
    ): String {
        require(productID.isNotBlank()) { "daily verse productID must not be blank" }
        require(contentVersion.isNotBlank()) { "daily verse contentVersion must not be blank" }
        require(proposedID.isNotBlank()) { "daily verse paragraphID must not be blank" }

        var selectedID = proposedID
        dataStore.edit { preferences ->
            val savedID = preferences[Keys.selectionParagraphID]
                ?.takeIf {
                    preferences[Keys.schemaVersion] == SCHEMA_VERSION &&
                        preferences[Keys.selectionProductID] == productID &&
                        preferences[Keys.selectionContentVersion] == contentVersion &&
                        preferences[Keys.selectionLocalDate] == localDate.toString()
                }
                ?.takeIf(isParagraphAvailable)
            selectedID = savedID ?: proposedID

            preferences[Keys.schemaVersion] = SCHEMA_VERSION
            preferences[Keys.selectionProductID] = productID
            preferences[Keys.selectionContentVersion] = contentVersion
            preferences[Keys.selectionLocalDate] = localDate.toString()
            preferences[Keys.selectionParagraphID] = selectedID
        }
        return selectedID
    }

    suspend fun saveSnapshot(
        productID: String,
        contentVersion: String,
        localDate: LocalDate,
        content: DailyVerseWidgetContent,
    ) {
        require(productID.isNotBlank()) { "daily verse productID must not be blank" }
        require(contentVersion.isNotBlank()) { "daily verse contentVersion must not be blank" }
        require(content.productTitle.isNotBlank()) { "daily verse product title must not be blank" }
        require(content.header.isNotBlank()) { "daily verse header must not be blank" }
        require(content.text.isNotBlank()) { "daily verse text must not be blank" }
        val paragraphID = requireNotNull(content.paragraphID?.takeIf(String::isNotBlank)) {
            "daily verse snapshot requires a paragraphID"
        }

        dataStore.edit { preferences ->
            preferences[Keys.schemaVersion] = SCHEMA_VERSION
            preferences[Keys.snapshotProductID] = productID
            preferences[Keys.snapshotContentVersion] = contentVersion
            preferences[Keys.snapshotLocalDate] = localDate.toString()
            preferences[Keys.snapshotProductTitle] = content.productTitle
            preferences[Keys.snapshotHeader] = content.header
            preferences[Keys.snapshotText] = content.text
            preferences[Keys.snapshotSource] = content.source
            preferences[Keys.snapshotParagraphID] = paragraphID
            preferences[Keys.snapshotTheme] = content.theme.name
            preferences[Keys.snapshotTapHint] = content.tapHint
        }
    }

    suspend fun lastSnapshot(): DailyVerseWidgetContent? {
        val preferences = dataStore.data.first()
        if (preferences[Keys.schemaVersion] != SCHEMA_VERSION) return null

        return runCatching {
            required(preferences, Keys.snapshotProductID)
            required(preferences, Keys.snapshotContentVersion)
            LocalDate.parse(required(preferences, Keys.snapshotLocalDate))
            DailyVerseWidgetContent(
                productTitle = required(preferences, Keys.snapshotProductTitle),
                header = required(preferences, Keys.snapshotHeader),
                text = required(preferences, Keys.snapshotText),
                source = preferences[Keys.snapshotSource].orEmpty(),
                paragraphID = required(preferences, Keys.snapshotParagraphID),
                theme = ThemePreference.entries.first {
                    it.name == required(preferences, Keys.snapshotTheme)
                },
                tapHint = preferences[Keys.snapshotTapHint].orEmpty(),
            )
        }.getOrNull()
    }

    private fun required(
        preferences: Preferences,
        key: Preferences.Key<String>,
    ): String = requireNotNull(preferences[key]?.takeIf(String::isNotBlank)) {
        "daily verse snapshot is missing ${key.name}"
    }

    private object Keys {
        val schemaVersion = intPreferencesKey("storage_schema_version")
        val selectionProductID = stringPreferencesKey("selection_product_id")
        val selectionContentVersion = stringPreferencesKey("selection_content_version")
        val selectionLocalDate = stringPreferencesKey("selection_local_date")
        val selectionParagraphID = stringPreferencesKey("selection_paragraph_id")
        val snapshotProductID = stringPreferencesKey("snapshot_product_id")
        val snapshotContentVersion = stringPreferencesKey("snapshot_content_version")
        val snapshotLocalDate = stringPreferencesKey("snapshot_local_date")
        val snapshotProductTitle = stringPreferencesKey("snapshot_product_title")
        val snapshotHeader = stringPreferencesKey("snapshot_header")
        val snapshotText = stringPreferencesKey("snapshot_text")
        val snapshotSource = stringPreferencesKey("snapshot_source")
        val snapshotParagraphID = stringPreferencesKey("snapshot_paragraph_id")
        val snapshotTheme = stringPreferencesKey("snapshot_theme")
        val snapshotTapHint = stringPreferencesKey("snapshot_tap_hint")
    }

    private companion object {
        const val SCHEMA_VERSION = 1
    }
}
