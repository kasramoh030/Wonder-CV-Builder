import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ─────────────────────────────────────────────────────────
//
// The keystore and its passwords are never in the repository. Two sources are
// accepted, in this order:
//
//   1. environment variables — what CI uses, fed from GitHub Secrets:
//        ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
//        ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
//   2. android/key.properties — what a developer machine uses (git-ignored):
//        storeFile=/absolute/path/to/upload-keystore.jks
//        storePassword=...
//        keyAlias=upload
//        keyPassword=...
//
// See docs/RELEASE.md for how to create the keystore and set the secrets.
val keystoreProperties = Properties()
val keystorePropertiesFile: File = rootProject.file("key.properties")
val hasKeyProperties: Boolean = keystorePropertiesFile.exists()
if (hasKeyProperties) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(envName: String, propertyName: String): String? =
    (System.getenv(envName) ?: keystoreProperties.getProperty(propertyName))
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile: String? = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword: String? = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias: String? = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword: String? = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")

val hasReleaseSigning: Boolean = releaseStoreFile != null &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

if (!hasReleaseSigning) {
    // Deliberately loud. A release build that silently falls back to the debug
    // key is how an app reaches a store signed by a key that is not yours and
    // can never be updated again.
    logger.warn(
        "Wonder CV Builder: no release signing configuration found. " +
            "Release builds will be signed with the DEBUG key and cannot be " +
            "published. Set ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / " +
            "ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD, or android/key.properties. " +
            "See docs/RELEASE.md."
    )
}

android {
    namespace = "dev.cvpro.builder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.cvpro.builder"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Version comes from pubspec.yaml (`version: x.y.z+n`); a store build
        // must never depend on a number typed in two places.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                // v1 for API 17–23 devices, v2 for 24+, v3 for 28+. The
                // package manager picks the strongest the device understands.
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            // R8 minification and resource shrinking are enabled for release
            // by the Flutter Gradle plugin (it passes -Pshrink=true, and
            // declines it only for multi-APK builds where shrinking is not
            // allowed). The keep rules that the plugins in this project need
            // live in android/app/proguard-rules.pro, which the plugin picks
            // up automatically.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
