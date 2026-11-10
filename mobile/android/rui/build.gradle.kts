// The RUI runtime for an Android app: RuiActivity, and the RUI program itself
// as jniLibs/<abi>/libmain.so with its fonts in assets/ (both put there by
// ../build_rui.sh). Java, not Kotlin, so it builds unchanged inside any host
// project whatever that project's Kotlin setup is (a Flutter app's, say).
plugins {
    id("com.android.library")
}

android {
    namespace = "dev.rui.android"
    compileSdk = 36
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
