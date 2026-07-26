package org.fuxuan.classics.core.behavior

enum class ReadingAnchorOrigin {
    REQUESTED,
    PERSISTED,
    VOLUME_START,
}

data class ReadingAnchorSelection(
    val anchor: ParagraphTextAnchor?,
    val origin: ReadingAnchorOrigin,
)

object ReadingAnchorSelectionPolicy {
    fun select(
        destinationVolumeID: String,
        requestedAnchor: ParagraphTextAnchor?,
        requestedAtEpochMilliseconds: Long,
        persistedVolumeID: String?,
        persistedAnchor: ParagraphTextAnchor?,
        persistedAtEpochMilliseconds: Long?,
    ): ReadingAnchorSelection {
        require(destinationVolumeID.isNotBlank()) { "destination volumeID must not be blank" }
        require(requestedAtEpochMilliseconds >= 0) { "requested timestamp must not be negative" }
        require(persistedAtEpochMilliseconds == null || persistedAtEpochMilliseconds >= 0) {
            "persisted timestamp must not be negative"
        }

        val persistedIsEligible =
            persistedVolumeID == destinationVolumeID && persistedAnchor != null
        val requestedIsNewest = requestedAnchor != null &&
            (!persistedIsEligible ||
                persistedAtEpochMilliseconds == null ||
                requestedAtEpochMilliseconds >= persistedAtEpochMilliseconds)
        return when {
            requestedIsNewest -> ReadingAnchorSelection(
                anchor = requestedAnchor,
                origin = ReadingAnchorOrigin.REQUESTED,
            )
            persistedIsEligible -> ReadingAnchorSelection(
                anchor = persistedAnchor,
                origin = ReadingAnchorOrigin.PERSISTED,
            )
            else -> ReadingAnchorSelection(
                anchor = null,
                origin = ReadingAnchorOrigin.VOLUME_START,
            )
        }
    }
}
