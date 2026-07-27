package org.fuxuan.classics.media.harness

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class MediaSessionContractTest {
    @Test
    fun sessionResolvesOnlyKnownContractAssets() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val token = SessionToken(
            context,
            ComponentName(context, HarnessMediaSessionService::class.java),
        )
        val controllerFuture = MediaController.Builder(context, token).buildAsync()
        val controller = controllerFuture.get(10, TimeUnit.SECONDS)

        try {
            onControllerThread {
                controller.setMediaItem(
                    MediaItem.Builder()
                        .setMediaId(HarnessMediaSessionService.KNOWN_ARTIFACT_ID)
                        .setUri("https://attacker.invalid/replacement.m4a")
                        .setMediaMetadata(
                            MediaMetadata.Builder()
                                .setTitle("untrusted title")
                                .build(),
                        )
                        .build(),
                )
            }

            awaitCondition("known media item was not resolved") {
                onControllerThread {
                    controller.currentMediaItem?.mediaId ==
                        HarnessMediaSessionService.KNOWN_ARTIFACT_ID
                }
            }
            val resolved = onControllerThread { controller.currentMediaItem }
            assertEquals(
                HarnessMediaSessionService.TRUSTED_URI,
                resolved?.localConfiguration?.uri.toString(),
            )
            assertEquals("audio/mp4", resolved?.localConfiguration?.mimeType)
            assertEquals(
                HarnessMediaSessionService.TRUSTED_TITLE,
                resolved?.mediaMetadata?.title.toString(),
            )

            onControllerThread {
                controller.setMediaItems(
                    listOf(
                        MediaItem.Builder()
                            .setMediaId(HarnessMediaSessionService.KNOWN_ARTIFACT_ID)
                            .build(),
                        MediaItem.Builder()
                            .setMediaId("unknown.audio")
                            .setUri("https://attacker.invalid/unknown.m4a")
                            .build(),
                    ),
                )
            }

            awaitCondition("a mixed known/unknown queue was not rejected") {
                onControllerThread { controller.mediaItemCount == 0 }
            }
            assertNull(onControllerThread { controller.currentMediaItem })
        } finally {
            onControllerThread(controller::release)
            context.stopService(Intent(context, HarnessMediaSessionService::class.java))
        }
    }

    private fun awaitCondition(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 5_000
        while (SystemClock.elapsedRealtime() < deadline) {
            if (condition()) return
            SystemClock.sleep(25)
        }
        check(condition()) { message }
    }

    private fun <T> onControllerThread(block: () -> T): T {
        val task = FutureTask(block)
        InstrumentationRegistry.getInstrumentation().runOnMainSync(task)
        return task.get(5, TimeUnit.SECONDS)
    }
}
