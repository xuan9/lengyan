package org.fuxuan.classics.media

import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

@OptIn(UnstableApi::class)
internal class ContractMediaSessionCallback(
    private val applicationPackageName: String,
    private val catalog: Media3AudioCatalog,
) : MediaSession.Callback {
    override fun onConnect(
        session: MediaSession,
        controller: MediaSession.ControllerInfo,
    ): MediaSession.ConnectionResult {
        if (controller.packageName != applicationPackageName && !controller.isTrusted) {
            return MediaSession.ConnectionResult.reject()
        }
        return super.onConnect(session, controller)
    }

    override fun onAddMediaItems(
        mediaSession: MediaSession,
        controller: MediaSession.ControllerInfo,
        mediaItems: List<MediaItem>,
    ): ListenableFuture<List<MediaItem>> = Futures.immediateFuture(
        catalog.resolveRequests(mediaItems),
    )
}
