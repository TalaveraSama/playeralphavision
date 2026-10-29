import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local-only credentials. Never fall back to a debug signature for production.
val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.isFile) {
    releasePropertiesFile.reader(Charsets.UTF_8).use { releaseProperties.load(it) }
}
val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = requiredSigningKeys.filter { releaseProperties.getProperty(it).isNullOrBlank() }
val releaseKeystore = releaseProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }?.let { rootProject.file(it) }
val releaseSigningReady = releasePropertiesFile.isFile && missingSigningKeys.isEmpty() &&
    releaseKeystore?.isFile == true

// Covers both Flutter's assembleRelease/bundleRelease and aggregate Gradle tasks.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("release", ignoreCase = true) } &&
        !releaseSigningReady) {
        throw GradleException(
            "Production signing is not configured. Create android/key.properties and a valid " +
                "keystore using GUIA_FIRMA_ANDROID.md. Release builds NEVER use the debug key. " +
                "Do not share or commit signing passwords."
        )
    }
}

android {
    namespace = "com.xtreamplayer.xtream_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador propio de NOVA: no choca con la marca ya instalada
        // (com.xtreamplayer.xtream_player), así se instala a la vez.
        applicationId = "com.alphavision.ott"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Flutter exige 24 como mínimo; los plugins de vídeo también.
        minSdk = 24
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("production") {
                storeFile = releaseKeystore
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Missing credentials are rejected before any release task executes.
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("production")
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

dependencies {

    // ExoPlayer estándar (Media3), sin motores ni decodificadores externos.
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.11.1")
}
