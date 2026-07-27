package org.fuxuan.classics.media.harness

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.media.AudioDownloadIntegrityEvent
import org.fuxuan.classics.media.AudioDownloadIntegrityIssue
import org.fuxuan.classics.media.AudioDownloadIntegrityListener
import org.fuxuan.classics.media.AudioDownloadRepairEnqueuer
import org.fuxuan.classics.media.CachedAudioVerification
import org.fuxuan.classics.media.Media3AudioDownloadIntegrityCoordinator
import org.fuxuan.classics.media.Media3AudioDownloadRuntime
import org.fuxuan.classics.media.Media3AudioDownloadSpec
import org.fuxuan.classics.media.Media3CachedAudioVerifier
import org.fuxuan.classics.media.ResolvedAndroidAudioAsset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@OptIn(UnstableApi::class)
@RunWith(AndroidJUnit4::class)
class MediaDownloadContractTest {
    @Test
    fun interruptedServiceDownloadResumesAndVerifiesOnlyCachedBytes() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val payload = ByteArray(512 * 1024) { index ->
            ((index * 31 + 17) and 0xff).toByte()
        }
        val expectedSha256 = payload.sha256()
        val spec = downloadSpec(payload.size.toLong(), expectedSha256)
        val request = spec.toDownloadRequest()
        val server = InterruptingRangeServer(payload)
        val terminalDownload = AtomicReference<Download>()
        val terminalException = AtomicReference<Exception?>()
        val terminalLatch = CountDownLatch(1)
        var runtime: Media3AudioDownloadRuntime? = null

        val listener = object : DownloadManager.Listener {
            override fun onDownloadChanged(
                downloadManager: DownloadManager,
                download: Download,
                finalException: Exception?,
            ) {
                if (
                    download.request.id == spec.requestID &&
                    download.state in setOf(Download.STATE_COMPLETED, Download.STATE_FAILED)
                ) {
                    terminalDownload.set(download)
                    terminalException.set(finalException)
                    terminalLatch.countDown()
                }
            }
        }

