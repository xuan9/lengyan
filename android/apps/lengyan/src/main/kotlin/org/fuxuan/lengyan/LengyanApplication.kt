package org.fuxuan.lengyan

import android.app.Application
import org.fuxuan.classics.data.repository.AssetContractSource
import org.fuxuan.classics.data.repository.DefaultBookRepository

class LengyanApplication : Application() {
    val container: LengyanAppContainer by lazy(LazyThreadSafetyMode.NONE) {
        LengyanAppContainer(
            bookRepository = DefaultBookRepository(
                source = AssetContractSource(
                    assetManager = assets,
                    productAssetRoot = "classics/lengyan",
                ),
            ),
        )
    }
}
