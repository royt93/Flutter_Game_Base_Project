import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Single local, gitignored file for this app's sensitive config (release
// signing today, any future ad-SDK keys later) — see app.properties.example.
val appProperties = Properties()
val appPropertiesFile = rootProject.file("app.properties")
if (appPropertiesFile.exists()) {
    appPropertiesFile.inputStream().use { appProperties.load(it) }
}

android {
    namespace = "com.galaxyjoy.roycasualkit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // I56: flutter_local_notifications yêu cầu core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.galaxyjoy.roycasualkit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = appProperties.getProperty("KEYSTORE_PATH")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
            }
            storePassword = appProperties.getProperty("KS_PW") ?: ""
            keyAlias = appProperties.getProperty("KS_ALIAS") ?: ""
            keyPassword = appProperties.getProperty("KS_PW") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Fail fast (before compile) when a release build is requested without the
// private signing config. Debug builds never reach this. Only key NAMES are
// reported, never values.
gradle.taskGraph.whenReady {
    if (allTasks.none { it.name == "packageRelease" || it.name == "packageReleaseBundle" }) return@whenReady
    val missing = listOf("KEYSTORE_PATH", "KS_ALIAS", "KS_PW")
        .filter { appProperties.getProperty(it).isNullOrBlank() }
    val keystoreMissing = missing.isEmpty() &&
        !file(appProperties.getProperty("KEYSTORE_PATH")).exists()
    if (missing.isNotEmpty() || keystoreMissing) {
        throw GradleException(
            "Release signing not configured. " +
                (if (missing.isNotEmpty()) "Missing in example/android/app.properties: ${missing.joinToString()}. "
                else "KEYSTORE_PATH does not point to an existing file. ") +
                "Copy example/android/app.properties.example to app.properties and fill it in " +
                "(debug builds do not need it)."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // I56: bắt buộc khi bật isCoreLibraryDesugaringEnabled ở trên.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
