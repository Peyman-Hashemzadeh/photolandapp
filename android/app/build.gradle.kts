plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.photoland.photolandapp"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.photoland.photolandapp"
        minSdk = flutter.minSdkVersion  // تغییر از flutter.minSdkVersion به 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true  // اضافه شده برای Firebase
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Dependencies برای Firebase
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Plugin Firebase
apply(plugin = "com.google.gms.google-services")
