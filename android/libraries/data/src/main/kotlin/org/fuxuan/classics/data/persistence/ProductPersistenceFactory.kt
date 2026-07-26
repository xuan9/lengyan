package org.fuxuan.classics.data.persistence

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.core.persistence.UserPreferencesRepository
import org.fuxuan.classics.data.persistence.db.ClassicsUserDatabase
import org.fuxuan.classics.data.persistence.db.RoomFavoriteRepository
import org.fuxuan.classics.data.persistence.preferences.DefaultUserPreferencesRepository
import org.fuxuan.classics.data.persistence.preferences.ProductDataStoreFactory

class ProductPersistence internal constructor(
    val userPreferencesRepository: UserPreferencesRepository,
    val favoriteRepository: FavoriteRepository,
    private val closeResources: () -> Unit,
) : AutoCloseable {
    override fun close() = closeResources()
}

object ProductPersistenceFactory {
    fun create(
        context: Context,
        productID: String,
        defaults: ProductPreferenceDefaults,
    ): ProductPersistence {
        require(PRODUCT_ID_PATTERN.matches(productID)) {
            "productID must be a stable lowercase slug"
        }
        val appContext = context.applicationContext
        val dataStoreScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        val database = Room.databaseBuilder(
            appContext,
            ClassicsUserDatabase::class.java,
            "classics-$productID.db",
        ).build()
        return ProductPersistence(
            userPreferencesRepository = DefaultUserPreferencesRepository(
                productID = productID,
                defaults = defaults,
                dataStore = ProductDataStoreFactory.create(appContext, productID, dataStoreScope),
            ),
            favoriteRepository = RoomFavoriteRepository(productID, database.favoriteDao()),
            closeResources = {
                database.close()
                dataStoreScope.cancel()
            },
        )
    }

    private val PRODUCT_ID_PATTERN = Regex("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
}
