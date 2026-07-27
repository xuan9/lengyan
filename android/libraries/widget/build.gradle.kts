plugins {
    id("classics.android.library")
    id("classics.android.compose")
}

android {
    namespace = "org.fuxuan.classics.widget"
}

dependencies {
    api(project(":libraries:core"))
    api(libs.androidx.glance.appwidget)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
}
