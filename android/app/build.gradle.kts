import java.io.FileInputStream
import java.util.Properties
import java.util.Base64
import java.net.URI

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Explicit opt-in only; ordinary debug/release builds retain their identity.
val qaSandboxBuild = providers.gradleProperty("attendQa").orNull == "true"

android {
    namespace = "com.zbooma.elabqrihr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.zbooma.elabqrihr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrEmpty()) {
                    storeFile = file(storeFilePath)
                }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            if (qaSandboxBuild) {
                applicationIdSuffix = ".qa"
                versionNameSuffix = "-qa"
            }
        }
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Debug key fallback is prohibited for release builds.
        }
    }

    if (qaSandboxBuild) {
        sourceSets.getByName("debug").manifest.srcFile("src/qa/AndroidManifest.xml")
    }

    firebaseCrashlytics {
        // Mapping upload is limited to signed release builds. Collection remains
        // disabled in AndroidManifest until the release build opts in explicitly.
        mappingFileUploadEnabled = !qaSandboxBuild
    }

    gradle.taskGraph.whenReady {
        val hasReleaseTask = allTasks.any { it.name.contains("Release", ignoreCase = true) }
        if (qaSandboxBuild) {
            check(!hasReleaseTask) { "QA sandbox is debug-only and cannot produce a store release" }
            val defines = (project.findProperty("dart-defines") as? String ?: "")
                .split(',').filter { it.isNotBlank() }
                .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
                .associate { it.substringBefore('=') to it.substringAfter('=', "") }
            check(defines["ATTEND_QA_SANDBOX"] == "true") { "QA APK requires its runtime sandbox guard" }
            val target = URI(defines["API_BASE_URL"] ?: "")
            check(target.host in listOf("127.0.0.1", "localhost", "10.0.2.2") && target.scheme in listOf("http", "https") && target.userInfo == null) {
                "QA APK must point to the local sandbox"
            }
        }
        if (hasReleaseTask && !keystorePropertiesFile.exists()) {
            throw GradleException(
                "Production release builds require mobile/android/key.properties and a valid keystore. " +
                "Falling back to debug signing is strictly prohibited."
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.play:integrity:1.6.0")
    implementation("androidx.work:work-runtime-ktx:2.12.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.2.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.work:work-testing:2.12.0")
    androidTestImplementation("com.google.guava:guava:28.1-android")
}

flutter {
    source = "../.."
}

// `integration_test` is a Flutter dev dependency. Flutter may add its Android
// registrant entry after `flutter pub get`, but the plugin is intentionally not
// packaged in a Play release. Keep test instrumentation available for debug
// builds while removing only that generated entry just before release Java is
// compiled.
tasks.configureEach {
    if (qaSandboxBuild && name.endsWith("GoogleServices")) enabled = false
    if (name == "compileReleaseJavaWithJavac") doFirst {
        val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        if (!registrant.exists()) return@doFirst

        val integrationTestBlock = Regex(
            """(?s)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s*\}""",
        )
        registrant.writeText(
            integrationTestBlock.replace(registrant.readText(), "\n"),
        )
    }
}
