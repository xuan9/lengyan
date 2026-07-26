package org.fuxuan.lengyan

import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.ProductIdentity
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.core.persistence.UserPreferencesRepository

class LengyanAppContainer(
    override val bookRepository: BookRepository,
    override val userPreferencesRepository: UserPreferencesRepository,
    override val favoriteRepository: FavoriteRepository,
) : AppContainer {
    override val product = ProductIdentity(
        productID = "lengyan",
        displayName = "楞严经",
        canonicalTitle = "大佛顶首楞严经",
    )
}
