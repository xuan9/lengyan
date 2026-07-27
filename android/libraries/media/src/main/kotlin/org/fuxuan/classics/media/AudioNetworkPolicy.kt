package org.fuxuan.classics.media

import org.fuxuan.classics.core.persistence.AudioPreferences

enum class AudioTransferPurpose {
    USER_PLAYBACK,
    AUTOMATIC_NEXT_PREFETCH,
}

sealed interface AudioNetworkDecision {
    data object Allowed : AudioNetworkDecision

    data class Blocked(
        val reason: AudioNetworkBlockReason,
    ) : AudioNetworkDecision
}

enum class AudioNetworkBlockReason {
    OFFLINE,
    PROVIDER_DISALLOWS_PREFETCH,
    AUTOMATIC_PREFETCH_DISABLED,
    METERED_NETWORK,
}

object AudioNetworkPolicy {
    fun decide(
        purpose: AudioTransferPurpose,
        isConnected: Boolean,
        isMetered: Boolean,
        providerAllowsPrefetch: Boolean,
        preferences: AudioPreferences,
    ): AudioNetworkDecision {
        if (!isConnected) {
            return AudioNetworkDecision.Blocked(AudioNetworkBlockReason.OFFLINE)
        }
        if (purpose == AudioTransferPurpose.USER_PLAYBACK) {
            return AudioNetworkDecision.Allowed
        }
        if (!providerAllowsPrefetch) {
            return AudioNetworkDecision.Blocked(
                AudioNetworkBlockReason.PROVIDER_DISALLOWS_PREFETCH,
            )
        }
        if (!preferences.automaticNextVolumePrefetch) {
            return AudioNetworkDecision.Blocked(
                AudioNetworkBlockReason.AUTOMATIC_PREFETCH_DISABLED,
            )
        }
        if (preferences.unmeteredPrefetchOnly && isMetered) {
            return AudioNetworkDecision.Blocked(AudioNetworkBlockReason.METERED_NETWORK)
        }
        return AudioNetworkDecision.Allowed
    }
}
