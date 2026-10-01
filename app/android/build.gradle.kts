allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Several third-party Flutter plugins pin compile SDK / Java levels that AGP 9
// rejects:
//  - file_picker 8.x and others compile against 34/35, while
//    flutter_plugin_android_lifecycle's AAR metadata demands 36+.
// compileSdk only selects the android.jar a module compiles against (no runtime
// behaviour change), so raise any plugin below the app's compileSdk up to it.
// Registered before the evaluationDependsOn block below so it runs ahead of
// AGP's own afterEvaluate for each plugin project.
subprojects {
    afterEvaluate {
        val library = extensions.findByName("android")
            as? com.android.build.api.dsl.LibraryExtension ?: return@afterEvaluate
        val appAndroid = rootProject.project(":app").extensions.getByName("android")
            as com.android.build.api.dsl.ApplicationExtension
        val appCompileSdk = appAndroid.compileSdk ?: return@afterEvaluate
        if ((library.compileSdk ?: 0) < appCompileSdk) {
            library.compileSdk = appCompileSdk
        }
    }
    // Plugins still on Java 8 make javac warn "source/target value 8 is
    // obsolete" on JDK 21+. That is the plugins' choice; silence the lint.
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
