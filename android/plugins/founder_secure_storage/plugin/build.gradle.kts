plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val godotPluginName = "FounderSecureStorage"
val godotPluginPackage = "com.kingofegyptcity.security"

android {
    namespace = godotPluginPackage
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = godotPluginName
        manifestPlaceholders["godotPluginPackageName"] = godotPluginPackage
        setProperty("archivesBaseName", godotPluginName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Keep this exactly aligned with the Godot editor/export templates used by the project.
    implementation("org.godotengine:godot:4.7.0.stable")
}

val repoRoot = layout.projectDirectory.dir("../../../../").asFile
val addonRoot = File(repoRoot, "addons/founder_secure_storage/bin")

tasks.register<Copy>("copyDebugAARToAddon") {
    dependsOn("assembleDebug")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("FounderSecureStorage-debug.aar")
    into(File(addonRoot, "debug"))
}

tasks.register<Copy>("copyReleaseAARToAddon") {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("FounderSecureStorage-release.aar")
    into(File(addonRoot, "release"))
}
