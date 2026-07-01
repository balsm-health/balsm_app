plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
