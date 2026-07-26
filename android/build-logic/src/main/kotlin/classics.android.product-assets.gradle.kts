import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.fuxuan.classics.buildlogic.ProductAssetsExtension
import org.fuxuan.classics.buildlogic.StageProductAssetsTask
import org.gradle.kotlin.dsl.configure

val productAssets = extensions.create<ProductAssetsExtension>("classicsProductAssets")

val stageProductAssets = tasks.register<StageProductAssetsTask>("stageProductAssets") {
    productID.set(productAssets.productID)
    productDirectory.set(productAssets.productDirectory)
    outputDirectory.set(layout.buildDirectory.dir("generated/classics/assets"))
}

plugins.withId("com.android.application") {
    extensions.configure<ApplicationAndroidComponentsExtension> {
        onVariants { variant ->
            variant.sources.assets?.addGeneratedSourceDirectory(
                stageProductAssets,
                StageProductAssetsTask::outputDirectory,
            )
        }
    }
}
