plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// storeFile is resolved against this (app) project directory, like the
// signingConfigs block below does.
val hasReleaseSigning =
    keystorePropertiesFile.exists() &&
        keystoreProperties["storeFile"] != null &&
        keystoreProperties["storePassword"] != null &&
        keystoreProperties["keyAlias"] != null &&
        keystoreProperties["keyPassword"] != null &&
        file(keystoreProperties["storeFile"] as String).exists()

android {
    namespace = "com.sentientbeingsoftware.gridmind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    defaultConfig {
        applicationId = "com.sentientbeingsoftware.gridmind"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (
                keystorePropertiesFile.exists() &&
                keystoreProperties["storeFile"] != null &&
                keystoreProperties["storePassword"] != null &&
                keystoreProperties["keyAlias"] != null &&
                keystoreProperties["keyPassword"] != null
            ) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Debug fallback keeps configuration (and debug builds) working;
            // the check below blocks it for real release builds.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Fail only when a release artifact is actually requested without a real
// signing key (CI verification builds are allowed to use the debug key).
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.project == project &&
            Regex("^(assemble|bundle|package)Release").containsMatchIn(it.name)
    }
    if (releaseRequested && !hasReleaseSigning && System.getenv("CI") != "true") {
        throw GradleException(
            "Release signing is not configured: create android/key.properties " +
                "(storeFile, storePassword, keyAlias, keyPassword) and make sure " +
                "storeFile points to an existing keystore (relative to android/app/)."
        )
    }
}

flutter {
    source = "../.."
}
