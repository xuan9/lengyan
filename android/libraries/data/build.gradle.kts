plugins {
    id("classics.android.library")
    id("classics.kotlin.serialization")
}

android {
    namespace = "org.fuxuan.classics.data"
}

dependencies {
    api(project(":libraries:core"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    testImplementation(libs.junit)
}

tasks.withType<Test>().configureEach {
    systemProperty(
        "classics.repositoryRoot",
        rootProject.layout.projectDirectory.dir("..").asFile.absolutePath,
    )
}
