package org.fuxuan.classics.buildlogic

import org.gradle.api.file.DirectoryProperty
import org.gradle.api.provider.Property

abstract class ProductAssetsExtension {
    abstract val productID: Property<String>
    abstract val productDirectory: DirectoryProperty
}
