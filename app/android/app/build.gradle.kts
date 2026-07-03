import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by `android/key.properties`, which CI writes from
// secrets (ANDROID_KEYSTORE_BASE64, ANDROID_KEY_ALIAS, …). It is never
// committed — see docs/ci-secrets.md. When absent (local dev, unsigned CI),
// the release build falls back to the debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "health.balsm.app"
    compileSdk = flutter.compileSdkVersion
    // Pinned to the locally-installed intact NDK (the SDK's 28.2.x was corrupt).
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Installed package / store id. Kept distinct from `namespace` above
        // (the code/R package, which matches MainActivity.kt's location).
        applicationId = "app.balsm.health"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Single Balsm patient build (no product flavors) — manifest
        // placeholders are fixed here instead of per-flavor.
        manifestPlaceholders["appNameSuffix"] = ""
        manifestPlaceholders["BASE_URL"] = "app.balsm.health"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when CI provisioned key.properties;
            // otherwise fall back to the debug key so `flutter run --release`
            // and unsigned CI builds still work.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Single product flavor — the Balsm patient app (run with `--flavor balsm`).
    flavorDimensions += "app"
    productFlavors {
        create("balsm") {
            dimension = "app"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
