package org.fuxuan.classics.data.persistence.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index

@Entity(
    tableName = "favorites",
    primaryKeys = ["product_id", "edition_id", "favorite_id"],
    indices = [Index(value = ["product_id", "edition_id", "position"])],
)
internal data class FavoriteEntity(
    @ColumnInfo(name = "product_id")
    val productID: String,
    @ColumnInfo(name = "edition_id")
    val editionID: String,
    @ColumnInfo(name = "favorite_id")
    val favoriteID: String,
    @ColumnInfo(name = "target_kind")
    val targetKind: String,
    @ColumnInfo(name = "section_id")
    val sectionID: String?,
    @ColumnInfo(name = "paragraph_id")
    val paragraphID: String?,
    @ColumnInfo(name = "legacy_path")
    val legacyPath: String?,
    val position: Int,
    @ColumnInfo(name = "created_at_epoch_ms")
    val createdAtEpochMilliseconds: Long,
)
