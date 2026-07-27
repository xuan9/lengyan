plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.media"
}

dependencies {
    api(project(":libraries:core"))
    api(libs.androidx.media3.session)
    implementation(libs.androidx.media3.exoplayer)
    testImplementation(libs.junit)
}
