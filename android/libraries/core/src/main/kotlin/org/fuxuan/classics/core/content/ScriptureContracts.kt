package org.fuxuan.classics.core.content

data class ProductManifest(
    val schemaVersion: Int,
    val productID: String,
    val lifecycle: String,
    val titles: Map<String, String>,
    val defaultLocale: String,
    val supportedLocales: List<String>,
    val navigationMode: String,
    val bookManifestPath: String,
    val sourceManifestPath: String,
    val audioManifestPath: String?,
    val androidPlatformState: ProductPlatformState,
    val androidAudioDeliveryPath: String?,
    val features: ProductFeatures,
    val featuredParagraphIDs: List<String> = emptyList(),
) {
    init {
        require(schemaVersion == 1) { "unsupported product schemaVersion: $schemaVersion" }
        require(PRODUCT_ID_PATTERN.matches(productID)) { "invalid productID: $productID" }
        require(lifecycle in PRODUCT_LIFECYCLES) { "invalid product lifecycle: $lifecycle" }
        require(navigationMode in NAVIGATION_MODES) { "invalid navigation mode: $navigationMode" }
        require(defaultLocale in supportedLocales) { "default locale is not supported" }
        require(supportedLocales.toSet().size == supportedLocales.size) {
            "supported locales must be unique"
        }
        require(supportedLocales.all(titles::containsKey)) {
            "every supported locale must have a product title"
        }
        requireLocalizedStrings(titles, "product title")
        requireSafeRelativePath(bookManifestPath, "book manifest")
        requireSafeRelativePath(sourceManifestPath, "source manifest")
        audioManifestPath?.let { requireSafeRelativePath(it, "audio manifest") }
        androidAudioDeliveryPath?.let { requireSafeRelativePath(it, "Android audio delivery") }
        if (androidAudioDeliveryPath != null) {
            require(features.audio) { "product without audio cannot provide Android delivery" }
        }
        if (androidPlatformState.isActive && features.audio) {
            require(androidAudioDeliveryPath != null) {
                "active Android audio product must provide a delivery manifest"
            }
        }
        if (lifecycle in setOf("production", "development") && features.audio) {
            require(audioManifestPath != null) { "audio product must provide an audio manifest" }
        }
        require(featuredParagraphIDs.toSet().size == featuredParagraphIDs.size) {
            "featured paragraph IDs must be unique"
        }
        require(featuredParagraphIDs.all(PARAGRAPH_ID_PATTERN::matches)) {
            "featured paragraph IDs must use the stable paragraph ID scheme"
        }
        if (lifecycle in setOf("production", "development") && features.dailyVerse) {
            require(featuredParagraphIDs.isNotEmpty()) {
                "active daily verse product must provide featured paragraphs"
            }
        }
    }

    fun title(locale: String): String = titles[locale] ?: titles.getValue(defaultLocale)
}

data class ProductFeatures(
    val audio: Boolean,
    val dailyVerse: Boolean,
    val guidedReading: Boolean,
    val personIndex: Boolean,
)

data class BookManifest(
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
    val sourceManifestPath: String,
    val contentPackagePaths: Map<String, String>,
    val legacyMapPath: String?,
) {
    init {
        require(schemaVersion == 1) { "unsupported book schemaVersion: $schemaVersion" }
        require(PRODUCT_ID_PATTERN.matches(productID)) { "invalid productID: $productID" }
        require(BOOK_ID_PATTERN.matches(bookID)) { "invalid bookID: $bookID" }
        require(EDITION_ID_PATTERN.matches(editionID)) { "invalid editionID: $editionID" }
        require(contractState in BOOK_CONTRACT_STATES) { "invalid book contract state: $contractState" }
        require(CONTENT_VERSION_PATTERN.matches(contentVersion)) { "invalid contentVersion" }
        require(canonicalLocale in supportedLocales) { "canonical locale is not supported" }
        require(supportedLocales.toSet().size == supportedLocales.size) {
            "supported locales must be unique"
        }
        require(supportedLocales.all(titles::containsKey)) {
            "every supported locale must have a book title"
        }
        requireLocalizedStrings(titles, "book title")
        require(contentPackagePaths.keys.all { it in supportedLocales }) {
            "content package locale is not supported"
        }
        contentPackagePaths.values.forEach { requireSafeRelativePath(it, "content package") }
        requireSafeRelativePath(sourceManifestPath, "source manifest")
        legacyMapPath?.let { requireSafeRelativePath(it, "legacy map") }
        require(stableIDScheme == "fuxuan-classics-v1") { "unsupported stable ID scheme" }
        require(normalization == NORMALIZATION) { "unsupported content normalization" }
    }

    fun title(locale: String): String = titles[locale] ?: titles.getValue(canonicalLocale)
}

