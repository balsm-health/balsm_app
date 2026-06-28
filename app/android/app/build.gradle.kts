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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "health.balsm.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    flavorDimensions += "default"
    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appNameSuffix"] = " Dev"
            manifestPlaceholders["BASE_URL"] = "app.balsm.health"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appNameSuffix"] = " Staging"
            manifestPlaceholders["BASE_URL"] = "app.balsm.health"
        }
        create("prod") {
            dimension = "default"
            manifestPlaceholders["appNameSuffix"] = ""
            manifestPlaceholders["BASE_URL"] = "app.balsm.health"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
