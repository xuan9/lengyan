package org.fuxuan.lengyan

import android.app.Application
import org.fuxuan.classics.data.repository.AssetContractSource
import org.fuxuan.classics.data.repository.DefaultBookRepository
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.data.persistence.ProductPersistenceFactory

class LengyanApplication : Application() {
    val container: LengyanAppContainer by lazy(LazyThreadSafetyMode.NONE) {
        val persistence = ProductPersistenceFactory.create(
            context = this,
            productID = PRODUCT_ID,
            defaults = ProductPreferenceDefaults(
                locale = "zh-Hant",
                supportedLocales = setOf("zh-Hant", "zh-Hans"),
            ),
        )
        LengyanAppContainer(
            bookRepository = DefaultBookRepository(
                source = AssetContractSource(
                    assetManager = assets,
                    productAssetRoot = "classics/$PRODUCT_ID",
                ),
            ),
            userPreferencesRepository = persistence.userPreferencesRepository,
            favoriteRepository = persistence.favoriteRepository,
        )
    }

    private companion object {
        const val PRODUCT_ID = "lengyan"
    }
}
