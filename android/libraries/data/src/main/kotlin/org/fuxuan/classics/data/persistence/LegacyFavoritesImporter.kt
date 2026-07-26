package org.fuxuan.classics.data.persistence

import org.fuxuan.classics.core.behavior.LegacyFavoritesMigrationPolicy
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.FavoriteRepository

data class LegacyFavoritesImportResult(
    val storedCount: Int,
    val mappedCount: Int,
    val unresolvedCount: Int,
    val invalidCount: Int,
)

class LegacyFavoritesImporter(
    private val productID: String,
    private val bookRepository: BookRepository,
    private val favoriteRepository: FavoriteRepository,
) {
    suspend fun replaceFromLegacy(
        editionID: String,
        legacyFavorites: List<String>,
        storedUserFavorites: List<String>?,
        curatedLegacyPaths: Set<String>,
        importedAtEpochMilliseconds: Long,
    ): LegacyFavoritesImportResult {
        require(editionID.isNotBlank()) { "legacy import editionID must not be blank" }
        require(importedAtEpochMilliseconds >= 0) { "legacy import timestamp must not be negative" }
        val book = bookRepository.book()
        require(book.productID == productID) { "legacy import book belongs to a different product" }
        require(book.editionID == editionID) { "legacy import book belongs to a different edition" }

        var mappedCount = 0
        var unresolvedCount = 0
        var invalidCount = 0
        val candidates = LegacyFavoritesMigrationPolicy.userFavorites(
            legacyFavorites = legacyFavorites,
            storedUserFavorites = storedUserFavorites,
            curatedLegacyPaths = curatedLegacyPaths,
        )
        val imported = candidates.mapNotNull { legacyPath ->
            when (
                val resolution = bookRepository.resolveLegacyLocation(
                    legacyPath = legacyPath,
                    usage = LegacyLocationUsage.FAVORITE,
                )
            ) {
                LegacyLocationResolution.Invalid -> {
                    invalidCount += 1
                    null
                }
                LegacyLocationResolution.Unresolved -> {
                    unresolvedCount += 1
                    Favorite.unresolvedLegacy(
                        productID = productID,
                        editionID = editionID,
                        legacyPath = legacyPath,
                        createdAtEpochMilliseconds = importedAtEpochMilliseconds,
                    )
                }
                is LegacyLocationResolution.Mapped -> {
                    mappedCount += 1
                    Favorite.section(
                        productID = productID,
                        editionID = editionID,
                        sectionID = resolution.sectionID,
                        anchorParagraphID = resolution.paragraphID,
                        legacyPath = legacyPath,
                        createdAtEpochMilliseconds = importedAtEpochMilliseconds,
                    )
                }
            }
        }.distinctBy(Favorite::favoriteID)
            .mapIndexed { position, favorite -> favorite.copy(position = position) }

        favoriteRepository.replace(editionID, imported)
        return LegacyFavoritesImportResult(
            storedCount = imported.size,
            mappedCount = mappedCount,
            unresolvedCount = unresolvedCount,
            invalidCount = invalidCount,
        )
    }
}
