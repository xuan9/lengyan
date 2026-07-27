package org.fuxuan.classics.core.content

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SourceManifestTest {
    @Test
    fun contractEnumsRejectUnknownValues() {
        assertEquals(
            DocumentedSourceRole.COLLATION_REFERENCE,
            DocumentedSourceRole.fromContract("collation-reference"),
        )
        assertThrows(IllegalStateException::class.java) {
            SourceRightsStatus.fromContract("assumed-open")
        }
    }

    @Test
    fun eligibleManifestRequiresAllHumanApprovals() {
        assertThrows(IllegalArgumentException::class.java) {
            SourceManifest(
                schemaVersion = 1,
                productID = "fixture",
                bookID = "fixture",
                editionID = "fixture-v1",
                reviewStatus = SourceReviewStatus.APPROVED,
                releaseEligibility = SourceReleaseEligibility.ELIGIBLE,
                approvals = SourceApprovals(
                    textAccuracy = pendingApproval(),
                    rights = pendingApproval(),
                ),
                sources = listOf(fixtureSource()),
            )
        }
    }

    @Test
    fun approvalTimeRejectsSchemaInvalidFractionalSeconds() {
        assertThrows(IllegalArgumentException::class.java) {
            SourceApproval(
                status = SourceApprovalStatus.APPROVED,
                reviewedBy = "reviewer",
                reviewedAt = "2026-07-27T12:00:00.123Z",
                notes = null,
            )
        }
    }

    @Test
    fun documentedSourceIDMustStartWithALetter() {
        assertThrows(IllegalArgumentException::class.java) {
            fixtureSource().copy(sourceID = "1fixture.source")
        }
    }

    private fun pendingApproval() = SourceApproval(
        status = SourceApprovalStatus.PENDING,
        reviewedBy = null,
        reviewedAt = null,
        notes = "Pending review",
    )

    private fun fixtureSource() = DocumentedSource(
        sourceID = "fixture.source",
        role = DocumentedSourceRole.CANONICAL_INPUT,
        format = DocumentedSourceFormat.PLAIN_TEXT,
        title = "Fixture source",
        institution = null,
        canonicalIdentifier = null,
        sourceHeaderAttribution = emptyMap(),
        sourceURI = "https://example.invalid/source",
        revision = null,
        retrievedOn = "2026-07-27",
        rights = DocumentedSourceRights(
            status = SourceRightsStatus.PUBLIC_DOMAIN,
            commercialUse = SourceCommercialUse.PERMITTED,
            redistribution = SourceRedistribution.PERMITTED,
            statement = "Public domain fixture",
            statementURI = null,
            licenseIdentifier = null,
        ),
        artifacts = listOf(
            DocumentedSourceArtifact(
                locator = "fixture.txt",
                pathWithinSource = null,
                bytes = 1,
                sha256 = "0".repeat(64),
            ),
        ),
    )
}
