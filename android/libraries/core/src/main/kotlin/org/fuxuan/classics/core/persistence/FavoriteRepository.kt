package org.fuxuan.classics.core.persistence

import kotlinx.coroutines.flow.Flow

enum class FavoriteTargetKind {
    SECTION,
    PARAGRAPH,
    UNRESOLVED_LEGACY,
}

data class Favorite(
    val favoriteID: String,
    val productID: String,
    val editionID: String,
    val targetKind: FavoriteTargetKind,
    val sectionID: String?,
    val paragraphID: String?,
    val legacyPath: String?,
    val position: Int,
    val createdAtEpochMilliseconds: Long,
) {
    init {
        require(favoriteID.isNotBlank()) { "favoriteID must not be blank" }
        require(productID.isNotBlank()) { "favorite productID must not be blank" }
        require(editionID.isNotBlank()) { "favorite editionID must not be blank" }
        require(legacyPath == null || legacyPath.isNotBlank()) {
            "favorite legacy path must not be blank"
        }
        require(position >= 0) { "favorite position must not be negative" }
        require(createdAtEpochMilliseconds >= 0) { "favorite timestamp must not be negative" }
        when (targetKind) {
            FavoriteTargetKind.SECTION -> {
                require(!sectionID.isNullOrBlank()) { "section favorite requires sectionID" }
                require(paragraphID == null || paragraphID.isNotBlank()) {
                    "section favorite anchor paragraph must not be blank"
                }
            }
            FavoriteTargetKind.PARAGRAPH -> {
                require(!sectionID.isNullOrBlank()) { "paragraph favorite requires sectionID" }
                require(!paragraphID.isNullOrBlank()) { "paragraph favorite requires paragraphID" }
            }
            FavoriteTargetKind.UNRESOLVED_LEGACY -> {
                require(sectionID == null && paragraphID == null) {
                    "unresolved legacy favorite cannot contain stable IDs"
                }
                require(!legacyPath.isNullOrBlank()) {
                    "unresolved legacy favorite requires its original path"
                }
            }
        }
    }

    companion object {
        fun section(
            productID: String,
            editionID: String,
            sectionID: String,
            anchorParagraphID: String? = null,
            legacyPath: String? = null,
            position: Int = 0,
            createdAtEpochMilliseconds: Long,
        ) = Favorite(
            favoriteID = "section:$sectionID",
            productID = productID,
            editionID = editionID,
            targetKind = FavoriteTargetKind.SECTION,
            sectionID = sectionID,
            paragraphID = anchorParagraphID,
            legacyPath = legacyPath,
            position = position,
            createdAtEpochMilliseconds = createdAtEpochMilliseconds,
        )

        fun paragraph(
            productID: String,
            editionID: String,
            sectionID: String,
            paragraphID: String,
            legacyPath: String? = null,
            position: Int = 0,
            createdAtEpochMilliseconds: Long,
        ) = Favorite(
            favoriteID = "paragraph:$paragraphID",
            productID = productID,
            editionID = editionID,
            targetKind = FavoriteTargetKind.PARAGRAPH,
            sectionID = sectionID,
            paragraphID = paragraphID,
            legacyPath = legacyPath,
            position = position,
            createdAtEpochMilliseconds = createdAtEpochMilliseconds,
        )

        fun unresolvedLegacy(
            productID: String,
            editionID: String,
            legacyPath: String,
            position: Int = 0,
            createdAtEpochMilliseconds: Long,
        ) = Favorite(
            favoriteID = "legacy:$legacyPath",
            productID = productID,
            editionID = editionID,
            targetKind = FavoriteTargetKind.UNRESOLVED_LEGACY,
            sectionID = null,
            paragraphID = null,
            legacyPath = legacyPath,
            position = position,
            createdAtEpochMilliseconds = createdAtEpochMilliseconds,
        )
    }
}

interface FavoriteRepository {
    fun favorites(editionID: String): Flow<List<Favorite>>

    suspend fun add(favorite: Favorite): Boolean

    suspend fun remove(editionID: String, favoriteID: String): Boolean

    suspend fun replace(editionID: String, favorites: List<Favorite>)
}
