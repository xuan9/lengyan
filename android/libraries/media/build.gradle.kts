plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.media"
}

dependencies {
    api(project(":libraries:core"))
}