data class SourceReference(
    val sourceID: String,
    val locator: String,
) {
    init {
        require(sourceID.isNotBlank()) { "sourceID must not be blank" }
        require(SOURCE_ID_PATTERN.matches(sourceID)) { "invalid sourceID: $sourceID" }
        require(locator.isNotBlank()) { "source locator must not be blank" }
    }
}

data class ScriptureVolume(
    val volumeID: String,
    val number: Int,
    val order: Int,
    val title: String,
    val sourceReferences: List<SourceReference>,
) {
    init {
        require(VOLUME_ID_PATTERN.matches(volumeID)) { "invalid volumeID: $volumeID" }
        require(number > 0) { "volume number must be positive" }
        require(order >= 0) { "volume order must not be negative" }
        require(title.isNotBlank()) { "volume title must not be blank" }
        require(sourceReferences.isNotEmpty()) { "volume must cite a source" }
    }
}

data class ScriptureSection(
    val sectionID: String,
    val parentSectionID: String?,
    val order: Int,
    val title: String,
    val subtitle: String?,
    val sourceReferences: List<SourceReference>,
    val legacyIDs: List<String>,
) {
    init {
        require(SECTION_ID_PATTERN.matches(sectionID)) { "invalid sectionID: $sectionID" }
        require(parentSectionID == null || SECTION_ID_PATTERN.matches(parentSectionID)) {
            "invalid parentSectionID: $parentSectionID"
        }
        require(parentSectionID != sectionID) { "section cannot be its own parent" }
        require(order >= 0) { "section order must not be negative" }
        require(title.isNotBlank()) { "section title must not be blank" }
        require(subtitle == null || subtitle.isNotBlank()) { "section subtitle must not be blank" }
        require(sourceReferences.isNotEmpty()) { "section must cite a source" }
        require(legacyIDs.toSet().size == legacyIDs.size) { "legacy section IDs must be unique" }
    }
}

data class ScriptureParagraph(
    val paragraphID: String,
    val sectionID: String,
    val volumeID: String?,
    val order: Int,
    val textRole: String,
    val text: String,
    val sourceReferences: List<SourceReference>,
    val legacyIDs: List<String>,
    val legacyVolumeHint: Int?,
) {
    init {
        require(PARAGRAPH_ID_PATTERN.matches(paragraphID)) { "invalid paragraphID: $paragraphID" }
        require(SECTION_ID_PATTERN.matches(sectionID)) { "invalid sectionID: $sectionID" }
        require(volumeID == null || VOLUME_ID_PATTERN.matches(volumeID)) {
            "invalid volumeID: $volumeID"
        }
        require(order >= 0) { "paragraph order must not be negative" }
        require(TEXT_ROLE_PATTERN.matches(textRole)) { "invalid textRole: $textRole" }
        require(text.isNotEmpty()) { "paragraph text must not be empty" }
        require(sourceReferences.isNotEmpty()) { "paragraph must cite a source" }
        require(legacyIDs.toSet().size == legacyIDs.size) { "legacy paragraph IDs must be unique" }
        require(legacyVolumeHint == null || legacyVolumeHint > 0) {
            "legacy volume hint must be positive"
        }
    }
}

