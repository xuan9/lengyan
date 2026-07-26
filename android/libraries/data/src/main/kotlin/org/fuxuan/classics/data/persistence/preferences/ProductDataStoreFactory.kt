package org.fuxuan.classics.data.persistence.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStoreFile
import kotlinx.coroutines.CoroutineScope

internal object ProductDataStoreFactory {
    fun create(
        context: Context,
        productID: String,
        scope: CoroutineScope,
    ): DataStore<Preferences> {
        require(PRODUCT_ID_PATTERN.matches(productID)) {
            "productID must be a stable lowercase slug"
        }
        return PreferenceDataStoreFactory.create(scope = scope) {
            context.applicationContext.preferencesDataStoreFile("classics-$productID")
        }
    }

    private val PRODUCT_ID_PATTERN = Regex("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
}
