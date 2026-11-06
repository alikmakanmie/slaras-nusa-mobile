pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // Repo Maven lokal (offline VM Hatch) — aktif bila env LOCAL_MAVEN_REPO
        // diset; diabaikan di CI/mesin normal.
        val localRepo = System.getenv("LOCAL_MAVEN_REPO")
        if (localRepo != null) {
            maven { url = uri(localRepo) }
        }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    // Dhodi (VM Hatch, 6 Nov 2026): KGP 2.4.0 -> 2.5.0-Beta2 karena KGP <= 2.4.21
    // memanggil API internal Gradle yang dihapus di Gradle 9.3.1 (BuildOption$Value,
    // HasConvention) -> build gagal NoSuchMethodError. Kembalikan ke stabil bila
    // KGP 2.5.0 final tersedia.
    id("org.jetbrains.kotlin.android") version "2.5.0-Beta2" apply false
}

include(":app")
