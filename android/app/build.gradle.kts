import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun resolveKeystoreFile(rawPath: String): File {
    val direct = project.file(rawPath)
    if (direct.exists()) return direct
    val fromRoot = rootProject.file(rawPath)
    if (fromRoot.exists()) return fromRoot
    return direct
}

val envStorePath = System.getenv("ANDROID_KEYSTORE_PATH")?.trim().orEmpty()
val envStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")?.trim().orEmpty()
val envKeyAlias = System.getenv("ANDROID_KEY_ALIAS")?.trim().orEmpty()
val envKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")?.trim().orEmpty()
val hasAnyEnvSigning =
    envStorePath.isNotEmpty() ||
        envStorePassword.isNotEmpty() ||
        envKeyAlias.isNotEmpty() ||
        envKeyPassword.isNotEmpty()
val hasReleaseSigningSource = keystorePropertiesFile.exists() || hasAnyEnvSigning
val isStrictReleaseSigningRequested =
    gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) } ||
        project.hasProperty("requireReleaseSigning")

android {
    namespace = "com.cajaya.pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cajaya.pos"
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

    signingConfigs {
        create("release") {
            if (hasReleaseSigningSource) {
                val rawAlias = if (keystorePropertiesFile.exists()) {
                    keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
                } else {
                    envKeyAlias
                }
                val rawKeyPassword = if (keystorePropertiesFile.exists()) {
                    keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()
                } else {
                    envKeyPassword
                }
                val rawStorePath = if (keystorePropertiesFile.exists()) {
                    keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
                } else {
                    envStorePath
                }
                val rawStorePassword = if (keystorePropertiesFile.exists()) {
                    keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
                } else {
                    envStorePassword
                }

                if (rawAlias.isEmpty() || rawKeyPassword.isEmpty() || rawStorePath.isEmpty() || rawStorePassword.isEmpty()) {
                    throw GradleException(
                        "Configuracion de firma Android incompleta: verifica storeFile, keyAlias, storePassword y keyPassword."
                    )
                }

                val resolvedStoreFile = resolveKeystoreFile(rawStorePath)
                if (!resolvedStoreFile.exists()) {
                    throw GradleException(
                        "No se encontro el keystore de produccion en '${resolvedStoreFile.absolutePath}'."
                    )
                }

                keyAlias = rawAlias
                keyPassword = rawKeyPassword
                storeFile = resolvedStoreFile
                storePassword = rawStorePassword
            } else if (isStrictReleaseSigningRequested) {
                throw GradleException(
                    "Falta firma de produccion para generar AAB de Play Store. Configura android/key.properties o las variables ANDROID_KEYSTORE_*."
                )
            } else {
                // Fallback controlado solo para builds APK de previsualizacion sin claves de produccion
                initWith(getByName("debug"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
