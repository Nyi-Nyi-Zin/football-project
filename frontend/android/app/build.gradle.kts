plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.betting_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    flavorDimensions += "app"

    defaultConfig {
        // The app ID is overridden by each product flavor below so all three
        // apps can be installed side-by-side on the same Android device.
        applicationId = "com.example.betting_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    productFlavors {
        create("customer") {
            dimension = "app"
            applicationId = "com.cloud9.bet"
            resValue("string", "app_name", "Cloud 9 Bet")
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.cloud9.admin"
            resValue("string", "app_name", "Cloud 9 Admin")
        }
        create("agent") {
            dimension = "app"
            applicationId = "com.cloud9.agent"
            resValue("string", "app_name", "Cloud 9 Agent")
        }
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
