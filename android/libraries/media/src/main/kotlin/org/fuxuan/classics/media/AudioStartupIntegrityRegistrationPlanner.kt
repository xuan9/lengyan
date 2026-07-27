package org.fuxuan.classics.media

internal data class AudioStartupIntegrityRegistration(
    val spec: Media3AudioDownloadSpec,
    val transfer: ReconciledAudioStartupTransfer,
)

internal data class AudioStartupIntegrityRegistrationPlan(
    val registrations: List<AudioStartupIntegrityRegistration>,
    val completedRequestIDs: List<String>,
)

internal object AudioStartupIntegrityRegistrationPlanner {
    fun plan(
        catalog: List<Media3AudioDownloadSpec>,
        transfers: List<ReconciledAudioStartupTransfer>,
    ): AudioStartupIntegrityRegistrationPlan {
        require(catalog.isNotEmpty()) { "startup integrity catalog must not be empty" }
        val catalogByRequestID = catalog.associateBy(Media3AudioDownloadSpec::requestID)
        require(catalogByRequestID.size == catalog.size) {
            "startup integrity catalog request IDs must be unique"
        }
        require(transfers.map(ReconciledAudioStartupTransfer::requestID).distinct().size ==
            transfers.size) {
            "startup integrity transfer request IDs must be unique"
        }

        val registrations = transfers.map { transfer ->
            require(
                transfer.state != AudioStartupTransferState.REMOVING &&
                    transfer.state != AudioStartupTransferState.RESTARTING,
            ) {
                "transitional startup transfer cannot be registered for integrity"
            }
            val spec = requireNotNull(catalogByRequestID[transfer.requestID]) {
                "startup integrity transfer is missing from the catalog"
            }
            AudioStartupIntegrityRegistration(spec, transfer)
        }
        return AudioStartupIntegrityRegistrationPlan(
            registrations = registrations,
            completedRequestIDs = registrations
                .filter { registration ->
                    registration.transfer.state == AudioStartupTransferState.COMPLETED
                }
                .map { registration -> registration.spec.requestID }
                .sorted(),
        )
    }
}