        try {
            assertEquals(
                "lengyan:lengyan.audio.range-test:android.test.range",
                spec.requestID,
            )
            assertEquals(spec.requestID, request.id)
            assertEquals(spec.requestID, request.customCacheKey)
            grantNotificationPermission(context)

            val upstreamFactory = ResolvingDataSource.Factory(
                DefaultHttpDataSource.Factory()
                    .setConnectTimeoutMs(5_000)
                    .setReadTimeoutMs(5_000),
            ) { dataSpec -> dataSpec.redirectTo(server.uri) }

            runtime = onMainThread {
                HarnessAudioDownloadEnvironment.installForTest(
                    context,
                    upstreamFactory,
                ).also { installed ->
                    installed.downloadManager.addListener(listener)
                    DownloadService.sendAddDownload(
                        context,
                        HarnessAudioDownloadService::class.java,
                        request,
                        true,
                    )
                }
            }
            val activeRuntime = checkNotNull(runtime)

            assertTrue(
                "Media3 download did not reach a terminal state",
                terminalLatch.await(30, TimeUnit.SECONDS),
            )
            assertEquals(Download.STATE_COMPLETED, terminalDownload.get()?.state)
            assertNull(terminalException.get())
            server.assertHealthy()
            assertTrue(
                "download retry did not request a non-zero byte range",
                server.hasNonZeroRangeRequest(),
            )

            server.close()
            assertEquals(
                CachedAudioVerification.Verified(
                    bytes = payload.size.toLong(),
                    sha256 = expectedSha256,
                ),
                Media3CachedAudioVerifier.verify(activeRuntime.cache, spec),
            )

            val wrongHash = downloadSpec(
                expectedBytes = payload.size.toLong(),
                expectedSha256 = "0".repeat(64),
            )
            val mismatch = Media3CachedAudioVerifier.verify(activeRuntime.cache, wrongHash)
            assertTrue(mismatch is CachedAudioVerification.HashMismatch)
            mismatch as CachedAudioVerification.HashMismatch
            assertEquals("0".repeat(64), mismatch.expectedSha256)
            assertEquals(expectedSha256, mismatch.actualSha256)

            val wrongLength = downloadSpec(
                expectedBytes = payload.size.toLong() + 1,
                expectedSha256 = expectedSha256,
            )
            assertEquals(
                CachedAudioVerification.MissingBytes(
                    expectedBytes = payload.size.toLong() + 1,
                    cachedBytes = payload.size.toLong(),
                ),
                Media3CachedAudioVerifier.verify(activeRuntime.cache, wrongLength),
            )

            val unexpectedTail = downloadSpec(
                expectedBytes = payload.size.toLong() - 1,
                expectedSha256 = expectedSha256,
            )
            assertEquals(
                CachedAudioVerification.LengthMismatch(
                    expectedBytes = payload.size.toLong() - 1,
                    actualBytes = payload.size.toLong(),
                ),
                Media3CachedAudioVerifier.verify(activeRuntime.cache, unexpectedTail),
            )

            val mainThreadFailure = runCatching {
                onMainThread {
                    Media3CachedAudioVerifier.verify(activeRuntime.cache, spec)
                }
            }.exceptionOrNull()
            assertTrue(mainThreadFailure?.cause is IllegalStateException)
        } finally {
            server.close()
            runtime?.let { activeRuntime ->
                onMainThread {
                    activeRuntime.downloadManager.removeListener(listener)
                    context.stopService(Intent(context, HarnessAudioDownloadService::class.java))
                    HarnessAudioDownloadEnvironment.releaseForTest()
                }
                HarnessAudioDownloadEnvironment.cacheDirectory(context).deleteRecursively()
            }
        }
    }

    @Test
    fun corruptCompletedDownloadIsRemovedAndRepairedOnce() {
        val payload = ByteArray(256 * 1024) { index ->
            ((index * 17 + 29) and 0xff).toByte()
        }
        val corruptPayload = payload.copyOf().apply {
            this[size / 2] = (this[size / 2].toInt() xor 0xff).toByte()
        }
        val spec = downloadSpec(
            expectedBytes = payload.size.toLong(),
            expectedSha256 = payload.sha256(),
            artifactID = "lengyan.audio.integrity-repair-test",
            renditionID = "android.test.integrity-repair",
            fileName = "integrity-repair-test.m4a",
        )
        val server = SequencedPayloadServer(listOf(corruptPayload, payload))

        val result = runIntegrityScenario(server, spec)

        server.assertHealthy()
        assertEquals(2, server.bodyRequestCount())
        assertTrue(result.callbacksRanOnMainThread)
        assertTrue(result.coordinatorVerified)
        assertEquals(Download.STATE_COMPLETED, result.indexedDownloadState)
        assertEquals(payload.size.toLong(), result.cachedBytes)
        assertEquals(
            CachedAudioVerification.Verified(
                bytes = payload.size.toLong(),
                sha256 = payload.sha256(),
            ),
            result.cacheVerification,
        )
        assertEquals(2, result.events.size)
        val repairing = result.events[0] as AudioDownloadIntegrityEvent.Repairing
        assertEquals(1, repairing.repairAttempt)
        assertTrue(
            (repairing.issue as AudioDownloadIntegrityIssue.CacheVerification).result is
                CachedAudioVerification.HashMismatch,
        )
        val verified = result.events[1] as AudioDownloadIntegrityEvent.Verified
        assertEquals(1, verified.repairAttempts)
        assertEquals(payload.sha256(), verified.sha256)
    }

    @Test
    fun repeatedlyCorruptDownloadIsRemovedAndRejectedAfterOneRepair() {
        val payload = ByteArray(256 * 1024) { index ->
            ((index * 23 + 11) and 0xff).toByte()
        }
        val corruptPayload = payload.copyOf().apply {
            this[size / 3] = (this[size / 3].toInt() xor 0xff).toByte()
        }
        val spec = downloadSpec(
            expectedBytes = payload.size.toLong(),
            expectedSha256 = payload.sha256(),
            artifactID = "lengyan.audio.integrity-reject-test",
            renditionID = "android.test.integrity-reject",
            fileName = "integrity-reject-test.m4a",
        )
        val server = SequencedPayloadServer(listOf(corruptPayload))

        val result = runIntegrityScenario(server, spec)

        server.assertHealthy()
        assertEquals(2, server.bodyRequestCount())
        assertTrue(result.callbacksRanOnMainThread)
        assertFalse(result.coordinatorVerified)
        assertNull(result.indexedDownloadState)
        assertEquals(0L, result.cachedBytes)
        assertEquals(
            CachedAudioVerification.MissingBytes(
                expectedBytes = payload.size.toLong(),
                cachedBytes = 0,
            ),
            result.cacheVerification,
        )
        assertEquals(2, result.events.size)
        val repairing = result.events[0] as AudioDownloadIntegrityEvent.Repairing
        assertEquals(1, repairing.repairAttempt)
        val rejected = result.events[1] as AudioDownloadIntegrityEvent.Rejected
        assertEquals(1, rejected.repairAttempts)
        assertTrue(
            (rejected.issue as AudioDownloadIntegrityIssue.CacheVerification).result is
                CachedAudioVerification.HashMismatch,
        )
    }

    @Test
    fun removingVerifiedDownloadInvalidatesInMemoryTrust() {
        val payload = ByteArray(128 * 1024) { index ->
            ((index * 13 + 7) and 0xff).toByte()
        }
        val spec = downloadSpec(
            expectedBytes = payload.size.toLong(),
            expectedSha256 = payload.sha256(),
            artifactID = "lengyan.audio.integrity-removal-test",
            renditionID = "android.test.integrity-removal",
            fileName = "integrity-removal-test.m4a",
        )
        val server = SequencedPayloadServer(listOf(payload))

        val result = runIntegrityScenario(
            server = server,
            spec = spec,
            removeAfterTerminal = true,
        )

        server.assertHealthy()
        assertEquals(1, server.bodyRequestCount())
        assertTrue(result.callbacksRanOnMainThread)
        assertFalse(result.coordinatorVerified)
        assertNull(result.indexedDownloadState)
        assertEquals(0L, result.cachedBytes)
        assertEquals(
            CachedAudioVerification.MissingBytes(
                expectedBytes = payload.size.toLong(),
                cachedBytes = 0,
            ),
            result.cacheVerification,
        )
        assertEquals(1, result.events.size)
        val verified = result.events.single() as AudioDownloadIntegrityEvent.Verified
        assertEquals(0, verified.repairAttempts)
    }

    private fun runIntegrityScenario(
        server: SequencedPayloadServer,
        spec: Media3AudioDownloadSpec,
        removeAfterTerminal: Boolean = false,
    ): IntegrityScenarioResult {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val verificationExecutor = Executors.newSingleThreadExecutor()
        val terminalLatch = CountDownLatch(1)
        val callbacksRanOnMainThread = AtomicBoolean(true)
        val events = Collections.synchronizedList(
            mutableListOf<AudioDownloadIntegrityEvent>(),
        )
        var runtime: Media3AudioDownloadRuntime? = null
        var coordinator: Media3AudioDownloadIntegrityCoordinator? = null

        try {
            val upstreamFactory = ResolvingDataSource.Factory(
                DefaultHttpDataSource.Factory()
                    .setConnectTimeoutMs(5_000)
                    .setReadTimeoutMs(5_000),
            ) { dataSpec -> dataSpec.redirectTo(server.uri) }

            onMainThread {
                val installedRuntime = HarnessAudioDownloadEnvironment.installForTest(
                    context,
                    upstreamFactory,
                )
                runtime = installedRuntime
                coordinator = Media3AudioDownloadIntegrityCoordinator(
                    runtime = installedRuntime,
                    verificationExecutor = verificationExecutor,
                    repairEnqueuer = AudioDownloadRepairEnqueuer { request ->
                        installedRuntime.downloadManager.addDownload(request)
                    },
                    listener = AudioDownloadIntegrityListener { event ->
                        if (Looper.myLooper() != Looper.getMainLooper()) {
                            callbacksRanOnMainThread.set(false)
                        }
                        events += event
                        if (
                            event is AudioDownloadIntegrityEvent.Verified ||
                            event is AudioDownloadIntegrityEvent.Rejected
                        ) {
                            terminalLatch.countDown()
                        }
                    },
                ).also { integrityCoordinator ->
                    integrityCoordinator.track(spec)
                }
                installedRuntime.downloadManager.resumeDownloads()
                installedRuntime.downloadManager.addDownload(spec.toDownloadRequest())
            }

            val activeRuntime = checkNotNull(runtime)
            if (!terminalLatch.await(30, TimeUnit.SECONDS)) {
                val eventSnapshot = synchronized(events) { events.toList() }
                val indexedDownload = activeRuntime.downloadManager.downloadIndex
                    .getDownload(spec.requestID)
                val cachedBytes = activeRuntime.cache.getCachedSpans(spec.requestID)
                    .sumOf { span -> span.length }
                throw AssertionError(
                    "integrity coordinator did not reach a terminal state: " +
                        "requests=${server.bodyRequestCount()}, " +
                        "events=$eventSnapshot, " +
                        "downloadState=${indexedDownload?.state}, " +
                        "failureReason=${indexedDownload?.failureReason}, " +
                        "cachedBytes=$cachedBytes",
                )
            }
            if (removeAfterTerminal) {
                val removalLatch = CountDownLatch(1)
                val removalListener = object : DownloadManager.Listener {
                    override fun onDownloadRemoved(
                        downloadManager: DownloadManager,
                        download: Download,
                    ) {
                        if (download.request.id == spec.requestID) {
                            removalLatch.countDown()
                        }
                    }
                }
                try {
                    onMainThread {
                        activeRuntime.downloadManager.addListener(removalListener)
                        activeRuntime.downloadManager.removeDownload(spec.requestID)
                    }
                    assertTrue(
                        "verified download was not removed",
                        removalLatch.await(10, TimeUnit.SECONDS),
                    )
                } finally {
                    onMainThread {
                        activeRuntime.downloadManager.removeListener(removalListener)
                    }
                }
            }
            val eventSnapshot = synchronized(events) { events.toList() }
            return IntegrityScenarioResult(
                events = eventSnapshot,
                callbacksRanOnMainThread = callbacksRanOnMainThread.get(),
                coordinatorVerified = onMainThread {
                    checkNotNull(coordinator).isVerified(spec.requestID)
                },
                cacheVerification = Media3CachedAudioVerifier.verify(
                    activeRuntime.cache,
                    spec,
                ),
                cachedBytes = activeRuntime.cache.getCachedSpans(spec.requestID)
                    .sumOf { span -> span.length },
                indexedDownloadState = activeRuntime.downloadManager.downloadIndex
                    .getDownload(spec.requestID)
                    ?.state,
            )
        } finally {
            server.close()
            onMainThread {
                coordinator?.release()
                if (runtime != null) {
                    HarnessAudioDownloadEnvironment.releaseForTest()
                }
            }
            verificationExecutor.shutdownNow()
            verificationExecutor.awaitTermination(5, TimeUnit.SECONDS)
            if (runtime != null) {
                HarnessAudioDownloadEnvironment.cacheDirectory(context).deleteRecursively()
            }
        }
    }

    private fun downloadSpec(
        expectedBytes: Long,
        expectedSha256: String,
        artifactID: String = "lengyan.audio.range-test",
        renditionID: String = "android.test.range",
        fileName: String = "range-test.m4a",
    ): Media3AudioDownloadSpec = Media3AudioDownloadSpec.from(
        productID = "lengyan",
        asset = ResolvedAndroidAudioAsset(
            artifactID = artifactID,
            volumeID = "lengyan.v000001",
            titles = mapOf("zh-Hant" to "楞嚴經 第一卷"),
            rendition = AudioRendition(
                renditionID = renditionID,
                fileName = fileName,
                artifactKey = "audio/$fileName",
                mediaType = "audio/mp4",
                fileExtension = "m4a",
                codec = "mp4a.40.2",
                durationMilliseconds = 60_000,
                sampleRateHertz = 44_100,
                channels = 1,
                bytes = expectedBytes,
                sha256 = expectedSha256,
            ),
            uri = URI("https://media.example.invalid/audio/$fileName"),
        ),
    )

    private data class IntegrityScenarioResult(
        val events: List<AudioDownloadIntegrityEvent>,
        val callbacksRanOnMainThread: Boolean,
        val coordinatorVerified: Boolean,
        val cacheVerification: CachedAudioVerification,
        val cachedBytes: Long,
        val indexedDownloadState: Int?,
    )

    private fun grantNotificationPermission(context: Context) {
        if (context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val descriptor = InstrumentationRegistry.getInstrumentation()
            .uiAutomation
            .executeShellCommand(
                "pm grant ${context.packageName} ${Manifest.permission.POST_NOTIFICATIONS}",
            )
        ParcelFileDescriptor.AutoCloseInputStream(descriptor).bufferedReader().use { reader ->
            reader.readText()
        }
    }

    private fun <T> onMainThread(block: () -> T): T {
        val task = FutureTask(block)
        InstrumentationRegistry.getInstrumentation().runOnMainSync(task)
        return task.get(5, TimeUnit.SECONDS)
    }

    private fun DataSpec.redirectTo(uri: Uri): DataSpec =
        buildUpon().setUri(uri).build()

    private fun ByteArray.sha256(): String = MessageDigest.getInstance("SHA-256")
        .digest(this)
        .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}

