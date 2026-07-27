package org.fuxuan.classics.media

import org.fuxuan.classics.core.persistence.AudioPreferences

data class AudioNetworkState(
    val isConnected: Boolean,
    val isMetered: Boolean,
)

data class AudioPrefetchPolicyContext(
    val network: AudioNetworkState,
    val providerAllowsPrefetch: Boolean,
    val preferences: AudioPreferences,
)

enum class AudioTransferRequestRejectionReason {
    CONFLICTING_REQUEST_CONTRACT,
    UNSUPPORTED_REQUEST_METADATA,
}

sealed interface AudioTransferRequestResult {
    val requestID: String

    data class Accepted(
        override val requestID: String,
        val requestedPurpose: AudioTransferPurpose,
        val effectivePurpose: AudioTransferPurpose,
        val networkDecision: AudioNetworkDecision,
        val reusedExistingTask: Boolean,
        val promotedExistingPrefetch: Boolean,
        val effectiveStopReason: Int,
    ) : AudioTransferRequestResult

    data class NotScheduled(
        override val requestID: String,
        val reason: AudioNetworkBlockReason,
    ) : AudioTransferRequestResult

    data class Rejected(
        override val requestID: String,
        val reason: AudioTransferRequestRejectionReason,
    ) : AudioTransferRequestResult
}

data class AudioPrefetchPolicyUpdateResult(
    val stoppedRequestIDs: List<String>,
    val resumedRequestIDs: List<String>,
    val externallyStoppedRequestIDs: List<String>,
)

/** A stable application-owned reason. Media3 reserves zero to mean "not stopped". */
const val AUTOMATIC_PREFETCH_POLICY_STOP_REASON: Int = 0x43504631

internal data class AudioTransferRequestContract(
    val requestID: String,
    val uri: String,
    val mediaType: String?,
    val customCacheKey: String?,
    val isFullProgressiveAsset: Boolean,
) {
    init {
        require(requestID.isNotBlank()) { "audio transfer request ID must not be blank" }
        require(uri.isNotBlank()) { "audio transfer URI must not be blank" }
    }
}

internal enum class AudioTransferRequestOwnership {
    MANAGED_AUTOMATIC_PREFETCH,
    MANAGED_USER_PLAYBACK,
    LEGACY_USER_PLAYBACK,
    UNSUPPORTED_METADATA,
}

internal data class QueuedAudioTransfer(
    val contract: AudioTransferRequestContract,
    val ownership: AudioTransferRequestOwnership,
    val stopReason: Int,
)

internal interface AudioTransferQueue {
    fun currentTransfers(): List<QueuedAudioTransfer>

    fun add(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        initialStopReason: Int,
    )

    fun replacePurpose(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        preservedStopReason: Int,
    )

    fun setStopReason(requestID: String, stopReason: Int)
}

