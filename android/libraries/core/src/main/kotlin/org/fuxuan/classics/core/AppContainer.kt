package org.fuxuan.classics.core

import org.fuxuan.classics.core.content.BookRepository

interface AppContainer {
    val product: ProductIdentity
    val bookRepository: BookRepository
}
