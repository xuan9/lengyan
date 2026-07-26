package org.fuxuan.classics.core.behavior

object LegacyFavoritesMigrationPolicy {
    fun userFavorites(
        legacyFavorites: List<String>,
        storedUserFavorites: List<String>?,
        curatedLegacyPaths: Set<String>,
    ): List<String> {
        val source = storedUserFavorites
            ?: legacyFavorites.filterNot(curatedLegacyPaths::contains)
        return source.distinct()
    }
}
