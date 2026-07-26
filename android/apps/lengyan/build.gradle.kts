plugins {
    id("classics.android.application")
    id("classics.android.compose")
    id("classics.android.product-assets")
}

classicsProductAssets {
    productID.set("lengyan")
    productDirectory.set(rootProject.layout.projectDirectory.dir("../Products/lengyan"))
}

android {
    namespace = "org.fuxuan.lengyan"

    defaultConfig {
        applicationId = "org.fuxuan.lengyan"
        versionCode = 1
        versionName = "0.1.0"
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
                create("tabletApi35") {
                    device = "Pixel Tablet"
                    apiLevel = 35
                    systemImageSource = "aosp-atd"
                }
            }
        }
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

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.kotlinx.coroutines.core)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    testImplementation(libs.junit)
}
