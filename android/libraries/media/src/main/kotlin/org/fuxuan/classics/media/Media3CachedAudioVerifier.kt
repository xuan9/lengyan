package org.fuxuan.classics.media

import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.ContentMetadata
import java.security.MessageDigest

sealed interface CachedAudioVerification {
    data class Verified(
        val bytes: Long,
        val sha256: String,
    ) : CachedAudioVerification

    data class MissingBytes(
        val expectedBytes: Long,
        val cachedBytes: Long,
    ) : CachedAudioVerification

    data class LengthMismatch(
        val expectedBytes: Long,
        val actualBytes: Long,
    ) : CachedAudioVerification

    data class HashMismatch(
        val expectedSha256: String,
        val actualSha256: String,
    ) : CachedAudioVerification

    data class ReadFailure(
        val reason: String,
    ) : CachedAudioVerification
}

@OptIn(UnstableApi::class)
object Media3CachedAudioVerifier {
    fun verify(
        cache: Cache,
        spec: Media3AudioDownloadSpec,
    ): CachedAudioVerification {
        check(Looper.myLooper() != Looper.getMainLooper()) {
            "cached audio verification must not run on the main thread"
        }
        return try {
            verifyCache(cache, spec)
        } catch (exception: Exception) {
            CachedAudioVerification.ReadFailure(
                reason = exception::class.java.simpleName.ifBlank { "unknown" },
            )
        }
    }

    private fun verifyCache(
        cache: Cache,
        spec: Media3AudioDownloadSpec,
    ): CachedAudioVerification {
        val allCachedBytes = cache.getCachedSpans(spec.requestID).fold(0L) { total, span ->
            if (total > Long.MAX_VALUE - span.length) Long.MAX_VALUE else total + span.length
        }
        val expectedCachedBytes = cache.getCachedBytes(
            spec.requestID,
            0,
            spec.expectedBytes,
        )
        if (
            expectedCachedBytes != spec.expectedBytes ||
            !cache.isCached(spec.requestID, 0, spec.expectedBytes)
        ) {
            return CachedAudioVerification.MissingBytes(
                expectedBytes = spec.expectedBytes,
                cachedBytes = allCachedBytes,
            )
        }
        if (allCachedBytes != spec.expectedBytes) {
            return CachedAudioVerification.LengthMismatch(
                expectedBytes = spec.expectedBytes,
                actualBytes = allCachedBytes,
            )
        }

        val contentLength = ContentMetadata.getContentLength(
            cache.getContentMetadata(spec.requestID),
        )
        if (contentLength != spec.expectedBytes) {
            return CachedAudioVerification.LengthMismatch(
                expectedBytes = spec.expectedBytes,
                actualBytes = contentLength,
            )
        }

        val actualSha256 = hashCachedBytes(cache, spec)
        return if (actualSha256 == spec.expectedSha256) {
            CachedAudioVerification.Verified(
                bytes = spec.expectedBytes,
                sha256 = actualSha256,
            )
        } else {
            CachedAudioVerification.HashMismatch(
                expectedSha256 = spec.expectedSha256,
                actualSha256 = actualSha256,
            )
        }
    }

    private fun hashCachedBytes(
        cache: Cache,
        spec: Media3AudioDownloadSpec,
    ): String {
        val source = CacheDataSource(cache, null)
        try {
            val openedLength = source.open(
                DataSpec.Builder()
                    .setUri(spec.uri.toString())
                    .setKey(spec.requestID)
                    .setLength(spec.expectedBytes)
                    .build(),
            )
            if (openedLength != C.LENGTH_UNSET.toLong() && openedLength != spec.expectedBytes) {
                throw CachedAudioLengthException()
            }

            val digest = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(64 * 1024)
            var totalBytes = 0L
            while (true) {
                val read = source.read(buffer, 0, buffer.size)
                if (read == C.RESULT_END_OF_INPUT) break
                if (read == 0) continue
                digest.update(buffer, 0, read)
                totalBytes += read
            }
            if (totalBytes != spec.expectedBytes) {
                throw CachedAudioLengthException()
            }
            return digest.digest().toLowerHex()
        } finally {
            source.close()
        }
    }

    private fun ByteArray.toLowerHex(): String = buildString(size * 2) {
        for (byte in this@toLowerHex) {
            val value = byte.toInt() and 0xff
            append(HEX_DIGITS[value ushr 4])
            append(HEX_DIGITS[value and 0x0f])
        }
    }

    private class CachedAudioLengthException : IllegalStateException()

    private const val HEX_DIGITS = "0123456789abcdef"
}
