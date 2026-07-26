package org.fuxuan.classics.core.behavior

sealed interface AudioStartDecision {
    data object Beginning : AudioStartDecision

    data class Resume(val seekTimeSeconds: Double) : AudioStartDecision
}

object AudioPlaybackResumePolicy {
    fun startDecision(
        savedArtifactID: String?,
        requestedArtifactID: String,
        savedTimeSeconds: Double,
    ): AudioStartDecision {
        if (
            savedArtifactID != requestedArtifactID ||
            !savedTimeSeconds.isFinite() ||
            savedTimeSeconds <= 0
        ) {
            return AudioStartDecision.Beginning
        }
        return AudioStartDecision.Resume(savedTimeSeconds)
    }
}
