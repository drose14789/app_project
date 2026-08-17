import java.util.Base64

plugins {
    id("com.android.application")

    // Flutter Gradle Plugin
    // AGP 9에서는 Kotlin Android Plugin을 별도로 추가하지 않음
    id("dev.flutter.flutter-gradle-plugin")
}


// =========================================================
// Flutter --dart-define 값 읽기
// =========================================================
//
// flutter run --dart-define=KAKAO_NATIVE_APP_KEY=...
//
// 로 전달한 값은 Android 빌드 시
// Gradle의 "dart-defines" 값으로 전달됨.
//
// 해당 값은 Base64 형태이므로 디코딩해서 사용.
//
val dartDefines: Map<String, String> =
    project
        .findProperty("dart-defines")
        ?.toString()
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.associate { encodedValue ->

            val decodedValue =
                String(
                    Base64
                        .getDecoder()
                        .decode(encodedValue),
                    Charsets.UTF_8,
                )

            val separatorIndex =
                decodedValue.indexOf("=")

            if (separatorIndex == -1) {
                decodedValue to ""
            } else {
                decodedValue.substring(
                    0,
                    separatorIndex,
                ) to decodedValue.substring(
                    separatorIndex + 1,
                )
            }
        }
        ?: emptyMap()


// =========================================================
// 카카오 Native App Key
// =========================================================
//
// 실제 키는 build.gradle.kts에 작성하지 않음.
//
// Flutter 실행 시 전달된
// KAKAO_NATIVE_APP_KEY 값만 사용.
//
val kakaoNativeAppKey: String =
    dartDefines["KAKAO_NATIVE_APP_KEY"]
        ?: ""


android {
    namespace =
        "com.example.flutter_application_1"

    compileSdk =
        flutter.compileSdkVersion

    ndkVersion =
        flutter.ndkVersion


    // =====================================================
    // Java 설정
    // =====================================================

    compileOptions {
        sourceCompatibility =
            JavaVersion.VERSION_17

        targetCompatibility =
            JavaVersion.VERSION_17

        // flutter_local_notifications 등에서
        // Java API desugaring 사용
        isCoreLibraryDesugaringEnabled =
            true
    }


    // =====================================================
    // Kotlin 설정
    // =====================================================

    kotlin {
        compilerOptions {
            jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl
                    .JvmTarget.JVM_17,
            )
        }
    }


    // =====================================================
    // Android 앱 기본 설정
    // =====================================================

    defaultConfig {
        applicationId =
            "com.example.flutter_application_1"

        minSdk =
            flutter.minSdkVersion

        targetSdk =
            flutter.targetSdkVersion

        versionCode =
            flutter.versionCode

        versionName =
            flutter.versionName

        // Android MultiDex 사용
        multiDexEnabled =
            true


        // =================================================
        // 카카오 로그인 Manifest Placeholder
        // =================================================
        //
        // AndroidManifest.xml:
        //
        // android:scheme=
        // "kakao${KAKAO_NATIVE_APP_KEY}"
        //
        // 위 부분에 실제 값을 넣어줌.
        //
        manifestPlaceholders[
            "KAKAO_NATIVE_APP_KEY"
        ] = kakaoNativeAppKey
    }


    // =====================================================
    // 빌드 설정
    // =====================================================

    buildTypes {
        release {

            // 현재 개발 단계에서는
            // Debug 서명키를 Release에도 사용
            signingConfig =
                signingConfigs
                    .getByName("debug")
        }
    }
}


// =========================================================
// Flutter 프로젝트 위치
// =========================================================

flutter {
    source =
        "../.."
}


// =========================================================
// Android 의존성
// =========================================================

dependencies {

    // flutter_local_notifications에서 사용하는
    // Java Core Library Desugaring
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4",
    )
}