plugins {
    id("classics.android.application")
}

android {
    namespace = "org.fuxuan.classics.media.harness"

    defaultConfig {
        applicationId = "org.fuxuan.classics.media.harness"
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
    implementation(project(":libraries:media"))

    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
}
