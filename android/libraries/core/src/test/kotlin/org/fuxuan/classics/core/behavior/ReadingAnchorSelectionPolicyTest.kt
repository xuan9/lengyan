package org.fuxuan.classics.core.behavior

import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingAnchorSelectionPolicyTest {
    private val requested = ParagraphTextAnchor("book.p.requested", 12)
    private val persisted = ParagraphTextAnchor("book.p.persisted", 34)

    @Test
    fun explicitNavigationWinsOverOlderProgressInTheSameVolume() {
        assertEquals(
            ReadingAnchorSelection(requested, ReadingAnchorOrigin.REQUESTED),
            ReadingAnchorSelectionPolicy.select(
                destinationVolumeID = "book.v000001",
                requestedAnchor = requested,
                requestedAtEpochMilliseconds = 200,
                persistedVolumeID = "book.v000001",
                persistedAnchor = persisted,
                persistedAtEpochMilliseconds = 100,
            ),
        )
    }

    @Test
    fun newerProgressWinsWhenAReaderRouteIsRestoredAfterProcessDeath() {
        assertEquals(
            ReadingAnchorSelection(persisted, ReadingAnchorOrigin.PERSISTED),
            ReadingAnchorSelectionPolicy.select(
                destinationVolumeID = "book.v000001",
                requestedAnchor = requested,
                requestedAtEpochMilliseconds = 100,
                persistedVolumeID = "book.v000001",
                persistedAnchor = persisted,
                persistedAtEpochMilliseconds = 200,
            ),
        )
    }

    @Test
    fun progressFromAnotherVolumeNeverOverridesTheRequestedDestination() {
        assertEquals(
            ReadingAnchorSelection(requested, ReadingAnchorOrigin.REQUESTED),
            ReadingAnchorSelectionPolicy.select(
                destinationVolumeID = "book.v000002",
                requestedAnchor = requested,
                requestedAtEpochMilliseconds = 100,
                persistedVolumeID = "book.v000001",
                persistedAnchor = persisted,
                persistedAtEpochMilliseconds = 200,
            ),
        )
    }

    @Test
    fun openingAResumeVolumeWithoutAnExplicitAnchorUsesPersistedProgress() {
        assertEquals(
            ReadingAnchorSelection(persisted, ReadingAnchorOrigin.PERSISTED),
            ReadingAnchorSelectionPolicy.select(
                destinationVolumeID = "book.v000001",
                requestedAnchor = null,
                requestedAtEpochMilliseconds = 0,
                persistedVolumeID = "book.v000001",
                persistedAnchor = persisted,
                persistedAtEpochMilliseconds = 200,
            ),
        )
    }
}
