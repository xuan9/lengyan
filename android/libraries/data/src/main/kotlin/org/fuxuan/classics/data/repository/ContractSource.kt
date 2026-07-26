package org.fuxuan.classics.data.repository

import android.content.res.AssetManager

fun interface ContractSource {
    fun readText(relativePath: String): String
}

class AssetContractSource(
    private val assetManager: AssetManager,
    productAssetRoot: String,
) : ContractSource {
    private val productAssetRoot = safeRelativePath(productAssetRoot)

    override fun readText(relativePath: String): String {
        val path = "$productAssetRoot/${safeRelativePath(relativePath)}"
        return assetManager.open(path).bufferedReader(Charsets.UTF_8).use { it.readText() }
    }
}

internal fun safeRelativePath(path: String): String {
    val segments = path.split('/')
    require(
        path.isNotBlank() &&
            !path.startsWith('/') &&
            '\\' !in path &&
            segments.all { it.isNotBlank() && it != "." && it != ".." },
    ) {
        "contract path must remain relative to its product"
    }
    return path
}
