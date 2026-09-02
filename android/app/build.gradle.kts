import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.runlog"
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
        applicationId = "com.example.runlog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect 요구사항: API 26+
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val signingProperties = Properties()
    val signingPropertiesFile = rootProject.file("key.properties")
    if (signingPropertiesFile.exists()) {
        signingPropertiesFile.inputStream().use(signingProperties::load)
    }
    val storeFilePath = signingProperties.getProperty("storeFile")
    val storePassword = signingProperties.getProperty("storePassword")
    val keyAlias = signingProperties.getProperty("keyAlias")
    val keyPassword = signingProperties.getProperty("keyPassword")
    val releaseSigningConfigured = listOf(
        storeFilePath,
        storePassword,
        keyAlias,
        keyPassword,
    ).all { !it.isNullOrBlank() }

    if (releaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = file(storeFilePath!!)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Never produce a distributable release signed by the debug key.
                signingConfig = null
            }
        }
    }

    if (!releaseSigningConfigured) {
        tasks.configureEach {
            if (name.contains("Release", ignoreCase = true)) {
                doFirst {
                    throw GradleException(
                        "Release signing is not configured. Add android/key.properties."
                    )
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // health 플러그인과 동일 버전 — 세그먼트/고도/VO2max 직접 조회용
    implementation("androidx.health.connect:connect-client:1.2.0-alpha02")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
