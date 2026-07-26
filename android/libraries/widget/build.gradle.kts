plugins {
    id("classics.android.library")
}

android {
    namespace = "org.fuxuan.classics.widget"
}

dependencies {
    api(project(":libraries:core"))
}
