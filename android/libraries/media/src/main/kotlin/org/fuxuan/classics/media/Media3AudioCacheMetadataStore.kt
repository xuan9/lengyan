package org.fuxuan.classics.media

import androidx.annotation.OptIn
import androidx.annotation.WorkerThread
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.ContentMetadata
import androidx.media3.datasource.cache.ContentMetadataMutations

@OptIn(UnstableApi::class)
class Media3AudioCacheMetadataStore(
    private val cache: Cache,
) : AudioCacheMetadataStore {
    @WorkerThread
    override fun records(): List<AudioCacheRecord> = cache.keys
        .mapNotNull { requestID -> readRecord(requestID) }
        .sortedWith(
            compareBy<AudioCacheRecord>(
                { it.key.productID },
                { it.key.artifactID },
                AudioCacheRecord::requestID,
            ),
        )

    @WorkerThread
    override fun write(record: AudioCacheRecord) {
        cache.applyContentMetadataMutations(
            record.requestID,
            ContentMetadataMutations()
                .set(KEY_SCHEMA_VERSION, SCHEMA_VERSION)
                .set(KEY_PRODUCT_ID, record.key.productID)
                .set(KEY_ARTIFACT_ID, record.key.artifactID)
                .set(KEY_RENDITION_ID, record.reservation.renditionID)
                .set(KEY_EXPECTED_BYTES, record.expectedBytes)
                .set(KEY_EXPECTED_SHA_256, record.reservation.expectedSha256)
                .set(KEY_STATE, record.state.name)
                .set(KEY_LAST_ACCESS_MILLISECONDS, record.lastAccessEpochMilliseconds),
        )
    }

    @WorkerThread
    override fun remove(requestID: String) {
        require(requestID.isNotBlank()) { "removed audio requestID must not be blank" }
        cache.applyContentMetadataMutations(
            requestID,
            ContentMetadataMutations()
                .remove(KEY_SCHEMA_VERSION)
                .remove(KEY_PRODUCT_ID)
                .remove(KEY_ARTIFACT_ID)
                .remove(KEY_RENDITION_ID)
                .remove(KEY_EXPECTED_BYTES)
                .remove(KEY_EXPECTED_SHA_256)
                .remove(KEY_STATE)
                .remove(KEY_LAST_ACCESS_MILLISECONDS),
        )
    }

    private fun readRecord(requestID: String): AudioCacheRecord? {
        val metadata = cache.getContentMetadata(requestID)
        if (!metadata.contains(KEY_SCHEMA_VERSION)) return null

        val schemaVersion = metadata.get(KEY_SCHEMA_VERSION, MISSING_LONG)
        require(schemaVersion == SCHEMA_VERSION) {
            "unsupported audio cache metadata schema $schemaVersion"
        }
        val stateName = metadata.requiredString(KEY_STATE)
        val state = try {
            AudioCacheRecordState.valueOf(stateName)
        } catch (_: IllegalArgumentException) {
            throw IllegalStateException("unknown audio cache state $stateName")
        }
        return AudioCacheRecord(
            reservation = AudioCacheReservation(
                requestID = requestID,
                key = AudioCacheKey(
                    productID = metadata.requiredString(KEY_PRODUCT_ID),
                    artifactID = metadata.requiredString(KEY_ARTIFACT_ID),
                ),
                renditionID = metadata.requiredString(KEY_RENDITION_ID),
                expectedBytes = metadata.requiredLong(KEY_EXPECTED_BYTES),
                expectedSha256 = metadata.requiredString(KEY_EXPECTED_SHA_256),
            ),
            state = state,
            lastAccessEpochMilliseconds = metadata.requiredLong(
                KEY_LAST_ACCESS_MILLISECONDS,
            ),
        )
    }

    private fun ContentMetadata.requiredString(key: String): String {
        require(contains(key)) { "audio cache metadata is missing $key" }
        val value = get(key, MISSING_STRING)
        require(value != null && value != MISSING_STRING) {
            "audio cache metadata has an invalid $key"
        }
        return value
    }

    private fun ContentMetadata.requiredLong(key: String): Long {
        require(contains(key)) { "audio cache metadata is missing $key" }
        return get(key, MISSING_LONG).also { value ->
            require(value != MISSING_LONG) { "audio cache metadata has an invalid $key" }
        }
    }

    private companion object {
        const val SCHEMA_VERSION = 1L
        const val MISSING_LONG = Long.MIN_VALUE
        const val MISSING_STRING = "\u0000"
        const val KEY_SCHEMA_VERSION = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_schema"
        const val KEY_PRODUCT_ID = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_product_id"
        const val KEY_ARTIFACT_ID = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_artifact_id"
        const val KEY_RENDITION_ID = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_rendition_id"
        const val KEY_EXPECTED_BYTES = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_expected_bytes"
        const val KEY_EXPECTED_SHA_256 = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_sha256"
        const val KEY_STATE = ContentMetadata.KEY_CUSTOM_PREFIX + "classics_state"
        const val KEY_LAST_ACCESS_MILLISECONDS =
            ContentMetadata.KEY_CUSTOM_PREFIX + "classics_last_access_ms"
    }
}
