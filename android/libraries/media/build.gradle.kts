plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.media"
}

dependencies {
    api(project(":libraries:core"))
    api(libs.androidx.media3.exoplayer)
    api(libs.androidx.media3.session)
    testImplementation(libs.junit)
}
