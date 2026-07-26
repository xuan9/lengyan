package org.fuxuan.classics.data.persistence

import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.fuxuan.classics.data.persistence.db.ClassicsUserDatabase
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ClassicsUserDatabaseSchemaTest {
    @get:Rule
    val migrationHelper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        ClassicsUserDatabase::class.java,
    )

    @Test
    fun versionOneSchemaIsAValidatedMigrationOriginWithRealLegacyFavorites() = runBlocking {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val expectedPaths = instrumentation.context.assets
            .open("legacy-favorites-migration.json")
            .bufferedReader(Charsets.UTF_8)
            .use { reader ->
                Json.parseToJsonElement(reader.readText())
                    .jsonObject
                    .getValue("cases")
                    .jsonArray
                    .first()
                    .jsonObject
                    .getValue("expected")
                    .jsonObject
                    .getValue("userLikes")
                    .jsonArray
                    .map { it.jsonPrimitive.content }
            }

        migrationHelper.createDatabase(DATABASE_NAME, 1).apply {
            expectedPaths.forEachIndexed { position, legacyPath ->
                execSQL(
                    """
                    INSERT INTO favorites (
                        product_id, edition_id, favorite_id, target_kind,
                        section_id, paragraph_id, legacy_path, position, created_at_epoch_ms
                    ) VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?)
                    """.trimIndent(),
                    arrayOf<Any?>(
                        PRODUCT_ID,
                        EDITION_ID,
                        "legacy:$legacyPath",
                        "UNRESOLVED_LEGACY",
                        legacyPath,
                        position,
                        1_721_600_000_000L,
                    ),
                )
            }
            close()
        }

        val database = Room.databaseBuilder(
            instrumentation.targetContext,
            ClassicsUserDatabase::class.java,
            DATABASE_NAME,
        ).build()
        migrationHelper.closeWhenFinished(database)
        val reopenedPaths = database.favoriteDao()
            .observe(PRODUCT_ID, EDITION_ID)
            .first { it.size == expectedPaths.size }
            .mapNotNull { it.legacyPath }

        assertEquals(expectedPaths, reopenedPaths)
    }

    private companion object {
        const val DATABASE_NAME = "classics-room-v1-origin-test.db"
        const val PRODUCT_ID = "lengyan"
        const val EDITION_ID = "legacy-repository-v1"
    }
}
