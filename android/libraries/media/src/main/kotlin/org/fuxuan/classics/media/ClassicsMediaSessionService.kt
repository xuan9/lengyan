package org.fuxuan.classics.media

import android.app.PendingIntent
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

abstract class ClassicsMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null

    protected abstract fun createAudioCatalog(): Media3AudioCatalog

    protected open fun createPlayer(): Player = ExoPlayer.Builder(this).build()

    protected open fun createSessionActivity(): PendingIntent? = null

    final override fun onCreate() {
        super.onCreate()
        check(mediaSession == null) { "media session service was created twice" }

        val player = createPlayer()
        try {
            check(player.applicationLooper == mainLooper) {
                "media session service player must use the main looper"
            }
            val builder = MediaSession.Builder(this, player)
                .setCallback(
                    ContractMediaSessionCallback(
                        applicationPackageName = packageName,
                        catalog = createAudioCatalog(),
                    ),
                )
            createSessionActivity()?.let(builder::setSessionActivity)
            mediaSession = builder.build()
        } catch (exception: Exception) {
            player.release()
            throw exception
        }
    }

    final override fun onGetSession(
        controllerInfo: MediaSession.ControllerInfo,
    ): MediaSession? = mediaSession

    final override fun onDestroy() {
        mediaSession?.let { session ->
            session.player.release()
            session.release()
        }
        mediaSession = null
        super.onDestroy()
    }
}