class ScriptureContent(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val contentVersion: String,
    val contentStatus: String,
    val locale: String,
    val normalization: String,
    val contentHash: String,
    val volumes: List<ScriptureVolume>,
    val sections: List<ScriptureSection>,
    val paragraphs: List<ScriptureParagraph>,
) {
    private val volumesByID = volumes.associateBy(ScriptureVolume::volumeID)
    private val orderedVolumes = volumes.sortedBy(ScriptureVolume::order)
    private val sectionsByID = sections.associateBy(ScriptureSection::sectionID)
    private val paragraphsByID = paragraphs.associateBy(ScriptureParagraph::paragraphID)
    private val childrenByParentID = sections
        .groupBy(ScriptureSection::parentSectionID)
        .mapValues { (_, children) -> children.sortedBy(ScriptureSection::order) }
    private val paragraphsBySectionID = paragraphs
        .groupBy(ScriptureParagraph::sectionID)
        .mapValues { (_, values) -> values.sortedBy(ScriptureParagraph::order) }

    init {
        require(schemaVersion == 1) { "unsupported content schemaVersion: $schemaVersion" }
        require(PRODUCT_ID_PATTERN.matches(productID)) { "invalid productID: $productID" }
        require(BOOK_ID_PATTERN.matches(bookID)) { "invalid bookID: $bookID" }
        require(EDITION_ID_PATTERN.matches(editionID)) { "invalid editionID: $editionID" }
        require(CONTENT_VERSION_PATTERN.matches(contentVersion)) { "invalid contentVersion" }
        require(contentStatus in CONTENT_STATUSES) { "invalid content status: $contentStatus" }
        require(LOCALE_PATTERN.matches(locale)) { "invalid content locale: $locale" }
        require(normalization == NORMALIZATION) { "unsupported content normalization" }
        require(SHA256_PATTERN.matches(contentHash)) { "invalid contentHash" }
        require(volumes.isNotEmpty()) { "content must contain a volume" }
        require(sections.isNotEmpty()) { "content must contain a section" }
        require(paragraphs.isNotEmpty()) { "content must contain a paragraph" }
        require(volumesByID.size == volumes.size) { "volume IDs must be unique" }
        require(sectionsByID.size == sections.size) { "section IDs must be unique" }
        require(paragraphsByID.size == paragraphs.size) { "paragraph IDs must be unique" }
        requireUniqueOrders(volumes, ScriptureVolume::order, "volume")
        childrenByParentID.values.forEach { siblings ->
            requireUniqueOrders(siblings, ScriptureSection::order, "sibling section")
        }
        paragraphsBySectionID.values.forEach { values ->
            requireUniqueOrders(values, ScriptureParagraph::order, "section paragraph")
        }
        sections.forEach { section ->
            require(section.parentSectionID == null || section.parentSectionID in sectionsByID) {
                "missing parent for ${section.sectionID}"
            }
        }
        paragraphs.forEach { paragraph ->
            require(paragraph.sectionID in sectionsByID) {
                "missing section for ${paragraph.paragraphID}"
            }
            require(paragraph.volumeID == null || paragraph.volumeID in volumesByID) {
                "missing volume for ${paragraph.paragraphID}"
            }
        }
        validateSectionTree()
    }

    fun volume(volumeID: String): ScriptureVolume? = volumesByID[volumeID]

    fun volumesInReadingOrder(): List<ScriptureVolume> = orderedVolumes

    fun section(sectionID: String): ScriptureSection? = sectionsByID[sectionID]

    fun paragraph(paragraphID: String): ScriptureParagraph? = paragraphsByID[paragraphID]

    fun rootSections(): List<ScriptureSection> = childrenByParentID[null].orEmpty()

    fun childrenOf(sectionID: String): List<ScriptureSection> =
        childrenByParentID[sectionID].orEmpty()

    fun paragraphsIn(sectionID: String): List<ScriptureParagraph> =
        paragraphsBySectionID[sectionID].orEmpty()

    fun firstParagraphInSubtree(sectionID: String): ScriptureParagraph? {
        if (sectionID !in sectionsByID) return null
        paragraphsIn(sectionID).firstOrNull()?.let { return it }
        for (child in childrenOf(sectionID)) {
            val paragraph = firstParagraphInSubtree(child.sectionID)
            if (paragraph != null) return paragraph
        }
        return null
    }

    fun paragraphsInReadingOrder(): List<ScriptureParagraph> = buildList {
        fun appendSection(section: ScriptureSection) {
            addAll(paragraphsIn(section.sectionID))
            childrenOf(section.sectionID).forEach(::appendSection)
        }
        rootSections().forEach(::appendSection)
    }

    fun leafSections(): List<ScriptureSection> = sections.filter { childrenOf(it.sectionID).isEmpty() }

    fun sectionPath(sectionID: String): List<ScriptureSection> {
        val path = mutableListOf<ScriptureSection>()
        var current = sectionsByID[sectionID] ?: return emptyList()
        while (true) {
            path += current
            val parentID = current.parentSectionID ?: break
            current = sectionsByID.getValue(parentID)
        }
        return path.asReversed()
    }

    private fun validateSectionTree() {
        val visiting = mutableSetOf<String>()
        val visited = mutableSetOf<String>()

        fun visit(section: ScriptureSection) {
            require(visiting.add(section.sectionID)) { "section hierarchy contains a cycle" }
            childrenOf(section.sectionID).forEach(::visit)
            visiting.remove(section.sectionID)
            visited += section.sectionID
        }

        val roots = rootSections()
        require(roots.isNotEmpty()) { "content must contain a root section" }
        roots.forEach(::visit)
        require(visited.size == sections.size) { "every section must be reachable from a root" }
    }

    private fun <T> requireUniqueOrders(
        values: List<T>,
        order: (T) -> Int,
        label: String,
    ) {
        require(values.map(order).toSet().size == values.size) { "$label orders must be unique" }
    }
}

