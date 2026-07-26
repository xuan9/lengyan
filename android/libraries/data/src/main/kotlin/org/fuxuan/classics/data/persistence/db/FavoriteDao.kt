package org.fuxuan.classics.data.persistence.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
internal abstract class FavoriteDao {
    @Query(
        """
        SELECT * FROM favorites
        WHERE product_id = :productID AND edition_id = :editionID
        ORDER BY position ASC, created_at_epoch_ms DESC, favorite_id ASC
        """,
    )
    abstract fun observe(productID: String, editionID: String): Flow<List<FavoriteEntity>>

    @Query(
        """
        SELECT * FROM favorites
        WHERE product_id = :productID AND edition_id = :editionID AND favorite_id = :favoriteID
        LIMIT 1
        """,
    )
    protected abstract suspend fun find(
        productID: String,
        editionID: String,
        favoriteID: String,
    ): FavoriteEntity?

    @Query(
        """
        UPDATE favorites SET position = position + 1
        WHERE product_id = :productID AND edition_id = :editionID
        """,
    )
    protected abstract suspend fun makeRoomAtFront(productID: String, editionID: String)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    protected abstract suspend fun insert(entity: FavoriteEntity)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    protected abstract suspend fun insertAll(entities: List<FavoriteEntity>)

    @Query(
        """
        DELETE FROM favorites
        WHERE product_id = :productID AND edition_id = :editionID AND favorite_id = :favoriteID
        """,
    )
    protected abstract suspend fun delete(
        productID: String,
        editionID: String,
        favoriteID: String,
    ): Int

    @Query(
        """
        UPDATE favorites SET position = position - 1
        WHERE product_id = :productID AND edition_id = :editionID AND position > :removedPosition
        """,
    )
    protected abstract suspend fun closePositionGap(
        productID: String,
        editionID: String,
        removedPosition: Int,
    )

    @Query("DELETE FROM favorites WHERE product_id = :productID AND edition_id = :editionID")
    protected abstract suspend fun deleteEdition(productID: String, editionID: String)

    @Transaction
    open suspend fun addAtFront(entity: FavoriteEntity): Boolean {
        if (find(entity.productID, entity.editionID, entity.favoriteID) != null) return false
        makeRoomAtFront(entity.productID, entity.editionID)
        insert(entity.copy(position = 0))
        return true
    }

    @Transaction
    open suspend fun remove(
        productID: String,
        editionID: String,
        favoriteID: String,
    ): Boolean {
        val existing = find(productID, editionID, favoriteID) ?: return false
        delete(productID, editionID, favoriteID)
        closePositionGap(productID, editionID, existing.position)
        return true
    }

    @Transaction
    open suspend fun replaceEdition(
        productID: String,
        editionID: String,
        entities: List<FavoriteEntity>,
    ) {
        deleteEdition(productID, editionID)
        if (entities.isNotEmpty()) insertAll(entities)
    }
}
