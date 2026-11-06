plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.slaras.foodlab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Dhodi, 6 Nov 2026: androidx.collection:collection:1.4.2 dan
    // com.squareup.okio:okio:3.9.1 sama-sama membawa file metadata
    // Kotlin Multiplatform (nativeMain/linuxMain/...) sehingga
    // MergeJavaRes gagal (duplikat). File itu tak dipakai di runtime
    // Android — kecualikan seluruh direktori metadata KMP.
    packaging {
        resources {
            excludes += "commonMain/**"
            excludes += "nonJvmMain/**"
            excludes += "**/linkdata/**"
            excludes += "nativeMain/**"
            excludes += "linuxMain/**"
            excludes += "mingwMain/**"
            excludes += "appleMain/**"
            excludes += "iosMain/**"
            excludes += "jsMain/**"
            excludes += "wasmJsMain/**"
            excludes += "wasmWasiMain/**"
            excludes += "androidNativeMain/**"
            excludes += "**/*.knm"
            // Duplikat file lisensi META-INF antar artefak KMP
            // (mis. annotation vs annotation-jvm) — tak dipakai runtime.
            excludes += "META-INF/kotlin-project-structure-metadata.json"
            excludes += "META-INF/**/LICENSE.txt"
            excludes += "META-INF/**/LICENSE"
            excludes += "META-INF/**/NOTICE.txt"
            excludes += "META-INF/**/NOTICE"
            excludes += "META-INF/**/DEPENDENCIES"
        }
    }

    defaultConfig {
        applicationId = "com.slaras.foodlab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Dhodi, 6 Nov 2026: artefak -ktx lama (activity-ktx 1.5.1,
// collection-ktx 1.1.0, lifecycle-runtime-ktx 2.5.1) masih membawa kelas
// yang di versi baru sudah pindah ke artefak dasar (activity 1.9.0,
// collection 1.4.2, lifecycle-common 2.7.0) sehingga
// checkDebugDuplicateClasses gagal. Paksa -ktx ke versi yang selaras
// dengan artefak dasar (di versi itu -ktx sudah tipis/kosong, kelasnya
// hanya ada di artefak dasar).
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity-ktx:1.9.0")
        force("androidx.collection:collection-ktx:1.4.2")
        force("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    }
    // Dhodi/VM Hatch 6 Nov 2026: datastore-core-okio (KMP, tanpa target
    // Android) menarik datastore-core-jvm, yang kelasnya
    // (androidx.datastore.core.*) identik dengan datastore-core-android
    // (AAR). Tanpa exclude, :app:checkDebugDuplicateClasses gagal dengan
    // 104 kelas duplikat. Kelas yang sama disediakan AAR Android.
    exclude(group = "androidx.datastore", module = "datastore-core-jvm")
}

flutter {
    source = "../.."
}