private class InterruptingRangeServer(
    private val payload: ByteArray,
) : AutoCloseable {
    private val serverSocket = ServerSocket(
        0,
        16,
        InetAddress.getByName("127.0.0.1"),
    )
    private val executor = Executors.newSingleThreadExecutor()
    private val closed = AtomicBoolean(false)
    private val requestCount = AtomicInteger(0)
    private val failure = AtomicReference<Throwable?>()

    val uri: Uri = Uri.parse(
        "http://127.0.0.1:${serverSocket.localPort}/audio/range-test.m4a",
    )
    private val requestedRangeStarts: MutableList<Long> =
        Collections.synchronizedList(mutableListOf())

    init {
        executor.execute(::serve)
    }

    fun assertHealthy() {
        failure.get()?.let { throwable ->
            throw AssertionError("loopback Range server failed", throwable)
        }
    }

    fun hasNonZeroRangeRequest(): Boolean = synchronized(requestedRangeStarts) {
        requestedRangeStarts.any { it > 0L }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        serverSocket.close()
        executor.shutdownNow()
        executor.awaitTermination(5, TimeUnit.SECONDS)
    }

    private fun serve() {
        try {
            while (!closed.get()) {
                val socket = try {
                    serverSocket.accept()
                } catch (exception: SocketException) {
                    if (closed.get()) return
                    throw exception
                }
                handle(socket)
            }
        } catch (throwable: Throwable) {
            if (!closed.get()) failure.compareAndSet(null, throwable)
        }
    }

    private fun handle(socket: Socket) {
        socket.use { connection ->
            connection.soTimeout = 5_000
            val reader = connection.getInputStream()
                .bufferedReader(StandardCharsets.US_ASCII)
            val requestLine = reader.readLine() ?: return
            val headers = mutableMapOf<String, String>()
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isEmpty()) break
                val separator = line.indexOf(':')
                if (separator > 0) {
                    headers[line.substring(0, separator).lowercase()] =
                        line.substring(separator + 1).trim()
                }
            }

            val method = requestLine.substringBefore(' ')
            val rangeStart = headers["range"]?.parseRangeStart() ?: 0L
            requestedRangeStarts += rangeStart
            val currentRequest = requestCount.incrementAndGet()
            when {
                method == "HEAD" -> writeResponse(connection, 0, includeBody = false)
                currentRequest == 1 && rangeStart == 0L -> writeInterruptedResponse(connection)
                else -> writeResponse(connection, rangeStart.toInt(), includeBody = true)
            }
        }
    }

    private fun writeInterruptedResponse(socket: Socket) {
        val output = socket.getOutputStream()
        output.write(responseHeaders(200, payload.size, null))
        output.write(payload, 0, payload.size / 3)
        output.flush()
    }

    private fun writeResponse(
        socket: Socket,
        start: Int,
        includeBody: Boolean,
    ) {
        require(start in 0..payload.size)
        val remaining = payload.size - start
        val contentRange = if (start > 0) {
            "bytes $start-${payload.lastIndex}/${payload.size}"
        } else {
            null
        }
        val status = if (start > 0) 206 else 200
        val output = socket.getOutputStream()
        output.write(responseHeaders(status, remaining, contentRange))
        if (includeBody && remaining > 0) {
            output.write(payload, start, remaining)
        }
        output.flush()
    }

    private fun responseHeaders(
        status: Int,
        contentLength: Int,
        contentRange: String?,
    ): ByteArray {
        val reason = if (status == 206) "Partial Content" else "OK"
        return buildString {
            append("HTTP/1.1 $status $reason\r\n")
            append("Content-Type: audio/mp4\r\n")
            append("Content-Length: $contentLength\r\n")
            append("Accept-Ranges: bytes\r\n")
            contentRange?.let { append("Content-Range: $it\r\n") }
            append("Connection: close\r\n")
            append("\r\n")
        }.toByteArray(StandardCharsets.US_ASCII)
    }

    private fun String.parseRangeStart(): Long {
        require(startsWith("bytes="))
        return removePrefix("bytes=").substringBefore('-').toLong()
    }
}

