plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

project.extra["envConfigFiles"] = mapOf(
    "production" to ".env",
    "staging" to ".env.staging",
    "development" to ".env.development",
)

apply(from = project(":flutter_config").projectDir.path + "/dotenv.gradle.kts")

android {
    namespace = "com.beebase"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.beebase"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("production") {
            dimension = "environment"
            resValue("string", "APP_DISPLAY_NAME", "BeeBase")
            applicationIdSuffix = ".production"
        }
        create("staging") {
            dimension = "environment"
            resValue("string", "APP_DISPLAY_NAME", "BeeBase (staging)")
            applicationIdSuffix = ".staging"
        }
        create("development") {
            dimension = "environment"
            resValue("string", "APP_DISPLAY_NAME", "BeeBase (development)")
            applicationIdSuffix = ".development"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8/resource shrinking is on by default for this AGP version and strips
            // the BuildConfig fields and string resources that flutter_config reads
            // via reflection at runtime (they're never referenced from code/XML, so
            // the shrinker treats them as unused). Disabled until proguard/keep rules
            // are set up to preserve them explicitly.
            isMinifyEnabled = false
            isShrinkResources = false
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
