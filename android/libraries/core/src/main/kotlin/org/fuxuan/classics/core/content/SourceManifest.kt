package org.fuxuan.classics.core.content

import java.net.URI
import java.time.Instant
import java.time.LocalDate

enum class SourceReviewStatus(val contractValue: String) {
    LEGACY_UNVERIFIED("legacy-unverified"),
    CANDIDATE("candidate"),
    APPROVED("approved"),
    REJECTED("rejected"),
    ;

    companion object {
        fun fromContract(value: String): SourceReviewStatus =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source review status: $value")
    }
}

enum class SourceReleaseEligibility(val contractValue: String) {
    BLOCKED("blocked"),
    ELIGIBLE("eligible"),
    ;

    companion object {
        fun fromContract(value: String): SourceReleaseEligibility =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source release eligibility: $value")
    }
}

enum class SourceApprovalStatus(val contractValue: String) {
    PENDING("pending"),
    APPROVED("approved"),
    REJECTED("rejected"),
    ;

    companion object {
        fun fromContract(value: String): SourceApprovalStatus =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source approval status: $value")
    }
}

enum class DocumentedSourceRole(val contractValue: String) {
    LEGACY_RUNTIME_INPUT("legacy-runtime-input"),
    CANONICAL_INPUT("canonical-input"),
    COLLATION_REFERENCE("collation-reference"),
    TRANSCRIPTION_BASE("transcription-base"),
    TRANSLATION_REFERENCE("translation-reference"),
    ;

    companion object {
        fun fromContract(value: String): DocumentedSourceRole =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid documented source role: $value")
    }
}

enum class DocumentedSourceFormat(val contractValue: String) {
    REPOSITORY_JSON("repository-json"),
    TEI_XML("tei-xml"),
    SCAN_IMAGES("scan-images"),
    PLAIN_TEXT("plain-text"),
    ;

    companion object {
        fun fromContract(value: String): DocumentedSourceFormat =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid documented source format: $value")
    }
}

enum class SourceRightsStatus(val contractValue: String) {
    UNKNOWN("unknown"),
    RESTRICTED_NONCOMMERCIAL("restricted-noncommercial"),
    PUBLIC_DOMAIN("public-domain"),
    PRODUCT_LICENSE("product-license"),
    ;

    companion object {
        fun fromContract(value: String): SourceRightsStatus =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source rights status: $value")
    }
}

enum class SourceCommercialUse(val contractValue: String) {
    UNKNOWN("unknown"),
    REQUIRES_PERMISSION("requires-permission"),
    PERMITTED("permitted"),
    ;

    companion object {
        fun fromContract(value: String): SourceCommercialUse =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source commercial-use status: $value")
    }
}

enum class SourceRedistribution(val contractValue: String) {
    UNKNOWN("unknown"),
    HEADER_REQUIRED("header-required"),
    PERMITTED("permitted"),
    ;

    companion object {
        fun fromContract(value: String): SourceRedistribution =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid source redistribution status: $value")
    }
}

data class SourceApproval(
    val status: SourceApprovalStatus,
    val reviewedBy: String?,
    val reviewedAt: String?,
    val notes: String?,
) {
    init {
        require(reviewedBy == null || reviewedBy.isNotBlank()) {
            "source approval reviewer must not be blank"
        }
        require(
            reviewedAt == null ||
                (DATE_TIME_PATTERN.matches(reviewedAt) &&
                    runCatching { Instant.parse(reviewedAt) }.isSuccess),
        ) {
            "source approval review time must be an ISO-8601 instant"
        }
        require(notes == null || notes.isNotBlank()) {
            "source approval notes must not be blank"
        }
        if (status != SourceApprovalStatus.PENDING) {
            require(reviewedBy != null && reviewedAt != null) {
                "completed source approval requires reviewer and time"
            }
        }
    }
}

data class SourceApprovals(
    val textAccuracy: SourceApproval,
    val rights: SourceApproval,
)

data class DocumentedSourceRights(
    val status: SourceRightsStatus,
    val commercialUse: SourceCommercialUse,
    val redistribution: SourceRedistribution,
    val statement: String,
    val statementURI: String?,
    val licenseIdentifier: String?,
) {
    init {
        require(statement.isNotBlank()) { "source rights statement must not be blank" }
        require(statementURI == null || statementURI.isAbsoluteURI()) {
            "source rights statement URI must be absolute"
        }
        require(licenseIdentifier == null || licenseIdentifier.isNotBlank()) {
            "source license identifier must not be blank"
        }
        if (status == SourceRightsStatus.PRODUCT_LICENSE) {
            require(statementURI != null && licenseIdentifier != null) {
                "product license requires a statement URI and license identifier"
            }
        }
    }
}

