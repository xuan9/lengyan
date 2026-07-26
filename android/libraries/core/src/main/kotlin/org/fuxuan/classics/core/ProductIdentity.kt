package org.fuxuan.classics.core

private val productIDPattern = Regex("^[a-z][a-z0-9-]{1,63}$")

data class ProductIdentity(
    val productID: String,
    val displayName: String,
    val canonicalTitle: String,
) {
    init {
        require(productIDPattern.matches(productID)) {
            "productID must be a stable lowercase slug"
        }
        require(displayName.isNotBlank()) { "displayName must not be blank" }
        require(canonicalTitle.isNotBlank()) { "canonicalTitle must not be blank" }
    }
}
