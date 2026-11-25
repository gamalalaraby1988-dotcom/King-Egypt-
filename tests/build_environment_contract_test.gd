extends SceneTree

var _failed := 0

func _initialize() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var founder_auth := FileAccess.get_file_as_string("res://scripts/founder_auth_client.gd")
	var player_auth := FileAccess.get_file_as_string("res://scripts/player_account_auth_client.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var friends_client := FileAccess.get_file_as_string("res://scripts/player_friends_client.gd")
	var sync_client := FileAccess.get_file_as_string("res://scripts/player_sync_client.gd")
	var game_server := FileAccess.get_file_as_string("res://scripts/authoritative_game_server.gd")

	_check(project.contains('auth/api_base_url="https://lupmaktbymuaymhqsxxu.supabase.co"'), "Default project auth endpoint must remain PRODUCTION.")
	_check(project.contains('auth/api_base_url.environment_test="https://unwrlvyjrtdwobcktetd.supabase.co"'), "TEST endpoint override must target the TEST project.")
	_check(project.contains('auth/api_base_url.environment_production="https://lupmaktbymuaymhqsxxu.supabase.co"'), "PRODUCTION override must target the PRODUCTION project.")
	_check(project.contains('auth/publishable_key.environment_test="sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"'), "TEST publishable key must match the TEST project.")
	_check(project.contains('auth/publishable_key.environment_production="sb_publishable_KMNgd88WnXikozVVI9TeLA_PxV5ap9P"'), "PRODUCTION publishable key must match the PRODUCTION project.")
	_check(project.contains('auth/magic_link_redirect_uri.environment_test="kingofegyptcity://auth-callback"'), "TEST OAuth callback URI must be explicitly configured.")
	_check(project.contains('auth/magic_link_redirect_uri.environment_production="kingofegyptcity://auth-callback"'), "PRODUCTION OAuth callback URI must be explicitly configured.")
	_check(presets.contains('name="Android TEST"') and presets.contains('custom_features="environment_test"'), "Android TEST preset must carry only the TEST feature tag.")
	_check(presets.contains('name="Android PRODUCTION"') and presets.contains('custom_features="environment_production"'), "Android PRODUCTION preset must carry only the PRODUCTION feature tag.")
	_check(presets.contains('package/unique_name="com.kingofegyptcity.game.test"'), "TEST APK must use a distinct Android application ID.")
	_check(presets.contains('package/unique_name="com.kingofegyptcity.game"'), "PRODUCTION APK must preserve the production Android application ID.")
	_check(founder_auth.contains("ProjectSettings.get_setting_with_override(API_BASE_SETTING") and founder_auth.contains("ProjectSettings.get_setting_with_override(PUBLISHABLE_KEY_SETTING"), "Founder entitlement client must honor the selected environment.")
	_check(player_auth.contains("ProjectSettings.get_setting_with_override(API_BASE_SETTING") and player_auth.contains("ProjectSettings.get_setting_with_override(PUBLISHABLE_KEY_SETTING"), "Player auth client must honor the selected environment.")
	_check(player_auth.contains("ProjectSettings.get_setting_with_override(REDIRECT_URI_SETTING"), "OAuth redirect URI must honor the selected environment.")
	for client_source in [main_source, friends_client, sync_client, game_server]:
		_check(client_source.contains('ProjectSettings.get_setting_with_override("founder/auth/api_base_url")'), "Every Supabase caller must honor the selected API endpoint.")
		_check(client_source.contains('ProjectSettings.get_setting_with_override("founder/auth/publishable_key")'), "Every Supabase caller must honor the selected publishable key.")
		_check(not client_source.contains('ProjectSettings.get_setting("founder/auth/api_base_url"'), "No Supabase caller may bypass environment overrides.")
		_check(not client_source.contains('ProjectSettings.get_setting("founder/auth/publishable_key"'), "No Supabase caller may bypass environment overrides.")
	_check(not project.contains("service_role") and not project.contains("secret_key"), "Project settings must not contain privileged Supabase keys.")

	if _failed > 0:
		push_error("Build environment contract tests failed: %d" % _failed)
		quit(1)
		return
	print("Build environment contract tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed += 1
	push_error(message)
