plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sample.ota.shell_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sample.ota.shell_app"
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

flutter {
    source = "../.."
}

// Shell mặc định gọi OTA server ở http://localhost:8080 (lib/config.dart). Trước mỗi
// lần build debug (Run từ Android Studio, `flutter run`), chuyển cổng đó về máy dev
// cho MỌI thiết bị đang cắm: `adb -s <serial> reverse tcp:8080 tcp:8080`.
// Không có adb/thiết bị thì chỉ cảnh báo, không làm hỏng build.
// Đổi cổng: -PotaServerPort=9090 (nhớ đổi cả MINI_APP_SERVER).
val otaServerPort = (project.findProperty("otaServerPort") as String?) ?: "8080"
val adbExecutable = android.sdkDirectory.resolve("platform-tools")
    .resolve(if (System.getProperty("os.name").startsWith("Windows")) "adb.exe" else "adb")

val adbReverseOtaServer by tasks.registering {
    description = "adb reverse tcp:$otaServerPort cho mọi thiết bị đang kết nối"
    doLast {
        fun adb(vararg args: String): Pair<Int, String> {
            val process = ProcessBuilder(adbExecutable.absolutePath, *args).redirectErrorStream(true).start()
            val output = process.inputStream.bufferedReader().readText()
            return process.waitFor() to output
        }
        if (!adbExecutable.exists()) {
            logger.warn("adbReverseOtaServer: không thấy $adbExecutable, bỏ qua")
            return@doLast
        }
        val serials = adb("devices").second.lines()
            .map { line -> line.trim().split(' ', '\t').filter { it.isNotEmpty() } }
            .filter { it.size >= 2 && it[1] == "device" }
            .map { it[0] }
        for (serial in serials) {
            val (code, output) = adb("-s", serial, "reverse", "tcp:$otaServerPort", "tcp:$otaServerPort")
            if (code == 0) {
                logger.lifecycle("adb reverse tcp:$otaServerPort -> $serial")
            } else {
                logger.warn("adb reverse thất bại cho $serial: ${output.trim()}")
            }
        }
    }
}

tasks.matching { it.name == "preDebugBuild" }.configureEach { dependsOn(adbReverseOtaServer) }
