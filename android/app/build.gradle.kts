import java.util.Properties
import java.net.URLDecoder
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

fun dartDefine(name: String): String? {
    val encodedDefines = project.findProperty("dart-defines") as String? ?: return null
    for (encoded in encodedDefines.split(",")) {
        val decoded = String(Base64.getDecoder().decode(encoded))
        val separator = decoded.indexOf("=")
        if (separator == -1) {
            continue
        }

        val key = decoded.substring(0, separator)
        if (key == name) {
            val value = decoded.substring(separator + 1)
            return URLDecoder.decode(value, "UTF-8")
        }
    }
    return null
}

val googleMapsApiKey = (
    project.findProperty("GOOGLE_MAPS_API_KEY") as String?
        ?: dartDefine("GOOGLE_MAPS_API_KEY")
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""
)

android {
    namespace = "com.example.wanderjoy_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.wanderjoy_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
