package org.fuxuan.classics.data.persistence.db

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.core.persistence.FavoriteTargetKind

internal class RoomFavoriteRepository(
    private val productID: String,
    private val dao: FavoriteDao,
) : FavoriteRepository {
    override fun favorites(editionID: String): Flow<List<Favorite>> {
        require(editionID.isNotBlank()) { "favorite editionID must not be blank" }
        return dao.observe(productID, editionID).map { entities -> entities.map(FavoriteEntity::toDomain) }
    }

    override suspend fun add(favorite: Favorite): Boolean {
        require(favorite.productID == productID) { "favorite belongs to a different product" }
        return dao.addAtFront(favorite.toEntity())
    }

    override suspend fun remove(editionID: String, favoriteID: String): Boolean {
        require(editionID.isNotBlank()) { "favorite editionID must not be blank" }
        require(favoriteID.isNotBlank()) { "favoriteID must not be blank" }
        return dao.remove(productID, editionID, favoriteID)
    }

    override suspend fun replace(editionID: String, favorites: List<Favorite>) {
        require(editionID.isNotBlank()) { "favorite editionID must not be blank" }
        require(favorites.all { it.productID == productID && it.editionID == editionID }) {
            "replacement favorites belong to a different product or edition"
        }
        require(favorites.map(Favorite::favoriteID).toSet().size == favorites.size) {
            "replacement favorite IDs must be unique"
        }
        dao.replaceEdition(
            productID = productID,
            editionID = editionID,
            entities = favorites.mapIndexed { position, favorite ->
                favorite.copy(position = position).toEntity()
            },
        )
    }
}

private fun Favorite.toEntity() = FavoriteEntity(
    productID = productID,
    editionID = editionID,
    favoriteID = favoriteID,
    targetKind = targetKind.name,
    sectionID = sectionID,
    paragraphID = paragraphID,
    legacyPath = legacyPath,
    position = position,
    createdAtEpochMilliseconds = createdAtEpochMilliseconds,
)

private fun FavoriteEntity.toDomain() = Favorite(
    favoriteID = favoriteID,
    productID = productID,
    editionID = editionID,
    targetKind = FavoriteTargetKind.valueOf(targetKind),
    sectionID = sectionID,
    paragraphID = paragraphID,
    legacyPath = legacyPath,
    position = position,
    createdAtEpochMilliseconds = createdAtEpochMilliseconds,
)
