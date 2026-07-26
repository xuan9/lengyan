plugins {
    `kotlin-dsl`
}

group = "org.fuxuan.classics.buildlogic"

kotlin {
    jvmToolchain(17)
}

dependencyLocking {
    lockAllConfigurations()
}

dependencies {
    implementation(libs.android.gradle.plugin)
    implementation(libs.kotlin.gradle.plugin)
    implementation(libs.kotlin.compose.gradle.plugin)
    implementation(libs.kotlin.serialization.gradle.plugin)
    implementation(libs.androidx.room.gradle.plugin)
    implementation(libs.ksp.gradle.plugin)
}
