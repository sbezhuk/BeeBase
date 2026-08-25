## Android Setup

**The following steps are required for Android**

You need to manually apply a plugin to your app, from `android/app/build.gradle.kts`:

Right below the Flutter Gradle plugin is applied

add the following line:

`apply(from = project(":flutter_config").projectDir.path + "/dotenv.gradle.kts")`

**Building a release version**

When building your apk for release, the R8 code shrinker obfuscates the `BuildConfig` class which holds all the env variables and thus causes all the env variables to be null. To prevent this, the following has to be done:

1. Add file `android/app/proguard-rules.pro` to your app's project.
2. Add the below line to the newly created `proguard-rules.pro` file:
    ```
    -keep class com.yourcompany.app.BuildConfig { *; }
    ```
    where `com.yourcompany.app` should be replaced with your app's package name.

## Usage in Java/Kotlin Code

Config variables set in `.env` are available to your Java or Kotlin classes via `BuildConfig`:

```kotlin
fun getApiClient(): HttpURLConnection {
    val url = URL(BuildConfig.API_URL);
    // ...
}
```

## Usage in Gradle

You can read environment varibles from your Gradle configuration:

```kotlin
defaultConfig {
    applicationId = project.extra["env"].let { (it as Map<*, *>)["APP_ID"] as String }
}
```

## Usage in XML files

You can use env variables to configure libraries in `AndroidManifest.xml` and other xml files:

```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="@string/GOOGLE_MAPS_API_KEY" />
```

## Different environments

Save config for different environments in different files: `.env.staging`, `.env.production`, etc.

The same environment variable can be used to assemble releases with a different config:

```
$ cd android && ENVFILE=.env.staging ./gradlew assembleRelease
```

Alternatively, you can define a map in `build.gradle.kts` associating builds with env files. Do it before the `apply(from = ...)` call, and use build cases in lowercase, like:

```kotlin
project.extra["envConfigFiles"] = mapOf(
    "debug" to ".env.development",
    "release" to ".env.production",
    "anothercustombuild" to ".env",
)

apply(from = project(":flutter_config").projectDir.path + "/dotenv.gradle.kts")
```

## Different Package Names

In `android/app/build.gradle.kts`, if you use `applicationIdSuffix` or `applicationId` that is different from the package name indicated in `AndroidManifest.xml` in `<manifest package="...">` tag, for example, to support different build variants:
Add this in `android/app/build.gradle.kts`

```kotlin
defaultConfig {
    ...
    resValue("string", "build_config_package", "YOUR_PACKAGE_NAME_IN_ANDROIDMANIFEST.XML")
}
```

## Note

All variables are strings, so you may need to cast them. For instance, in Gradle:

```kotlin
versionCode = (project.extra["env"] as Map<*, *>)["VERSION_CODE"].toString().toInt()
```

Once again, remember variables stored in `.env` are published with your code, so **DO NOT put anything sensitive there like your app `signingConfigs`.**

This plugin is written in Kotlin. Therefore, you need to make sure you have Kotlin support in your project your project. See [installing the Kotlin plugin](https://kotlinlang.org/docs/tutorials/kotlin-android.html#installing-the-kotlin-plugin).

Edit your project-level build.gradle.kts file to look like this:

    buildscript {
        extra["kotlin_version"] = "1.3.31"
        ...
        dependencies {
            ...
            classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${extra["kotlin_version"]}")
        }
    }
    ...

Edit your app-level build.gradle.kts file to look like this:

    apply(plugin = "kotlin-android")
    ...
    dependencies {
        implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:${extra["kotlin_version"]}")
        ...
    }

You also need to make sure you are on the latest version of gradle
