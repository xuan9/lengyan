package org.fuxuan.classics.data.contracts

import kotlinx.serialization.Serializable
import org.fuxuan.classics.core.content.DocumentedSource
import org.fuxuan.classics.core.content.DocumentedSourceArtifact
import org.fuxuan.classics.core.content.DocumentedSourceFormat
import org.fuxuan.classics.core.content.DocumentedSourceRights
import org.fuxuan.classics.core.content.DocumentedSourceRole
import org.fuxuan.classics.core.content.SourceApproval
import org.fuxuan.classics.core.content.SourceApprovalStatus
import org.fuxuan.classics.core.content.SourceApprovals
import org.fuxuan.classics.core.content.SourceCommercialUse
import org.fuxuan.classics.core.content.SourceManifest
import org.fuxuan.classics.core.content.SourceRedistribution
import org.fuxuan.classics.core.content.SourceReleaseEligibility
import org.fuxuan.classics.core.content.SourceReviewStatus
import org.fuxuan.classics.core.content.SourceRightsStatus

@Serializable
internal data class SourceManifestDto(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val reviewStatus: String,
    val releaseEligibility: String,
    val approvals: SourceApprovalsDto,
    val sources: List<DocumentedSourceDto>,
) {
    fun toDomain() = SourceManifest(
        schemaVersion = schemaVersion,
        productID = productID,
        bookID = bookID,
        editionID = editionID,
        reviewStatus = SourceReviewStatus.fromContract(reviewStatus),
        releaseEligibility = SourceReleaseEligibility.fromContract(releaseEligibility),
        approvals = approvals.toDomain(),
        sources = sources.map(DocumentedSourceDto::toDomain),
    )
}

@Serializable
internal data class SourceApprovalsDto(
    val textAccuracy: SourceApprovalDto,
    val rights: SourceApprovalDto,
) {
    fun toDomain() = SourceApprovals(
        textAccuracy = textAccuracy.toDomain(),
        rights = rights.toDomain(),
    )
}

@Serializable
internal data class SourceApprovalDto(
    val status: String,
    val reviewedBy: String? = null,
    val reviewedAt: String? = null,
    val notes: String? = null,
) {
    fun toDomain() = SourceApproval(
        status = SourceApprovalStatus.fromContract(status),
        reviewedBy = reviewedBy,
        reviewedAt = reviewedAt,
        notes = notes,
    )
}

@Serializable
internal data class DocumentedSourceDto(
    val sourceID: String,
    val role: String,
    val format: String,
    val title: String,
    val institution: String? = null,
    val canonicalIdentifier: String? = null,
    val sourceHeaderAttribution: Map<String, String>? = null,
    val sourceURI: String,
    val revision: String? = null,
    val retrievedOn: String,
    val rights: DocumentedSourceRightsDto,
    val artifacts: List<DocumentedSourceArtifactDto>,
) {
    init {
        require(sourceHeaderAttribution == null || sourceHeaderAttribution.isNotEmpty()) {
            "documented source attribution must not be empty when present"
        }
    }

    fun toDomain() = DocumentedSource(
        sourceID = sourceID,
        role = DocumentedSourceRole.fromContract(role),
        format = DocumentedSourceFormat.fromContract(format),
        title = title,
        institution = institution,
        canonicalIdentifier = canonicalIdentifier,
        sourceHeaderAttribution = sourceHeaderAttribution.orEmpty(),
        sourceURI = sourceURI,
        revision = revision,
        retrievedOn = retrievedOn,
        rights = rights.toDomain(),
        artifacts = artifacts.map(DocumentedSourceArtifactDto::toDomain),
    )
}

@Serializable
internal data class DocumentedSourceRightsDto(
    val status: String,
    val commercialUse: String,
    val redistribution: String,
    val statement: String,
    val statementURI: String? = null,
    val licenseIdentifier: String? = null,
) {
    fun toDomain() = DocumentedSourceRights(
        status = SourceRightsStatus.fromContract(status),
        commercialUse = SourceCommercialUse.fromContract(commercialUse),
        redistribution = SourceRedistribution.fromContract(redistribution),
        statement = statement,
        statementURI = statementURI,
        licenseIdentifier = licenseIdentifier,
    )
}

@Serializable
internal data class DocumentedSourceArtifactDto(
    val locator: String,
    val pathWithinSource: String? = null,
    val bytes: Long,
    val sha256: String,
) {
    fun toDomain() = DocumentedSourceArtifact(
        locator = locator,
        pathWithinSource = pathWithinSource,
        bytes = bytes,
        sha256 = sha256,
    )
}
