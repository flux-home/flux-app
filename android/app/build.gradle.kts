import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Detect whether the real CHIP SDK AARs are present ─────────────────────
val chipAar     = file("libs/CHIPController.aar")
val chipPayload = file("libs/SetupPayloadParser.jar")
val useRealChipSdk = chipAar.exists()

// ── Release signing (optional — only if key.properties exists) ────────────
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties().also { props ->
    if (keyPropsFile.exists()) props.load(keyPropsFile.inputStream())
}

android {
    namespace  = "com.fluxhome.app"
    compileSdk = 36

    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        applicationId = "com.fluxhome.app"
        minSdk     = 27
        targetSdk  = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // flux-ice native build (app ADR-0001/0002). arm64-v8a matches the
        // existing jniLibs delivery; add x86_64 when an emulator build is needed.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=none")   // flux-ice is pure C
            }
        }
    }

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("release") {
                keyAlias        = keyProps["keyAlias"]    as String
                keyPassword     = keyProps["keyPassword"] as String
                storeFile       = file(keyProps["storeFile"] as String)
                storePassword   = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropsFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled  = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Build libflux_ice_jni.so from src/main/cpp (flux-ice + libjuice + JNI glue).
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

dependencies {
    if (useRealChipSdk) {
        // ── Real CHIP SDK (place AARs in android/app/libs/) ─────────────────
        implementation(files("libs/CHIPController.aar"))
        if (chipPayload.exists()) {
            implementation(files("libs/SetupPayloadParser.jar"))
        }
        // Transitive deps required by CHIPController
        implementation("com.google.protobuf:protobuf-java:4.35.0")
        implementation("com.google.code.gson:gson:2.14.0")
    } else {
        // ── Compile-time stubs (simulation mode at runtime) ──────────────────
        implementation(project(":chip-stub"))
    }

    // PKCS#10 CSR building for controller-owned fabric enrollment (the CHIP SDK
    // exposes no CSR builder and Android Keystore keys can't CSR).
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.78.1")

    // Thread Network credential store (Play Services, all build variants)
    implementation("com.google.android.gms:play-services-threadnetwork:16.3.0")

    // Coroutines (used by MatterCommissioner, the cluster bridges, BleConnectionManager)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
