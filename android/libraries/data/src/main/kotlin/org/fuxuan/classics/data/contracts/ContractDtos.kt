package org.fuxuan.classics.data.contracts

import kotlinx.serialization.Serializable
import org.fuxuan.classics.core.content.AudioArtifact
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.AudioContentMapping
import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.core.content.AudioRights
import org.fuxuan.classics.core.behavior.LegacyPathEntry
import org.fuxuan.classics.core.behavior.LegacyPathMap
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductFeatures
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference

@Serializable
internal data class ProductManifestDto(
    val schemaVersion: Int,
    val productID: String,
    val lifecycle: String,
    val titles: Map<String, String>,
    val defaultLocale: String,
    val supportedLocales: List<String>,
    val navigationMode: String,
    val manifests: ProductManifestPathsDto,
    val features: ProductFeaturesDto,
    val platforms: ProductPlatformsDto,
) {
    fun toDomain() = ProductManifest(
        schemaVersion = schemaVersion,
        productID = productID,
        lifecycle = lifecycle,
        titles = titles,
        defaultLocale = defaultLocale,
        supportedLocales = supportedLocales,
        navigationMode = navigationMode,
        bookManifestPath = manifests.book,
        sourceManifestPath = manifests.source,
        audioManifestPath = manifests.audio,
        androidAudioDeliveryPath = platforms.android.audioDelivery,
        features = features.toDomain(),
    )
}

@Serializable
internal data class ProductManifestPathsDto(
    val book: String,
    val source: String,
    val audio: String? = null,
    val audioBuild: String? = null,
)

@Serializable
internal data class ProductFeaturesDto(
    val audio: Boolean,
    val dailyVerse: Boolean,
    val guidedReading: Boolean,
    val personIndex: Boolean,
) {
    fun toDomain() = ProductFeatures(
        audio = audio,
        dailyVerse = dailyVerse,
        guidedReading = guidedReading,
        personIndex = personIndex,
    )
}

@Serializable
internal data class ProductPlatformsDto(
    val ios: ProductPlatformDto,
    val android: ProductPlatformDto,
)

@Serializable
internal data class ProductPlatformDto(
    val state: String,
    val audioDelivery: String? = null,
)

@Serializable
internal data class BookManifestDto(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val contractState: String,
    val titles: Map<String, String>,
    val canonicalLocale: String,
    val supportedLocales: List<String>,
    val contentVersion: String,
    val stableIDScheme: String,
    val normalization: String,
    val sourceManifest: String,
    val contentPackages: Map<String, String> = emptyMap(),
    val legacyCompatibility: LegacyCompatibilityDto? = null,
) {
    fun toDomain() = BookManifest(
        schemaVersion = schemaVersion,
        productID = productID,
        bookID = bookID,
        editionID = editionID,
        contractState = contractState,
        titles = titles,
        canonicalLocale = canonicalLocale,
        supportedLocales = supportedLocales,
        contentVersion = contentVersion,
        stableIDScheme = stableIDScheme,
        normalization = normalization,
        sourceManifestPath = sourceManifest,
        contentPackagePaths = contentPackages,
        legacyMapPath = legacyCompatibility?.mappingArtifact,
    )
}

@Serializable
internal data class LegacyCompatibilityDto(
    val identifierKind: String,
    val identifierPattern: String,
    val migrationStatus: String,
    val mappingArtifact: String? = null,
    val sourceArtifacts: List<String>,
)

@Serializable
internal data class ContentPackageDto(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val contentVersion: String,
    val contentStatus: String,
    val locale: String,
    val normalization: String,
    val contentHash: String,
    val volumes: List<VolumeDto>,
    val sections: List<SectionDto>,
    val paragraphs: List<ParagraphDto>,
) {
    fun toDomain() = ScriptureContent(
        schemaVersion = schemaVersion,
        productID = productID,
        bookID = bookID,
        editionID = editionID,
        contentVersion = contentVersion,
        contentStatus = contentStatus,
        locale = locale,
        normalization = normalization,
        contentHash = contentHash,
        volumes = volumes.map(VolumeDto::toDomain),
        sections = sections.map(SectionDto::toDomain),
        paragraphs = paragraphs.map(ParagraphDto::toDomain),
    )
}

@Serializable
internal data class VolumeDto(
    val volumeID: String,
    val number: Int,
    val order: Int,
    val title: String,
    val sourceReferences: List<SourceReferenceDto>,
) {
    fun toDomain() = ScriptureVolume(
        volumeID = volumeID,
        number = number,
        order = order,
        title = title,
        sourceReferences = sourceReferences.map(SourceReferenceDto::toDomain),
    )
}

@Serializable
internal data class SectionDto(
    val sectionID: String,
    val parentSectionID: String?,
    val order: Int,
    val title: String,
    val subtitle: String? = null,
    val sourceReferences: List<SourceReferenceDto>,
    val legacyIDs: List<String> = emptyList(),
) {
    fun toDomain() = ScriptureSection(
        sectionID = sectionID,
        parentSectionID = parentSectionID,
        order = order,
        title = title,
        subtitle = subtitle,
        sourceReferences = sourceReferences.map(SourceReferenceDto::toDomain),
        legacyIDs = legacyIDs,
    )
}