private class SequencedPayloadServer(
    private val payloads: List<ByteArray>,
) : AutoCloseable {
    private val serverSocket = ServerSocket(
        0,
        16,
        InetAddress.getByName("127.0.0.1"),
    )
    private val executor = Executors.newSingleThreadExecutor()
    private val closed = AtomicBoolean(false)
    private val bodyRequests = AtomicInteger(0)
    private val failure = AtomicReference<Throwable?>()

    val uri: Uri = Uri.parse(
        "http://127.0.0.1:${serverSocket.localPort}/audio/integrity-test.m4a",
    )

    init {
        require(payloads.isNotEmpty()) { "integrity server requires a payload" }
        require(payloads.all { it.size == payloads.first().size }) {
            "integrity server payloads must have the same length"
        }
        executor.execute(::serve)
    }

    fun bodyRequestCount(): Int = bodyRequests.get()

    fun assertHealthy() {
        failure.get()?.let { throwable ->
            throw AssertionError("loopback integrity server failed", throwable)
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        serverSocket.close()
        executor.shutdownNow()
        executor.awaitTermination(5, TimeUnit.SECONDS)
    }

    private fun serve() {
        try {
            while (!closed.get()) {
                val socket = try {
                    serverSocket.accept()
                } catch (exception: SocketException) {
                    if (closed.get()) return
                    throw exception
                }
                handle(socket)
            }
        } catch (throwable: Throwable) {
            if (!closed.get()) failure.compareAndSet(null, throwable)
        }
    }

    private fun handle(socket: Socket) {
        socket.use { connection ->
            connection.soTimeout = 5_000
            val reader = connection.getInputStream()
                .bufferedReader(StandardCharsets.US_ASCII)
            val requestLine = reader.readLine() ?: return
            val headers = mutableMapOf<String, String>()
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isEmpty()) break
                val separator = line.indexOf(':')
                if (separator > 0) {
                    headers[line.substring(0, separator).lowercase()] =
                        line.substring(separator + 1).trim()
                }
            }

            val method = requestLine.substringBefore(' ')
            val rangeStart = headers["range"]?.parseRangeStart() ?: 0L
            val payload = if (method == "HEAD") {
                payloads.first()
            } else {
                val bodyRequest = bodyRequests.getAndIncrement()
                payloads[bodyRequest.coerceAtMost(payloads.lastIndex)]
            }
            writeResponse(
                socket = connection,
                payload = payload,
                start = rangeStart.toInt(),
                includeBody = method != "HEAD",
            )
        }
    }

    private fun writeResponse(
        socket: Socket,
        payload: ByteArray,
        start: Int,
        includeBody: Boolean,
    ) {
        require(start in 0..payload.size)
        val remaining = payload.size - start
        val contentRange = if (start > 0) {
            "bytes $start-${payload.lastIndex}/${payload.size}"
        } else {
            null
        }
        val status = if (start > 0) 206 else 200
        val reason = if (status == 206) "Partial Content" else "OK"
        val headers = buildString {
            append("HTTP/1.1 $status $reason\r\n")
            append("Content-Type: audio/mp4\r\n")
            append("Content-Length: $remaining\r\n")
            append("Accept-Ranges: bytes\r\n")
            contentRange?.let { append("Content-Range: $it\r\n") }
            append("Connection: close\r\n")
            append("\r\n")
        }.toByteArray(StandardCharsets.US_ASCII)
        socket.getOutputStream().run {
            write(headers)
            if (includeBody && remaining > 0) {
                write(payload, start, remaining)
            }
            flush()
        }
    }

    private fun String.parseRangeStart(): Long {
        require(startsWith("bytes="))
        return removePrefix("bytes=").substringBefore('-').toLong()
    }
}
