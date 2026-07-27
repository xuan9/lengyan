package org.fuxuan.classics.media.harness

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
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
import org.fuxuan.classics.media.CachedAudioVerification
import org.fuxuan.classics.media.Media3AudioDownloadRuntime
import org.fuxuan.classics.media.Media3AudioDownloadSpec
import org.fuxuan.classics.media.Media3CachedAudioVerifier
import org.fuxuan.classics.media.ResolvedAndroidAudioAsset
import org.junit.Assert.assertEquals
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

    private fun downloadSpec(
        expectedBytes: Long,
        expectedSha256: String,
    ): Media3AudioDownloadSpec = Media3AudioDownloadSpec.from(
        productID = "lengyan",
        asset = ResolvedAndroidAudioAsset(
            artifactID = "lengyan.audio.range-test",
            volumeID = "lengyan.v000001",
            titles = mapOf("zh-Hant" to "楞嚴經 第一卷"),
            rendition = AudioRendition(
                renditionID = "android.test.range",
                fileName = "range-test.m4a",
                artifactKey = "audio/range-test.m4a",
                mediaType = "audio/mp4",
                fileExtension = "m4a",
                codec = "mp4a.40.2",
                durationMilliseconds = 60_000,
                sampleRateHertz = 44_100,
                channels = 1,
                bytes = expectedBytes,
                sha256 = expectedSha256,
            ),
            uri = URI("https://media.example.invalid/audio/range-test.m4a"),
        ),
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