@Serializable
internal data class ParagraphDto(
    val paragraphID: String,
    val sectionID: String,
    val volumeID: String?,
    val order: Int,
    val textRole: String,
    val text: String,
    val sourceReferences: List<SourceReferenceDto>,
    val legacyIDs: List<String> = emptyList(),
    val legacyVolumeHint: Int? = null,
) {
    fun toDomain() = ScriptureParagraph(
        paragraphID = paragraphID,
        sectionID = sectionID,
        volumeID = volumeID,
        order = order,
        textRole = textRole,
        text = text,
        sourceReferences = sourceReferences.map(SourceReferenceDto::toDomain),
        legacyIDs = legacyIDs,
        legacyVolumeHint = legacyVolumeHint,
    )
}

@Serializable
internal data class SourceReferenceDto(
    val sourceID: String,
    val locator: String,
) {
    fun toDomain() = SourceReference(sourceID = sourceID, locator = locator)
}

@Serializable
internal data class LegacyPathMapDto(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val mappingVersion: String,
    val stableIDScheme: String,
    val normalization: String,
    val mappingHash: String,
    val paths: List<LegacyPathEntryDto>,
) {
    fun toDomain() = LegacyPathMap(
        schemaVersion = schemaVersion,
        productID = productID,
        bookID = bookID,
        editionID = editionID,
        mappingVersion = mappingVersion,
        stableIDScheme = stableIDScheme,
        normalization = normalization,
        mappingHash = mappingHash,
        paths = paths.map(LegacyPathEntryDto::toDomain),
    )
}

@Serializable
internal data class LegacyPathEntryDto(
    val legacyPath: String,
    val legacyNodeID: String,
    val parentLegacyPath: String?,
    val sectionID: String,
    val order: Int,
    val directParagraphIDs: List<String>,
    val firstDescendantParagraphID: String?,
    val descendantParagraphCount: Int,
) {
    fun toDomain() = LegacyPathEntry(
        legacyPath = legacyPath,
        sectionID = sectionID,
        directParagraphIDs = directParagraphIDs,
        firstDescendantParagraphID = firstDescendantParagraphID,
    )
}

@Serializable
internal data class AudioCatalogDto(
    val schemaVersion: Int,
    val productID: String,
    val catalogID: String,
    val catalogVersion: String,
    val contractState: String,
    val contentVersion: String,
    val supportedLocales: List<String>,
    val performers: Map<String, String>,
    val rights: AudioRightsDto,
    val artifacts: List<AudioArtifactDto>,
) {
    fun toDomain() = AudioCatalog(
        schemaVersion = schemaVersion,
        productID = productID,
        catalogID = catalogID,
        catalogVersion = catalogVersion,
        contractState = contractState,
        contentVersion = contentVersion,
        supportedLocales = supportedLocales,
        performers = performers,
        rights = rights.toDomain(),
        artifacts = artifacts.map(AudioArtifactDto::toDomain),
    )
}

@Serializable
internal data class AudioRightsDto(
    val rightsID: String,
    val status: String,
    val reuseEligibility: String,
    val statement: String,
    val evidenceReference: String? = null,
) {
    fun toDomain() = AudioRights(
        rightsID = rightsID,
        status = status,
        reuseEligibility = reuseEligibility,
        statement = statement,
        evidenceReference = evidenceReference,
    )
}

@Serializable
internal data class AudioArtifactDto(
    val artifactID: String,
    val legacyTrackID: String? = null,
    val kind: String,
    val titles: Map<String, String>,
    val contentMapping: AudioContentMappingDto,
    val rightsReference: String,
    val renditions: List<AudioRenditionDto>,
) {
    fun toDomain() = AudioArtifact(
        artifactID = artifactID,
        legacyTrackID = legacyTrackID,
        kind = kind,
        titles = titles,
        contentMapping = contentMapping.toDomain(),
        rightsReference = rightsReference,
        renditions = renditions.map(AudioRenditionDto::toDomain),
    )
}

@Serializable
internal data class AudioContentMappingDto(
    val status: String,
    val bookID: String,
    val legacyVolume: Int? = null,
    val volumeID: String? = null,
    val paragraphStartID: String? = null,
    val paragraphEndID: String? = null,
) {
    fun toDomain() = AudioContentMapping(
        status = status,
        bookID = bookID,
        legacyVolume = legacyVolume,
        volumeID = volumeID,
        paragraphStartID = paragraphStartID,
        paragraphEndID = paragraphEndID,
    )
}

@Serializable
internal data class AudioRenditionDto(
    val renditionID: String,
    val fileName: String,
    val artifactKey: String,
    val mediaType: String,
    val fileExtension: String,
    val codec: String,
    val durationMilliseconds: Long,
    val sampleRateHertz: Int,
    val channels: Int,
    val bytes: Long,
    val sha256: String,
) {
    fun toDomain() = AudioRendition(
        renditionID = renditionID,
        fileName = fileName,
        artifactKey = artifactKey,
        mediaType = mediaType,
        fileExtension = fileExtension,
        codec = codec,
        durationMilliseconds = durationMilliseconds,
        sampleRateHertz = sampleRateHertz,
        channels = channels,
        bytes = bytes,
        sha256 = sha256,
    )
}
