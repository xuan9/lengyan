package org.fuxuan.lengyan

import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.ProductIdentity

class LengyanAppContainer : AppContainer {
    override val product = ProductIdentity(
        productID = "lengyan",
        displayName = "楞严经",
        canonicalTitle = "大佛顶首楞严经",
    )
}
