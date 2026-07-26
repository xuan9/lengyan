plugins {
    id("classics.android.library")
    id("classics.android.room")
    id("classics.kotlin.serialization")
}

android {
    namespace = "org.fuxuan.classics.data"

    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets {
        getByName("androidTest").assets.directories.add(
            rootProject.layout.projectDirectory
                .dir("../Contracts/BehaviorFixtures")
                .asFile
                .absolutePath,
        )
    }

    testOptions {
        managedDevices {
            localDevices {
                create("compactPhoneApi35") {
                    device = "Nexus 5"
                    apiLevel = 35
                    systemImageSource = "aosp-atd"
                }
            }
        }
    }
}

dependencies {
    api(project(":libraries:core"))
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.room.runtime)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    ksp(libs.androidx.room.compiler)
    androidTestImplementation(libs.androidx.room.testing)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    testImplementation(libs.junit)
}

tasks.withType<Test>().configureEach {
    systemProperty(
        "classics.repositoryRoot",
        rootProject.layout.projectDirectory.dir("..").asFile.absolutePath,
    )
}