data class AudioRights(
    val rightsID: String,
    val status: String,
    val reuseEligibility: String,
    val statement: String,
    val evidenceReference: String?,
) {
    init {
        require(ARTIFACT_ID_PATTERN.matches(rightsID)) { "invalid audio rightsID: $rightsID" }
        require(status in AUDIO_RIGHTS_STATUSES) { "invalid audio rights status: $status" }
        require(reuseEligibility in AUDIO_REUSE_ELIGIBILITY) {
            "invalid audio reuse eligibility: $reuseEligibility"
        }
        require(statement.isNotBlank()) { "audio rights statement must not be blank" }
        require(evidenceReference == null || evidenceReference.isNotBlank()) {
            "audio rights evidence reference must not be blank"
        }
        if (reuseEligibility == "eligible") {
            require(evidenceReference != null) { "eligible audio rights require evidence" }
        }
    }
}

data class AudioContentMapping(
    val status: String,
    val bookID: String,
    val legacyVolume: Int?,
    val volumeID: String?,
    val paragraphStartID: String?,
    val paragraphEndID: String?,
) {
    init {
        require(status in AUDIO_MAPPING_STATUSES) { "invalid audio mapping status: $status" }
        require(BOOK_ID_PATTERN.matches(bookID)) { "invalid mapped bookID: $bookID" }
        require(legacyVolume == null || legacyVolume > 0) { "legacy volume must be positive" }
        require(volumeID == null || VOLUME_ID_PATTERN.matches(volumeID)) {
            "invalid mapped volumeID: $volumeID"
        }
        if (status == "mapped") {
            require(volumeID != null) { "mapped audio requires a volumeID" }
        }
    }
}

data class AudioRendition(
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
    init {
        require(ARTIFACT_ID_PATTERN.matches(renditionID)) { "invalid renditionID: $renditionID" }
        require(fileName.isNotBlank() && '/' !in fileName && '\\' !in fileName) {
            "audio fileName must be a basename"
        }
        require(ARTIFACT_KEY_PATTERN.matches(artifactKey) && !hasParentSegment(artifactKey)) {
            "invalid audio artifactKey"
        }
        require(MEDIA_TYPE_PATTERN.matches(mediaType)) { "invalid audio mediaType" }
        require(FILE_EXTENSION_PATTERN.matches(fileExtension)) { "invalid audio file extension" }
        require(codec.isNotBlank()) { "audio codec must not be blank" }
        require(durationMilliseconds in 1..MAX_SAFE_INTEGER) { "audio duration must be positive" }
        require(sampleRateHertz > 0) { "sample rate must be positive" }
        require(channels in 1..32) { "channel count is outside the contract range" }
        require(bytes in 1..MAX_SAFE_INTEGER) { "audio byte count must be positive" }
        require(SHA256_PATTERN.matches(sha256)) { "invalid audio SHA-256" }
    }
}

data class AudioArtifact(
    val artifactID: String,
    val legacyTrackID: String?,
    val kind: String,
    val titles: Map<String, String>,
    val contentMapping: AudioContentMapping,
    val rightsReference: String,
    val renditions: List<AudioRendition>,
) {
    init {
        require(ARTIFACT_ID_PATTERN.matches(artifactID)) { "invalid artifactID: $artifactID" }
        require(kind in AUDIO_KINDS) { "invalid audio kind: $kind" }
        require(titles.isNotEmpty()) { "audio artifact must have a title" }
        requireLocalizedStrings(titles, "audio title")
        require(renditions.isNotEmpty()) { "audio artifact must have a rendition" }
        require(renditions.map(AudioRendition::renditionID).toSet().size == renditions.size) {
            "rendition IDs must be unique within an artifact"
        }
    }
}

