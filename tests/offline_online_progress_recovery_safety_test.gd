extends SceneTree

const PlayerSyncClientScript = preload("res://scripts/player_sync_client.gd")
const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")

const REVIEW_PATH := "user://player_sync_progress_review.cfg"
var _profile_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _remove_file(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	_remove_file(REVIEW_PATH)
	_remove_file(_profile_path)
	ProfileConfigStore.set_active_account("")


func _fail(client: Node, message: String) -> void:
	push_error("Offline/Online progress recovery safety test failed: " + message)
	client.queue_free()
	_cleanup()
	quit(1)


func _run() -> void:
	_cleanup()
	if not ProfileConfigStore.set_active_account("sync-recovery-contract-test"):
		push_error("Could not activate isolated recovery test profile.")
		quit(1)
		return
	_profile_path = ProfileConfigStore.get_active_profile_path()

	var local_profile := ConfigFile.new()
	local_profile.set_value("profile", "mission_progress_test", 7)
	local_profile.set_value("profile", "owned_vehicles", ["toyota_corolla", "hyundai_elantra"])
	local_profile.set_value("wallet", "balances", {"money": 88, "chips": 12, "gems": 3})
	if local_profile.save(_profile_path) != OK:
		push_error("Could not create isolated local progress fixture.")
		_cleanup()
		quit(1)
		return

	var client := PlayerSyncClientScript.new()
	root.add_child(client)
	await process_frame
	client._access_token = "synthetic-access-token"
	client._session_user_id = "synthetic-account-id"
	client._progress_request_active = true
	client._progress_request_token = "synthetic-access-token"
	client._progress_request_user_id = "synthetic-account-id"

	var accepted_messages: Array[String] = []
	var recovery_messages: Array[String] = []
	client.progress_observations_finished.connect(func(success: bool, message: String) -> void:
		recovery_messages.append(("success: " if success else "failure: ") + message)
		if success:
			accepted_messages.append(message)
	)

	var recovery_body := JSON.stringify({
		"authoritative": false,
		"trust": "unverified_client_observations",
		"observations": [
			{"progress_key": "mission.test", "progress_value": 2, "updated_at": "2026-11-20T10:00:00Z"},
			{"progress_key": "achievement.test", "progress_value": 8, "updated_at": "2026-11-20T10:00:00Z"}
		]
	}).to_utf8_buffer()
	client._on_progress_recovery_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), recovery_body)

	var recovered := client.get_unverified_progress_observations()
	var after_recovery := ConfigFile.new()
	if after_recovery.load(_profile_path) != OK:
		_fail(client, "Local profile could not be reloaded after recovery.")
		return
	var mission_value := -1
	for observation in recovered:
		if str(observation.get("progress_key", "")) == "mission.test":
			mission_value = int(observation.get("progress_value", -1))
	if recovered.size() != 2 or mission_value != 2 or not FileAccess.file_exists(REVIEW_PATH):
		_fail(client, "Server observations were not saved to the separate review file. messages=" + str(recovery_messages) + " recovered=" + str(recovered))
		return
	if accepted_messages.size() != 1:
		_fail(client, "Recovery was not explicitly reported as review-only.")
		return
	if int(after_recovery.get_value("profile", "mission_progress_test", -1)) != 7:
		_fail(client, "An older unverified observation overwrote newer local mission progress.")
		return
	if after_recovery.get_value("profile", "owned_vehicles", []) != ["toyota_corolla", "hyundai_elantra"]:
		_fail(client, "Progress recovery changed local vehicle ownership.")
		return
	if after_recovery.get_value("wallet", "balances", {}) != {"money": 88, "chips": 12, "gems": 3}:
		_fail(client, "Progress recovery changed local wallet balances.")
		return

	# A response that claims authority must be rejected and must not replace the review file.
	client._progress_request_active = true
	client._progress_request_token = "synthetic-access-token"
	client._progress_request_user_id = "synthetic-account-id"
	var invalid_body := JSON.stringify({
		"authoritative": true,
		"trust": "unverified_client_observations",
		"observations": [{"progress_key": "mission.test", "progress_value": 999}]
	}).to_utf8_buffer()
	client._on_progress_recovery_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), invalid_body)
	if client.get_unverified_progress_observations().size() != 2:
		_fail(client, "A response with an invalid trust label replaced the previously stored review data.")
		return

	client.queue_free()
	_cleanup()
	print("Offline/Online progress recovery safety test passed: remote observations remain review-only and cannot overwrite local progress, wallet, or ownership.")
	quit(0)
