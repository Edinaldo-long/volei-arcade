import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.edinaldo.volei"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.edinaldo.volei"
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
            val envKeyAlias = System.getenv("KEY_ALIAS")
            val envKeyPassword = System.getenv("KEY_PASSWORD")
            val envStoreFile = System.getenv("STORE_FILE")
            val envStorePassword = System.getenv("STORE_PASSWORD")

            val keyAliasProp = if (!envKeyAlias.isNullOrBlank()) envKeyAlias else keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = if (!envKeyPassword.isNullOrBlank()) envKeyPassword else keystoreProperties.getProperty("keyPassword")
            val storeFileProp = if (!envStoreFile.isNullOrBlank()) envStoreFile else keystoreProperties.getProperty("storeFile")
            val storePasswordProp = if (!envStorePassword.isNullOrBlank()) envStorePassword else keystoreProperties.getProperty("storePassword")

            if (!keyAliasProp.isNullOrBlank() && !storeFileProp.isNullOrBlank()) {
                val candidateFile = if (file(storeFileProp).exists()) {
                    file(storeFileProp)
                } else if (rootProject.file(storeFileProp).exists()) {
                    rootProject.file(storeFileProp)
                } else if (file("app/$storeFileProp").exists()) {
                    file("app/$storeFileProp")
                } else {
                    null
                }

                if (candidateFile != null) {
                    keyAlias = keyAliasProp
                    keyPassword = keyPasswordProp
                    storeFile = candidateFile
                    storePassword = storePasswordProp
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseConfig?.storeFile != null && releaseConfig.storeFile!!.exists()) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
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
