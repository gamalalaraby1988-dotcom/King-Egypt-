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

	# Switch accounts before the first account's successful HTTP response arrives.
	client.set_session_access_token("token-b", "user-b")
	var response := JSON.stringify({
		"ok": true,
		"result": {"accepted": 1, "duplicates": 0}
	}).to_utf8_buffer()
	client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), response)

	var passed := client._events.size() == 2
	passed = passed and client._events[0].get("owner_user_id", "") == "user-a"
	passed = passed and client._events[1].get("owner_user_id", "") == "user-b"
	passed = passed and client._pending_event_ids.is_empty()
	passed = passed and not client._request_active
	passed = passed and client._request_access_token.is_empty()
	passed = passed and client._request_user_id.is_empty()

	if not passed:
		push_error("Account switch in-flight sync test failed: stale response changed the outbox or request state.")
		client.queue_free()
		quit(1)
		return

	print("Account switch in-flight sync test passed: stale response preserved both accounts' queued events.")
	client.queue_free()
	quit(0)
