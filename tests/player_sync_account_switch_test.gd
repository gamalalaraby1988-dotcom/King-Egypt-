extends SceneTree

const PlayerSyncClientScript = preload("res://scripts/player_sync_client.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("player_sync/enabled", false)
	var client := PlayerSyncClientScript.new()
	root.add_child(client)
	await process_frame

	client._events = [
		{
			"event_id": "event-account-a",
			"owner_user_id": "user-a",
			"event_type": "setting_changed",
			"payload": {"key": "locale", "value": "ar"}
		},
		{
			"event_id": "event-account-b",
			"owner_user_id": "user-b",
			"event_type": "setting_changed",
			"payload": {"key": "locale", "value": "en"}
		}
	]
	client._pending_event_ids = ["event-account-a"]
	client._request_active = true
	client._request_access_token = "token-a"
	client._request_user_id = "user-a"
	client._snapshot_request_active = true
	client._snapshot_action = "fetch"
	client._snapshot_request_token = "token-a"
	client._snapshot_request_user_id = "user-a"
	client._snapshot_revision = 4
	client._progress_request_active = true
	client._progress_request_token = "token-a"
	client._progress_request_user_id = "user-a"
	client._reward_claim_active = true
	client._reward_claim_token = "token-a"
	client._reward_claim_user_id = "user-a"
	var stale_signals: Array[String] = []
	client.preference_snapshot_finished.connect(func(_success: bool, _message: String) -> void: stale_signals.append("snapshot"))
	client.progress_observations_finished.connect(func(_success: bool, _message: String) -> void: stale_signals.append("progress"))
	client.verified_reward_claim_finished.connect(func(_success: bool, _result: Dictionary, _message: String) -> void: stale_signals.append("reward"))

	# Switch accounts before the first account's successful HTTP response arrives.
	client.set_session_access_token("token-b", "user-b")
	var response := JSON.stringify({
		"ok": true,
		"result": {"accepted": 1, "duplicates": 0}
	}).to_utf8_buffer()
	client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), response)
	client._on_snapshot_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"revision": 99, "settings": {"locale": "en"}}).to_utf8_buffer())
	client._on_progress_recovery_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"authoritative": false, "trust": "unverified_client_observations", "observations": [{"progress_key": "mission.test", "progress_value": 2}]}).to_utf8_buffer())
	client._on_verified_reward_claim_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"claimed": true, "duplicate": false}).to_utf8_buffer())

	var passed := client._events.size() == 2
	passed = passed and client._events[0].get("owner_user_id", "") == "user-a"
	passed = passed and client._events[1].get("owner_user_id", "") == "user-b"
	passed = passed and client._pending_event_ids.is_empty()
	passed = passed and not client._request_active
	passed = passed and client._request_access_token.is_empty()
	passed = passed and client._request_user_id.is_empty()
	passed = passed and client._snapshot_revision == 4
	passed = passed and not client._snapshot_request_active
	passed = passed and client._snapshot_request_token.is_empty()
	passed = passed and client._snapshot_request_user_id.is_empty()
	passed = passed and client._progress_request_user_id.is_empty()
	passed = passed and client._reward_claim_user_id.is_empty()
	passed = passed and stale_signals.is_empty()

	if not passed:
		push_error("Account switch in-flight sync test failed: stale response changed the outbox or request state.")
		client.queue_free()
		quit(1)
		return

	print("Account switch in-flight sync test passed: stale responses preserved both accounts' events and did not apply snapshots, progress, or rewards.")
	client.queue_free()
	quit(0)
