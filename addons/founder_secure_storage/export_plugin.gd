@tool
extends EditorPlugin

var export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
    export_plugin = AndroidExportPlugin.new()
    add_export_plugin(export_plugin)

func _exit_tree() -> void:
    if export_plugin != null:
        remove_export_plugin(export_plugin)
        export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
    var _plugin_name := "FounderSecureStorage"

    func _supports_platform(platform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(_platform, debug: bool) -> PackedStringArray:
        var build_type := "debug" if debug else "release"
        var library_path := "res://addons/founder_secure_storage/bin/%s/FounderSecureStorage-%s.aar" % [build_type, build_type]
        if not FileAccess.file_exists(library_path):
            push_error("FounderSecureStorage Android AAR is missing: " + library_path)
            return PackedStringArray()
        print("FounderSecureStorage: packaging Android AAR: " + library_path)
        return PackedStringArray([library_path])

    func _get_android_manifest_application_element_contents(_platform, _debug: bool) -> String:
        return """
<meta-data
    android:name="org.godotengine.plugin.v2.FounderSecureStorage"
    android:value="com.kingofegyptcity.security.FounderSecureStoragePlugin" />
"""

    func _get_android_manifest_activity_element_contents(_platform, _debug: bool) -> String:
        return """
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="kingofegyptcity" android:host="auth-callback" />
</intent-filter>
"""

    func _get_name() -> String:
        return _plugin_name
