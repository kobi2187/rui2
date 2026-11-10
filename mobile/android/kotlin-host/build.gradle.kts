// A plain Kotlin Android app (no Flutter, no Compose) that opens RUI screens:
// the smallest integration of RUI into an existing Kotlin project.
plugins {
    id("com.android.application")
}

android {
    namespace = "dev.rui.kotlinhost"
    compileSdk = 36
    defaultConfig {
        applicationId = "dev.rui.kotlinhost"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true   // Robolectric sees the merged manifest and assets
    }
}

dependencies {
    implementation(project(":rui"))
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("androidx.test:core:1.7.0")
}

// Robolectric would download its Android framework jar (android-all) itself, at
// test time, outside Gradle's cache and retries. Fetch it as a dependency
// instead and run Robolectric offline against it. The version is the one
// Robolectric 4.17 wants for SDK 36; it names it in the error if it changes.
val robolectricRuntime: Configuration by configurations.creating { isTransitive = false }
dependencies {
    robolectricRuntime("org.robolectric:android-all-instrumented:16-robolectric-13921718-i7")
}
val robolectricJars = tasks.register<Copy>("robolectricJars") {
    from(robolectricRuntime)
    into(layout.buildDirectory.dir("robolectric-jars"))
}
tasks.withType<Test>().configureEach {
    dependsOn(robolectricJars)
    // Robolectric reaches into FileDescriptor through JDK internals; JDK 17+
    // forbids it unless they are opened to it.
    jvmArgs("--add-opens=java.base/java.io=ALL-UNNAMED",
            "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED")
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir",
                   layout.buildDirectory.dir("robolectric-jars").get().asFile.absolutePath)
}