data class AudioCatalog(
    val schemaVersion: Int,
    val productID: String,
    val catalogID: String,
    val catalogVersion: String,
    val contractState: String,
    val contentVersion: String,
    val supportedLocales: List<String>,
    val performers: Map<String, String>,
    val rights: AudioRights,
    val artifacts: List<AudioArtifact>,
) {
    init {
        require(schemaVersion == 1) { "unsupported audio schemaVersion: $schemaVersion" }
        require(PRODUCT_ID_PATTERN.matches(productID)) { "invalid productID: $productID" }
        require(ARTIFACT_ID_PATTERN.matches(catalogID)) { "invalid catalogID: $catalogID" }
        require(CONTENT_VERSION_PATTERN.matches(catalogVersion)) { "invalid catalogVersion" }
        require(contractState in AUDIO_CONTRACT_STATES) { "invalid audio contract state" }
        require(contentVersion.isNotBlank()) { "audio contentVersion must not be blank" }
        require(supportedLocales.toSet().size == supportedLocales.size) {
            "audio supported locales must be unique"
        }
        require(supportedLocales.all(LOCALE_PATTERN::matches)) { "invalid audio locale" }
        requireLocalizedStrings(performers, "audio performer")
        require(artifacts.isNotEmpty()) { "audio catalog must contain an artifact" }
        require(artifacts.map(AudioArtifact::artifactID).toSet().size == artifacts.size) {
            "audio artifact IDs must be unique"
        }
        require(artifacts.all { it.rightsReference == rights.rightsID }) {
            "audio artifact rights reference does not match the catalog"
        }
        if (contractState == "release-ready") {
            require(rights.reuseEligibility == "eligible") {
                "release-ready audio must be eligible for reuse"
            }
        }
    }
}

private const val NORMALIZATION = "utf8-nfc-lf-v1"
internal const val MAX_SAFE_INTEGER = 9_007_199_254_740_991L
internal val PRODUCT_ID_PATTERN = Regex("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
internal val BOOK_ID_PATTERN = PRODUCT_ID_PATTERN
internal val EDITION_ID_PATTERN = Regex("^[a-z0-9][a-z0-9.-]*$")
internal val LOCALE_PATTERN = Regex("^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
private val CONTENT_VERSION_PATTERN = Regex("^[A-Za-z0-9][A-Za-z0-9._-]*$")
private val VOLUME_ID_PATTERN = Regex("^[a-z][a-z0-9-]*\\.v[0-9]{6}$")
private val SECTION_ID_PATTERN = Regex("^[a-z][a-z0-9-]*\\.s[0-9]{6}$")
private val PARAGRAPH_ID_PATTERN = Regex("^[a-z][a-z0-9-]*\\.p[0-9]{6}$")
private val TEXT_ROLE_PATTERN = Regex("^[a-z][a-z0-9-]*$")
private val ARTIFACT_ID_PATTERN = Regex("^[a-z][a-z0-9.-]*$")
private val SOURCE_ID_PATTERN = ARTIFACT_ID_PATTERN
private val ARTIFACT_KEY_PATTERN = Regex("^[a-z0-9][a-z0-9._/-]*$")
private val MEDIA_TYPE_PATTERN = Regex("^[a-z0-9.+-]+/[a-z0-9.+-]+$")
private val FILE_EXTENSION_PATTERN = Regex("^[a-z0-9]+$")
internal val SHA256_PATTERN = Regex("^[a-f0-9]{64}$")
private val PRODUCT_LIFECYCLES = setOf("production", "development", "source-review", "retired")
private val NAVIGATION_MODES = setOf("hierarchy-and-volumes", "source-hierarchy", "continuous")
private val BOOK_CONTRACT_STATES = setOf("legacy-migration", "source-review", "canonical-ready")
private val CONTENT_STATUSES = setOf("legacy-migration", "release-canonical")
private val AUDIO_RIGHTS_STATUSES = setOf("legacy-unverified", "public-domain", "product-license")
private val AUDIO_REUSE_ELIGIBILITY = setOf("blocked", "eligible")
private val AUDIO_MAPPING_STATUSES = setOf("legacy-unmapped", "mapped")
private val AUDIO_KINDS = setOf("recitation", "chant", "commentary")
private val AUDIO_CONTRACT_STATES = setOf("legacy-migration", "release-ready")

private fun requireLocalizedStrings(values: Map<String, String>, label: String) {
    require(values.isNotEmpty()) { "$label map must not be empty" }
    require(values.keys.all(LOCALE_PATTERN::matches)) { "$label has an invalid locale" }
    require(values.values.all(String::isNotBlank)) { "$label must not be blank" }
}

private fun requireSafeRelativePath(path: String, label: String) {
    val segments = path.split('/')
    require(
        path.isNotBlank() &&
            !path.startsWith('/') &&
            '\\' !in path &&
            segments.all { it.isNotBlank() && it != "." && it != ".." },
    ) {
        "$label must be a safe relative path"
    }
}

private fun hasParentSegment(path: String): Boolean = path.split('/').any { it == ".." }
