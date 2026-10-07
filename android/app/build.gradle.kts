plugins {
    id("com.android.application")
}

android {
    namespace = "io.appwrite.pushusage"
    compileSdk = 37

    defaultConfig {
        applicationId = "io.appwrite.pushusage.android"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("com.github.appwrite:sdk-for-android:29.1.0-rc.3")
    implementation("androidx.appcompat:appcompat:1.8.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.0")
}
