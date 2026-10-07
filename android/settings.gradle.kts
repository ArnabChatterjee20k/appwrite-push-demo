pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        // Release candidates of the Android SDK are published on JitPack.
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "appwrite-push-android"
include(":app")
