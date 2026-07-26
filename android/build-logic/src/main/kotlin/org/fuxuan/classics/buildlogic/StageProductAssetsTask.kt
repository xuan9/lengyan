package org.fuxuan.classics.buildlogic

import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.FileSystemOperations
import org.gradle.api.provider.Property
import org.gradle.api.tasks.CacheableTask
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File
import javax.inject.Inject

@CacheableTask
abstract class StageProductAssetsTask : DefaultTask() {
    @get:Input
    abstract val productID: Property<String>

    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val productDirectory: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @get:Inject
    abstract val fileSystemOperations: FileSystemOperations

    @TaskAction
    fun stageAssets() {
        val expectedProductID = productID.get()
        require(PRODUCT_ID_PATTERN.matches(expectedProductID)) {
            "productID must be a stable lowercase slug"
        }

        val sourceDirectory = productDirectory.get().asFile
        val product = readObject(sourceDirectory.resolve(PRODUCT_MANIFEST))
        require(product.string("productID") == expectedProductID) {
            "product.json does not describe $expectedProductID"
        }

        val runtimePaths = linkedSetOf(PRODUCT_MANIFEST)
        val manifests = product.objectValue("manifests")
        val bookPath = manifests.relativePath("book")
        runtimePaths += bookPath
        runtimePaths += manifests.relativePath("source")
        manifests.optionalRelativePath("audio")?.let(runtimePaths::add)

        val book = readObject(sourceDirectory.resolve(bookPath))
        require(book.string("productID") == expectedProductID) {
            "$bookPath does not describe $expectedProductID"
        }
        book.optionalObjectValue("contentPackages")
            ?.values
            ?.forEach { runtimePaths += relativePath(it, "contentPackages") }
        book.optionalObjectValue("legacyCompatibility")
            ?.optionalRelativePath("mappingArtifact")
            ?.let(runtimePaths::add)

        product.objectValue("platforms")
            .objectValue("android")
            .optionalRelativePath("audioDelivery")
            ?.let(runtimePaths::add)

        val canonicalSourceDirectory = sourceDirectory.canonicalFile
        val runtimeFiles = runtimePaths.associateWith { relativePath ->
            val source = canonicalSourceDirectory.resolve(relativePath).canonicalFile
            require(source.toPath().startsWith(canonicalSourceDirectory.toPath())) {
                "runtime product asset escapes its product directory: $relativePath"
            }
            require(source.isFile) { "runtime product asset does not exist: $relativePath" }
            source
        }

        val destination = outputDirectory.get().dir("classics/$expectedProductID")
        fileSystemOperations.sync {
            into(destination)
            runtimeFiles.forEach { (relativePath, source) ->
                from(source) {
                    relativePath.substringBeforeLast('/', missingDelimiterValue = "")
                        .takeIf(String::isNotEmpty)
                        ?.let(::into)
                }
            }
        }
    }

    private fun readObject(file: File): Map<*, *> {
        require(file.isFile) { "product contract does not exist: ${file.name}" }
        return JsonSlurper().parse(file) as? Map<*, *>
            ?: error("product contract must be a JSON object: ${file.name}")
    }

    private fun Map<*, *>.string(key: String): String =
        this[key] as? String ?: error("$key must be a string")

    private fun Map<*, *>.objectValue(key: String): Map<*, *> =
        this[key] as? Map<*, *> ?: error("$key must be an object")

    private fun Map<*, *>.optionalObjectValue(key: String): Map<*, *>? =
        this[key]?.let { it as? Map<*, *> ?: error("$key must be an object") }

    private fun Map<*, *>.relativePath(key: String): String =
        relativePath(this[key], key)

    private fun Map<*, *>.optionalRelativePath(key: String): String? =
        this[key]?.let { relativePath(it, key) }

    private fun relativePath(value: Any?, label: String): String {
        val path = value as? String ?: error("$label must be a string")
        val segments = path.split('/')
        require(
            path.isNotBlank() &&
                !path.startsWith('/') &&
                '\\' !in path &&
                segments.all { it.isNotBlank() && it != "." && it != ".." },
        ) {
            "$label must be a safe product-relative path"
        }
        return path
    }

    private companion object {
        const val PRODUCT_MANIFEST = "product.json"
        val PRODUCT_ID_PATTERN = Regex("^[a-z][a-z0-9-]{1,63}$")
    }
}
