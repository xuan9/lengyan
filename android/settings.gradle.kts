pluginManagement {
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "ClassicsAndroid"

include(":apps:lengyan")
include(":benchmark:lengyan")
include(":libraries:core")
include(":libraries:data")
include(":libraries:ui")
include(":libraries:media")
include(":libraries:widget")
