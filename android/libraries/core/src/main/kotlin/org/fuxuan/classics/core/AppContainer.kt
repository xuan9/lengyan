package org.fuxuan.classics.core

import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.core.persistence.UserPreferencesRepository

interface AppContainer {
    val product: ProductIdentity
    val bookRepository: BookRepository
    val userPreferencesRepository: UserPreferencesRepository
    val favoriteRepository: FavoriteRepository
}
