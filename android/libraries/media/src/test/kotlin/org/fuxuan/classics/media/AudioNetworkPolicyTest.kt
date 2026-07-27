package org.fuxuan.classics.media

import org.fuxuan.classics.core.persistence.AudioPreferences
import org.junit.Assert.assertEquals
import org.junit.Test

class AudioNetworkPolicyTest {
    @Test
    fun userPlaybackUsesAnyConnectedNetwork() {
        assertEquals(
            AudioNetworkDecision.Allowed,
            decision(
                purpose = AudioTransferPurpose.USER_PLAYBACK,
                isConnected = true,
                isMetered = true,
                providerAllowsPrefetch = false,
                preferences = AudioPreferences(
                    automaticNextVolumePrefetch = false,
                    unmeteredPrefetchOnly = true,
                ),
            ),
        )
    }

    @Test
    fun everyTransferIsBlockedWhileOffline() {
        assertEquals(
            AudioNetworkDecision.Blocked(AudioNetworkBlockReason.OFFLINE),
            decision(
                purpose = AudioTransferPurpose.USER_PLAYBACK,
                isConnected = false,
            ),
        )
        assertEquals(
            AudioNetworkDecision.Blocked(AudioNetworkBlockReason.OFFLINE),
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = false,
            ),
        )
    }

    @Test
    fun automaticPrefetchDefaultsToAnUnmeteredNetwork() {
        assertEquals(
            AudioNetworkDecision.Blocked(AudioNetworkBlockReason.METERED_NETWORK),
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = true,
                isMetered = true,
            ),
        )
        assertEquals(
            AudioNetworkDecision.Allowed,
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = true,
                isMetered = false,
            ),
        )
    }

    @Test
    fun providerAndUserPreferencesCanDisableAutomaticPrefetch() {
        assertEquals(
            AudioNetworkDecision.Blocked(
                AudioNetworkBlockReason.PROVIDER_DISALLOWS_PREFETCH,
            ),
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = true,
                providerAllowsPrefetch = false,
            ),
        )
        assertEquals(
            AudioNetworkDecision.Blocked(
                AudioNetworkBlockReason.AUTOMATIC_PREFETCH_DISABLED,
            ),
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = true,
                preferences = AudioPreferences(automaticNextVolumePrefetch = false),
            ),
        )
    }

    @Test
    fun explicitPreferenceAllowsPrefetchOnMeteredNetworks() {
        assertEquals(
            AudioNetworkDecision.Allowed,
            decision(
                purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                isConnected = true,
                isMetered = true,
                preferences = AudioPreferences(unmeteredPrefetchOnly = false),
            ),
        )
    }

    private fun decision(
        purpose: AudioTransferPurpose,
        isConnected: Boolean,
        isMetered: Boolean = false,
        providerAllowsPrefetch: Boolean = true,
        preferences: AudioPreferences = AudioPreferences(),
    ) = AudioNetworkPolicy.decide(
        purpose = purpose,
        isConnected = isConnected,
        isMetered = isMetered,
        providerAllowsPrefetch = providerAllowsPrefetch,
        preferences = preferences,
    )
}
