import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
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
    // Flutter's NDK (28.2.13676358 for 3.47) — every plugin requires it.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
        // Patrol's instrumentation runner — required by `patrol test`.
        // clearPackageData wipes app storage between tests so the on-device
        // database and secure storage do not leak state across them.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// sqlcipher_flutter_libs 0.5.x pulls net.zetetic:android-database-sqlcipher,
// whose libsqlcipher.so has 4 KB-aligned LOAD segments. Devices with 16 KB
// pages refuse to run it natively, and Play requires 16 KB support — it is the
// only library in a release build of this app that is not already aligned.
//
// The plugin's 0.6.x line does this swap itself, but it also moves the Apple
// podspec to SQLCipher 4.10, and this app resolves sqlite3 symbols with
// `source: process` (app/pubspec.yaml): with that pod the symbols stop being
// reachable and the database cannot open. Doing it here keeps the fix on the
// platform that needs it.
//
// Safe because nothing in this app touches the AAR's Java API. The plugin
// exists so System.loadLibrary("sqlcipher") works and Dart dlopens the
// library; the replacement ships the same libsqlcipher.so, exporting the same
// sqlite3_* symbols.
configurations.configureEach {
    resolutionStrategy.dependencySubstitution {
        substitute(module("net.zetetic:android-database-sqlcipher"))
            .using(module("net.zetetic:sqlcipher-android:4.10.0"))
            .because("16 KB page alignment; the old artifact is end-of-line at 4.5.4")
    }
}
