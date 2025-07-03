apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'com.google.gms.google-services'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    compileSdkVersion 35
    ndkVersion "27.0.12077973"

    defaultConfig {
        applicationId "com.example.herbal_i"
        minSdkVersion 26
        targetSdkVersion 35
        versionCode 1
        versionName "1.0.0"
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
                targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = '11'
    }

    aaptOptions {
        noCompress 'tflite'
        noCompress 'lite'
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:1.9.10"
    implementation platform("com.google.firebase:firebase-bom:32.7.4")
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-database'

    implementation 'org.tensorflow:tensorflow-lite:2.14.0'
    implementation 'org.tensorflow:tensorflow-lite-support:0.4.4'
    implementation 'org.tensorflow:tensorflow-lite-metadata:0.4.4'
}
