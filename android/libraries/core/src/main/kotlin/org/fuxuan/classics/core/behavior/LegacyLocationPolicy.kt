package org.fuxuan.classics.core.behavior

enum class LegacyLocationUsage {
    FAVORITE,
    RESUME,
}

sealed interface LegacyLocationResolution {
    data class Mapped(
        val sectionID: String,
        val paragraphID: String?,
    ) : LegacyLocationResolution

    data object Invalid : LegacyLocationResolution

    data object Unresolved : LegacyLocationResolution
}

data class LegacyPathEntry(
    val legacyPath: String,
    val sectionID: String,
    val directParagraphIDs: List<String>,
    val firstDescendantParagraphID: String?,
)

data class LegacyPathMap(
    val schemaVersion: Int,
    val productID: String,
    val bookID: String,
    val editionID: String,
    val mappingVersion: String,
    val stableIDScheme: String,
    val normalization: String,
    val mappingHash: String,
    val paths: List<LegacyPathEntry>,
) {
    init {
        require(schemaVersion == 1) { "unsupported legacy map schemaVersion" }
        require(mappingVersion.isNotBlank()) { "legacy mappingVersion must not be blank" }
        require(stableIDScheme == "fuxuan-classics-v1") { "unsupported stable ID scheme" }
        require(normalization == "utf8-nfc-lf-v1") { "unsupported legacy map normalization" }
        require(mappingHash.matches(Regex("^[a-f0-9]{64}$"))) { "invalid legacy mappingHash" }
        require(paths.isNotEmpty()) { "legacy map must contain paths" }
    }

    fun resolver(): LegacyLocationResolver = LegacyLocationResolver(productID, paths)
}

class LegacyLocationResolver(
    val productID: String,
    entries: List<LegacyPathEntry>,
) {
    private val entriesByPath = entries.associateBy(LegacyPathEntry::legacyPath)

    init {
        require(entriesByPath.size == entries.size) { "legacy paths must be unique" }
    }

    fun resolve(
        legacyPath: String,
        usage: LegacyLocationUsage,
    ): LegacyLocationResolution {
        if (legacyPath.isEmpty() || legacyPath == "/") return LegacyLocationResolution.Invalid
        val entry = entriesByPath[legacyPath] ?: return LegacyLocationResolution.Unresolved
        val paragraphID = when (usage) {
            LegacyLocationUsage.FAVORITE,
            LegacyLocationUsage.RESUME ->
                entry.directParagraphIDs.firstOrNull() ?: entry.firstDescendantParagraphID
        }
        return LegacyLocationResolution.Mapped(
            sectionID = entry.sectionID,
            paragraphID = paragraphID,
        )
    }
}
