plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.data"
}

dependencies {
    api(project(":libraries:core"))
}
