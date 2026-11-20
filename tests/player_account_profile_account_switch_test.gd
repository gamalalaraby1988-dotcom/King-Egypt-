extends SceneTree

const PlayerAccountAuthClientScript = preload("res://scripts/player_account_auth_client.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var client := PlayerAccountAuthClientScript.new()
	root.add_child(client)
	await process_frame

	client._access_token = "token-b"
	client._user_id = "user-b"
	client._expires_at = int(Time.get_unix_time_from_system()) + 3600

	var ready_profiles: Array[Dictionary] = []
	var failed_profiles: Array[String] = []
	client.player_profile_ready.connect(func(user_id: String, player_code: String, display_name: String) -> void:
		ready_profiles.append({
			"user_id": user_id,
			"player_code": player_code,
			"display_name": display_name
		})
	)
	client.player_profile_failed.connect(func(message: String) -> void:
		failed_profiles.append(message)
	)

	# Account B is active, so a response sent under account A must be rejected.
	var stale_request_matches := client._is_profile_request_current("user-a", "token-a")
	client._profile_action = "profile"
	client._profile_request_user_id = "user-a"
	client._profile_request_access_token = "token-a"
	# Deliver account A's response while account B remains active. The callback
	# must ignore A's profile and schedule a fresh fetch for B.
	var stale_body := JSON.stringify([{
		"player_code": "AAAAAAAAAA",
		"display_name": "Old Account"
	}]).to_utf8_buffer()
	client._on_profile_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), stale_body)
	var stale_profile_was_rejected := ready_profiles.is_empty()

	# Simulate the follow-up request for B before the deferred fetch can run.
	# Its response must be accepted with B's captured identity.
	# captured account ID, never with a mutable global identity.
	client._access_token = "token-b"
	client._user_id = "user-b"
	client._expires_at = int(Time.get_unix_time_from_system()) + 3600
	client._profile_action = "profile"
	client._profile_request_user_id = "user-b"
	client._profile_request_access_token = "token-b"
	var current_body := JSON.stringify([{
		"player_code": "BBBBBBBBBB",
		"display_name": "Current Account"
	}]).to_utf8_buffer()
	client._on_profile_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), current_body)

	var passed := not stale_request_matches
	passed = passed and stale_profile_was_rejected
	passed = passed and ready_profiles.size() == 1
	passed = passed and ready_profiles[0].get("user_id", "") == "user-b"
	passed = passed and ready_profiles[0].get("player_code", "") == "BBBBBBBBBB"
	passed = passed and ready_profiles[0].get("display_name", "") == "Current Account"
	passed = passed and failed_profiles.is_empty()

	if not passed:
		push_error("Player profile account-switch test failed: stale profile data was accepted or the current account profile was rejected.")
		client.queue_free()
		quit(1)
		return

	print("Player profile account-switch test passed: stale account response rejected and current account profile accepted.")
	client.queue_free()
	quit(0)
