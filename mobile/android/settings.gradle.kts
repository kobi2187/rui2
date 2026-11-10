// RUI on Android: the `rui` library (RuiActivity + the RUI program as
// libmain.so, built by build_rui.sh) and a plain Kotlin app that uses it.
// The Flutter mockups app (mobile/mockups/flutter/android) includes `rui` too.
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
    }
}
rootProject.name = "rui-android"
include(":rui", ":kotlin-host")
