package org.fuxuan.classics.data.persistence.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [FavoriteEntity::class],
    version = 1,
    exportSchema = true,
)
internal abstract class ClassicsUserDatabase : RoomDatabase() {
    abstract fun favoriteDao(): FavoriteDao
}
