import com.android.build.api.dsl.CommonExtension
import org.gradle.kotlin.dsl.configure

plugins {
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

extensions.configure<CommonExtension> {
    buildFeatures.compose = true
}