internal class AudioTransferQueueCoordinator(
    private val queue: AudioTransferQueue,
) {
    private val knownTransfers = mutableMapOf<String, QueuedAudioTransfer>()
    private val stickyUserPlaybackSpecs = mutableMapOf<String, Media3AudioDownloadSpec>()
    private var latestPolicyContext: AudioPrefetchPolicyContext? = null

    fun request(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        policyContext: AudioPrefetchPolicyContext,
    ): AudioTransferRequestResult {
        latestPolicyContext = policyContext
        synchronizeCurrentTransfers()

        val decision = policyContext.decision(purpose)
        val expectedContract = spec.toTransferRequestContract()
        val existing = knownTransfers[spec.requestID]
        if (existing != null) {
            if (existing.contract != expectedContract) {
                reconcileKnownPrefetches(policyContext, excludingRequestID = spec.requestID)
                return AudioTransferRequestResult.Rejected(
                    requestID = spec.requestID,
                    reason = AudioTransferRequestRejectionReason.CONFLICTING_REQUEST_CONTRACT,
                )
            }
            if (existing.ownership == AudioTransferRequestOwnership.UNSUPPORTED_METADATA) {
                reconcileKnownPrefetches(policyContext, excludingRequestID = spec.requestID)
                return AudioTransferRequestResult.Rejected(
                    requestID = spec.requestID,
                    reason = AudioTransferRequestRejectionReason.UNSUPPORTED_REQUEST_METADATA,
                )
            }
            val result = reuseExistingTransfer(existing, spec, purpose, decision)
            reconcileKnownPrefetches(policyContext, excludingRequestID = spec.requestID)
            return result
        }

        if (
            purpose == AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH &&
            decision is AudioNetworkDecision.Blocked &&
            decision.reason.isConfigurationBlock
        ) {
            reconcileKnownPrefetches(policyContext)
            return AudioTransferRequestResult.NotScheduled(
                requestID = spec.requestID,
                reason = decision.reason,
            )
        }

        val initialStopReason = if (
            purpose == AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH &&
            decision is AudioNetworkDecision.Blocked
        ) {
            AUTOMATIC_PREFETCH_POLICY_STOP_REASON
        } else {
            MEDIA3_STOP_REASON_NONE
        }
        queue.add(spec, purpose, initialStopReason)
        if (purpose == AudioTransferPurpose.USER_PLAYBACK) {
            stickyUserPlaybackSpecs[spec.requestID] = spec
        }
        knownTransfers[spec.requestID] = QueuedAudioTransfer(
            contract = expectedContract,
            ownership = purpose.toManagedOwnership(),
            stopReason = initialStopReason,
        )
        reconcileKnownPrefetches(policyContext, excludingRequestID = spec.requestID)

        return AudioTransferRequestResult.Accepted(
            requestID = spec.requestID,
            requestedPurpose = purpose,
            effectivePurpose = purpose,
            networkDecision = decision,
            reusedExistingTask = false,
            promotedExistingPrefetch = false,
            effectiveStopReason = initialStopReason,
        )
    }

    fun updatePolicy(
        policyContext: AudioPrefetchPolicyContext,
    ): AudioPrefetchPolicyUpdateResult {
        latestPolicyContext = policyContext
        synchronizeCurrentTransfers()
        return reconcileKnownPrefetches(policyContext)
    }

    fun onTransferChanged(transfer: QueuedAudioTransfer) {
        recordCurrentTransfer(transfer)
        latestPolicyContext?.let { policyContext ->
            reconcileKnownPrefetches(policyContext)
        }
    }

    fun onTransferUnavailable(requestID: String) {
        knownTransfers.remove(requestID)
        stickyUserPlaybackSpecs.remove(requestID)
    }

    fun onQueueInitialized() {
        synchronizeCurrentTransfers()
        latestPolicyContext?.let { policyContext ->
            reconcileKnownPrefetches(policyContext)
        }
    }

    private fun reuseExistingTransfer(
        existing: QueuedAudioTransfer,
        spec: Media3AudioDownloadSpec,
        requestedPurpose: AudioTransferPurpose,
        decision: AudioNetworkDecision,
    ): AudioTransferRequestResult.Accepted {
        val existingPurpose = existing.ownership.effectivePurpose
        if (
            requestedPurpose == AudioTransferPurpose.USER_PLAYBACK &&
            existing.ownership == AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH
        ) {
            stickyUserPlaybackSpecs[spec.requestID] = spec
            val preservedStopReason = existing.stopReason.takeUnless {
                it == AUTOMATIC_PREFETCH_POLICY_STOP_REASON
            } ?: MEDIA3_STOP_REASON_NONE
            queue.replacePurpose(
                spec = spec,
                purpose = AudioTransferPurpose.USER_PLAYBACK,
                preservedStopReason = preservedStopReason,
            )
            knownTransfers[spec.requestID] = existing.copy(
                ownership = AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
                stopReason = preservedStopReason,
            )
            return AudioTransferRequestResult.Accepted(
                requestID = spec.requestID,
                requestedPurpose = requestedPurpose,
                effectivePurpose = AudioTransferPurpose.USER_PLAYBACK,
                networkDecision = decision,
                reusedExistingTask = true,
                promotedExistingPrefetch = true,
                effectiveStopReason = preservedStopReason,
            )
        }

        if (existingPurpose == AudioTransferPurpose.USER_PLAYBACK) {
            if (requestedPurpose == AudioTransferPurpose.USER_PLAYBACK) {
                stickyUserPlaybackSpecs[spec.requestID] = spec
            }
            val effectiveStopReason = clearOwnedStopReason(existing)
            return AudioTransferRequestResult.Accepted(
                requestID = spec.requestID,
                requestedPurpose = requestedPurpose,
                effectivePurpose = AudioTransferPurpose.USER_PLAYBACK,
                networkDecision = decision,
                reusedExistingTask = true,
                promotedExistingPrefetch = false,
                effectiveStopReason = effectiveStopReason,
            )
        }

        val updated = applyPrefetchDecision(existing, decision)
        return AudioTransferRequestResult.Accepted(
            requestID = spec.requestID,
            requestedPurpose = requestedPurpose,
            effectivePurpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            networkDecision = decision,
            reusedExistingTask = true,
            promotedExistingPrefetch = false,
            effectiveStopReason = updated.stopReason,
        )
    }

    private fun clearOwnedStopReason(existing: QueuedAudioTransfer): Int {
        if (existing.stopReason != AUTOMATIC_PREFETCH_POLICY_STOP_REASON) {
            return existing.stopReason
        }
        queue.setStopReason(existing.contract.requestID, MEDIA3_STOP_REASON_NONE)
        knownTransfers[existing.contract.requestID] = existing.copy(
            stopReason = MEDIA3_STOP_REASON_NONE,
        )
        return MEDIA3_STOP_REASON_NONE
    }

    private fun reconcileKnownPrefetches(
        policyContext: AudioPrefetchPolicyContext,
        excludingRequestID: String? = null,
    ): AudioPrefetchPolicyUpdateResult {
        val stopped = mutableListOf<String>()
        val resumed = mutableListOf<String>()
        val externallyStopped = mutableListOf<String>()
        val decision = policyContext.decision(AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH)

        knownTransfers.values
            .filter { transfer ->
                transfer.contract.requestID != excludingRequestID &&
                    transfer.ownership ==
                    AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH
            }
            .sortedBy { it.contract.requestID }
            .forEach { transfer ->
                val updated = applyPrefetchDecision(transfer, decision)
                when {
                    updated.stopReason == transfer.stopReason &&
                        transfer.stopReason !in setOf(
                            MEDIA3_STOP_REASON_NONE,
                            AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
                        ) -> externallyStopped += transfer.contract.requestID
                    transfer.stopReason == MEDIA3_STOP_REASON_NONE &&
                        updated.stopReason == AUTOMATIC_PREFETCH_POLICY_STOP_REASON ->
                        stopped += transfer.contract.requestID
                    transfer.stopReason == AUTOMATIC_PREFETCH_POLICY_STOP_REASON &&
                        updated.stopReason == MEDIA3_STOP_REASON_NONE ->
                        resumed += transfer.contract.requestID
                }
            }

        return AudioPrefetchPolicyUpdateResult(
            stoppedRequestIDs = stopped,
            resumedRequestIDs = resumed,
            externallyStoppedRequestIDs = externallyStopped,
        )
    }

    private fun applyPrefetchDecision(
        transfer: QueuedAudioTransfer,
        decision: AudioNetworkDecision,
    ): QueuedAudioTransfer {
        val desiredStopReason = when (decision) {
            AudioNetworkDecision.Allowed -> MEDIA3_STOP_REASON_NONE
            is AudioNetworkDecision.Blocked -> AUTOMATIC_PREFETCH_POLICY_STOP_REASON
        }
        val currentStopReason = transfer.stopReason
        val coordinatorOwnsCurrentReason = currentStopReason in setOf(
            MEDIA3_STOP_REASON_NONE,
            AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
        )
        if (!coordinatorOwnsCurrentReason || currentStopReason == desiredStopReason) {
            return transfer
        }

        queue.setStopReason(transfer.contract.requestID, desiredStopReason)
        return transfer.copy(stopReason = desiredStopReason).also { updated ->
            knownTransfers[updated.contract.requestID] = updated
        }
    }

    private fun synchronizeCurrentTransfers() {
        queue.currentTransfers().forEach { transfer ->
            recordCurrentTransfer(transfer)
        }
    }

    private fun recordCurrentTransfer(incoming: QueuedAudioTransfer) {
        val requestID = incoming.contract.requestID
        val stickySpec = stickyUserPlaybackSpecs[requestID]
        if (stickySpec == null || incoming.contract != stickySpec.toTransferRequestContract()) {
            knownTransfers[requestID] = incoming
            return
        }

        val preservedStopReason = incoming.stopReason.takeUnless {
            it == AUTOMATIC_PREFETCH_POLICY_STOP_REASON
        } ?: MEDIA3_STOP_REASON_NONE
        if (incoming.ownership != AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK) {
            queue.replacePurpose(
                spec = stickySpec,
                purpose = AudioTransferPurpose.USER_PLAYBACK,
                preservedStopReason = preservedStopReason,
            )
        } else if (incoming.stopReason == AUTOMATIC_PREFETCH_POLICY_STOP_REASON) {
            queue.setStopReason(requestID, MEDIA3_STOP_REASON_NONE)
        }
        knownTransfers[requestID] = incoming.copy(
            ownership = AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            stopReason = preservedStopReason,
        )
    }

    private val AudioNetworkBlockReason.isConfigurationBlock: Boolean
        get() = this == AudioNetworkBlockReason.PROVIDER_DISALLOWS_PREFETCH ||
            this == AudioNetworkBlockReason.AUTOMATIC_PREFETCH_DISABLED

    private val AudioTransferRequestOwnership.effectivePurpose: AudioTransferPurpose
        get() = when (this) {
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH ->
                AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK,
            AudioTransferRequestOwnership.UNSUPPORTED_METADATA ->
                AudioTransferPurpose.USER_PLAYBACK
        }

    private fun AudioTransferPurpose.toManagedOwnership(): AudioTransferRequestOwnership =
        when (this) {
            AudioTransferPurpose.USER_PLAYBACK ->
                AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK
            AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH ->
                AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH
        }

    private fun AudioPrefetchPolicyContext.decision(
        purpose: AudioTransferPurpose,
    ): AudioNetworkDecision = AudioNetworkPolicy.decide(
        purpose = purpose,
        isConnected = network.isConnected,
        isMetered = network.isMetered,
        providerAllowsPrefetch = providerAllowsPrefetch,
        preferences = preferences,
    )

    private companion object {
        const val MEDIA3_STOP_REASON_NONE = 0
    }
}