data class DocumentedSourceArtifact(
    val locator: String,
    val pathWithinSource: String?,
    val bytes: Long,
    val sha256: String,
) {
    init {
        require(locator.isNotBlank()) { "source artifact locator must not be blank" }
        require(pathWithinSource == null || pathWithinSource.isSafeRelativePath()) {
            "source artifact path must be a safe relative path"
        }
        require(bytes in 1..MAX_SAFE_INTEGER) { "source artifact bytes must be positive" }
        require(SHA256_PATTERN.matches(sha256)) { "invalid source artifact SHA-256" }
    }
}

data class DocumentedSource(
    val sourceID: String,
    val role: DocumentedSourceRole,
    val format: DocumentedSourceFormat,
    val title: String,
    val institution: String?,
    val canonicalIdentifier: String?,
    val sourceHeaderAttribution: Map<String, String>,
    val sourceURI: String,
    val revision: String?,
    val retrievedOn: String,
    val rights: DocumentedSourceRights,
    val artifacts: List<DocumentedSourceArtifact>,
) {
    init {
        require(DOCUMENTED_SOURCE_ID_PATTERN.matches(sourceID)) {
            "invalid documented sourceID: $sourceID"
        }
        require(title.isNotBlank()) { "documented source title must not be blank" }
        require(institution == null || institution.isNotBlank()) {
            "documented source institution must not be blank"
        }
        require(canonicalIdentifier == null || canonicalIdentifier.isNotBlank()) {
            "documented source identifier must not be blank"
        }
        require(sourceHeaderAttribution.keys.all(LOCALE_PATTERN::matches)) {
            "documented source attribution has an invalid locale"
        }
        require(sourceHeaderAttribution.values.all(String::isNotBlank)) {
            "documented source attribution must not be blank"
        }
        require(sourceURI.isAbsoluteURI()) { "documented source URI must be absolute" }
        require(revision == null || revision.isNotBlank()) {
            "documented source revision must not be blank"
        }
        require(
            DATE_PATTERN.matches(retrievedOn) &&
                runCatching { LocalDate.parse(retrievedOn) }.isSuccess,
        ) {
            "documented source retrieval date must be ISO-8601"
        }
        require(artifacts.isNotEmpty()) { "documented source must contain an artifact" }
    }

    fun attribution(locale: String): String? =
        sourceHeaderAttribution[locale] ?: sourceHeaderAttribution.values.firstOrNull()
}

data class SourceManifest(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val reviewStatus: SourceReviewStatus,
    val releaseEligibility: SourceReleaseEligibility,
    val approvals: SourceApprovals,
    val sources: List<DocumentedSource>,
) {
    init {
        require(schemaVersion == 1) { "unsupported source schemaVersion: $schemaVersion" }
        require(PRODUCT_ID_PATTERN.matches(productID)) { "invalid source productID: $productID" }
        require(BOOK_ID_PATTERN.matches(bookID)) { "invalid source bookID: $bookID" }
        require(EDITION_ID_PATTERN.matches(editionID)) { "invalid source editionID: $editionID" }
        require(sources.isNotEmpty()) { "source manifest must contain a source" }
        require(sources.map(DocumentedSource::sourceID).toSet().size == sources.size) {
            "documented source IDs must be unique"
        }
        if (releaseEligibility == SourceReleaseEligibility.ELIGIBLE) {
            require(reviewStatus == SourceReviewStatus.APPROVED) {
                "eligible source manifest must be approved"
            }
            require(approvals.textAccuracy.status == SourceApprovalStatus.APPROVED) {
                "eligible source manifest requires text approval"
            }
            require(approvals.rights.status == SourceApprovalStatus.APPROVED) {
                "eligible source manifest requires rights approval"
            }
        }
    }
}

private fun String.isAbsoluteURI(): Boolean = runCatching {
    val uri = URI(this)
    uri.isAbsolute && !uri.scheme.isNullOrBlank()
}.getOrDefault(false)

private fun String.isSafeRelativePath(): Boolean {
    val segments = split('/')
    return isNotBlank() &&
        !startsWith('/') &&
        '\\' !in this &&
        segments.all { it.isNotBlank() && it != "." && it != ".." }
}

private val DATE_PATTERN = Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
private val DOCUMENTED_SOURCE_ID_PATTERN = Regex("^[a-z][a-z0-9.-]*$")
private val DATE_TIME_PATTERN = Regex(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:Z|[+-][0-9]{2}:[0-9]{2})$",
)
