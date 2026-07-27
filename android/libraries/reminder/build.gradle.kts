plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.reminder"
}

dependencies {
    api(project(":libraries:core"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
}
