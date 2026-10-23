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

    // The app is Arabic and English only. Libraries ship strings in eighty-odd
    // languages; without this they are all packaged, and Play lists every one
    // of them as a language the app supports.
    androidResources {
        localeFilters += listOf("en", "ar")
    }

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
            // R8: rename and shrink the Java/Kotlin side, and drop unused
            // resources. Flutter turns these on for release builds by default;
            // stated here so a change of default, or a `--no-shrink` passed by
            // hand, cannot ship readable class names. The build tool also
            // refuses a production build that R8 did not run on.
            isMinifyEnabled = true
            isShrinkResources = true
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
// CI probe: a native-only change must rebuild without re-analyzing.
