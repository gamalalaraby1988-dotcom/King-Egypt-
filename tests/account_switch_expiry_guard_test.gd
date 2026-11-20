extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	if source_file == null:
		push_error("Account-switch expiry guard test failed: could not read main.gd.")
		quit(1)
		return

	var source := source_file.get_as_text()
	var handler_start := source.find("func _on_player_account_session_expired() -> void:")
	if handler_start < 0:
		push_error("Account-switch expiry guard test failed: session-expiry handler is missing.")
		quit(1)
		return

	var next_handler := source.find("\nfunc ", handler_start + 1)
	var handler := source.substr(handler_start, next_handler - handler_start if next_handler >= 0 else source.length() - handler_start)
	var release_guard := handler.find("ProfileConfigStore.complete_account_switch()")
	var clear_session := handler.find("PlayerSyncClient.clear_session_access_token()")
	if release_guard < 0 or clear_session < 0 or release_guard > clear_session:
		push_error("Account-switch expiry guard test failed: session expiry must release the save guard before clearing sync.")
		quit(1)
		return

	print("Account-switch expiry guard test passed.")
	quit(0)
