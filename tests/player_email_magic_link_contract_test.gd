extends SceneTree

var _failed := 0

func _initialize() -> void:
	var player_auth := FileAccess.get_file_as_string("res://scripts/player_account_auth_client.gd")
	var founder_auth := FileAccess.get_file_as_string("res://scripts/founder_auth_client.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var android_plugin := FileAccess.get_file_as_string("res://android/plugins/founder_secure_storage/plugin/src/main/java/com/kingofegyptcity/security/FounderSecureStoragePlugin.kt")
	var export_plugin := FileAccess.get_file_as_string("res://addons/founder_secure_storage/export_plugin.gd")
	var export_preset := FileAccess.get_file_as_string("res://export_presets.cfg")

	_check(player_auth.contains("provider=google") and player_auth.contains("OS.shell_open(authorize_url)"), "Google fallback sign-in must open the OAuth page.");
	_check(player_auth.contains('/auth/v1/token?grant_type=password') and player_auth.contains('"email": normalized_email') and player_auth.contains('"password": password'), "Primary player sign-in must use Supabase email/password authentication.");
	_check(player_auth.contains('"email_password"') and player_auth.contains('_accept_session_response(response, false)'), "Email/password sign-in must enter the shared session lifecycle.");
	_check(player_auth.contains("code_challenge_method=s256") and player_auth.contains("code_challenge="), "Google OAuth must use PKCE.")
	_check(player_auth.contains('kingofegyptcity://auth-callback'), "Google OAuth must use the registered Android callback URI.")
	_check(player_auth.contains('"/auth/v1/token?grant_type=pkce"'), "Google callbacks must exchange the PKCE authorization code.")
	_check(player_auth.contains('getPendingAuthLink') and player_auth.contains('clearPendingAuthLink'), "Google OAuth must consume and clear Android callback links.")
	_check(founder_auth.contains("request_founder_entitlement_with_access_token"), "Founder entitlement must accept the player session.")
	_check(not founder_auth.contains("/auth/v1/otp") and not founder_auth.contains("refresh_token"), "Founder entitlement transport must not maintain a separate Auth session.")
	_check(not founder_auth.contains('call_deferred("_restore_persisted_session")'), "Founder auth must not restore a separate Auth session.")
	_check(main_source.contains("FounderIdentityManager.founder_subject_id != account_id"), "Founder identity must remain bound to its original Auth user.")
	_check(main_source.contains('str(parsed_claims.get("subject_id", "")) != PlayerAccountAuthClient.get_user_id()'), "Founder tickets must match the active player account.")
	_check(main_source.contains("FounderAuthClient.request_founder_entitlement_with_access_token(access_token)"), "Founder entitlement must be checked automatically after the player session is active.")
	_check(not main_source.contains("_on_founder_verify_current_player_account"), "There must be no separate founder verification action.")
	_check(not main_source.contains("founder_pin_gate") and not main_source.contains("_on_founder_pin_submit"), "Founder entry must not open a separate PIN login gate.")
	_check(main_source.contains("تسجيل الدخول بالبريد الإلكتروني") and main_source.contains("البريد الإلكتروني") and main_source.contains("كلمة المرور"), "The login screen must expose email/password as the primary sign-in path.")
	_check(main_source.contains("الدخول باستخدام Google (بديل)"), "Google sign-in must remain available as a fallback for existing linked accounts.")
	_check(main_source.contains("player_password_input.secret = true"), "The password field must be masked.")
	_check(main_source.contains("player_email_input") and main_source.contains("player_password_input"), "Player UI must collect email and password for primary login.")
	_check(not main_source.contains("player_account_code_input") and not main_source.contains("founder_email_gate"), "Player UI must not introduce a separate founder login gate.")
	_check(android_plugin.contains("getPendingAuthLink") and android_plugin.contains("clearPendingAuthLink"), "Android plugin must expose callback retrieval and clearing.")
	_check(export_plugin.contains("android.intent.action.VIEW") and export_plugin.contains('android:scheme="kingofegyptcity"'), "Android manifest must register the app callback scheme.")
	_check(export_preset.contains("gradle_build/use_gradle_build=true") and export_preset.contains("permissions/internet=true"), "Android export must use Gradle plugins and Internet permission.")

	if _failed:
		push_error("Player account auth contract tests failed: %d" % _failed)
		quit(1)
		return
	print("Player account auth contract tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed += 1
	push_error(message)
