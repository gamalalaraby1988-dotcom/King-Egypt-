extends SceneTree

var _failed := 0

func _initialize() -> void:
	var player_auth := FileAccess.get_file_as_string("res://scripts/player_account_auth_client.gd")
	var founder_auth := FileAccess.get_file_as_string("res://scripts/founder_auth_client.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var export_preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	var secure_plugin := FileAccess.get_file_as_string("res://android/plugins/founder_secure_storage/plugin/src/main/java/com/kingofegyptcity/security/FounderSecureStoragePlugin.kt")

	_check(player_auth.contains('"/auth/v1/signup"') and player_auth.contains('"signup_email"'), "Email registration must use Supabase signup.")
	_check(player_auth.contains('"/auth/v1/verify"') and player_auth.contains('"type": "email"'), "Email OTP must verify the signup email.")
	_check(player_auth.contains('"/auth/v1/token?grant_type=password"'), "Email sign-in must use the password grant.")
	_check(player_auth.contains('"/auth/v1/recover?redirect_to='), "Password recovery must request a recovery email with the app deep-link redirect.")
	_check(player_auth.contains('"code_challenge": challenge') and player_auth.contains('"code_challenge_method": "s256"'), "Password recovery must use a PKCE challenge.")
	_check(player_auth.contains('RECOVERY_CODE_VERIFIER_ALIAS') and player_auth.contains('save_secret'), "Password recovery verifier must be stored securely across app launches.")
	_check(player_auth.contains('"saveSecret"') and player_auth.contains('"isAvailable"') and player_auth.contains("storage.callv"), "The auth client must support both Android plugin bridge method naming styles.")
	_check(secure_plugin.contains("fun isAvailable()") and secure_plugin.contains("fun saveSecret(") and secure_plugin.contains("fun loadSecret("), "The Android plugin must expose camelCase aliases for secure storage methods.")
	_check(player_auth.contains('parameters.get("code", "")') and player_auth.contains('"/auth/v1/token?grant_type=pkce"'), "Password recovery deep links must exchange PKCE authorization codes.")
	_check(player_auth.contains('"auth_code": authorization_code') and player_auth.contains('"code_verifier": verifier'), "PKCE exchange must submit the authorization code and matching verifier.")
	_check(player_auth.contains('"type": "recovery"'), "Password recovery OTP must use the recovery verification type.")
	_check(player_auth.contains('"/auth/v1/user"') and player_auth.contains("HTTPClient.METHOD_PUT"), "Password updates must use the authenticated user endpoint with PUT.")
	_check(player_auth.contains("email_confirmed_at"), "A session must not be accepted until the email is confirmed.")
	_check(player_auth.contains("REFRESH_TOKEN_ALIAS") and player_auth.contains("save_secret"), "Refresh tokens must use Android secure storage.")
	_check(not player_auth.contains("provider=google") and not player_auth.contains("OS.shell_open(authorize_url)"), "The email/password flow must not accidentally invoke the disabled Google flow.")
	_check(founder_auth.contains("request_founder_entitlement_with_access_token"), "Founder entitlement must accept the player session.")
	_check(not founder_auth.contains("/auth/v1/otp") and not founder_auth.contains("refresh_token"), "Founder entitlement transport must not maintain a separate Auth session.")
	_check(not founder_auth.contains('call_deferred("_restore_persisted_session")'), "Founder auth must not restore a separate Auth session.")
	_check(main_source.contains("account_email_input") and main_source.contains("account_password_input"), "The login screen must expose email and password inputs.")
	_check(main_source.contains("account_otp_input"), "The login screen must expose the email OTP input.")
	_check(main_source.contains("request_email_sign_up") and main_source.contains("verify_email_otp"), "The login screen must connect registration and email verification.")
	_check(main_source.contains("request_email_sign_in") and main_source.contains("request_password_recovery"), "The login screen must connect email sign-in and password recovery.")
	_check(main_source.contains("verify_password_recovery_otp") and main_source.contains("update_password"), "The login screen must connect recovery verification and password update.")
	_check(main_source.contains("FounderIdentityManager.founder_subject_id != account_id"), "Founder identity must remain bound to its original Auth user.")
	_check(main_source.contains('str(parsed_claims.get("subject_id", "")) != PlayerAccountAuthClient.get_user_id()'), "Founder tickets must match the active player account.")
	_check(main_source.contains("FounderAuthClient.request_founder_entitlement_with_access_token(access_token)"), "Founder entitlement must be checked automatically after the player session is active.")
	_check(not main_source.contains("_on_founder_verify_current_player_account"), "There must be no separate founder verification action.")
	_check(not main_source.contains("founder_pin_gate") and not main_source.contains("_on_founder_pin_submit"), "Founder entry must not open a separate PIN login gate.")
	_check(export_preset.contains("gradle_build/use_gradle_build=true") and export_preset.contains("permissions/internet=true"), "Android export must use Gradle plugins and Internet permission.")

	if _failed:
		push_error("Player email/password authentication contract tests failed: %d" % _failed)
		quit(1)
		return
	print("Player email/password authentication contract tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed += 1
	push_error(message)
