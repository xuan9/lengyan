plugins {
    id("classics.android.application")
    id("classics.android.compose")
}

android {
    namespace = "org.fuxuan.lengyan"

    defaultConfig {
        applicationId = "org.fuxuan.lengyan"
        versionCode = 1
        versionName = "0.1.0"
    }
}

dependencies {
    implementation(project(":libraries:core"))
    implementation(project(":libraries:data"))
    implementation(project(":libraries:ui"))
    implementation(project(":libraries:media"))
    implementation(project(":libraries:widget"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)

    testImplementation(libs.junit)
}
