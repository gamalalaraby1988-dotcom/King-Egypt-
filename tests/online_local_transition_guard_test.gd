extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	var mode_file := FileAccess.open("res://scripts/game_mode_manager.gd", FileAccess.READ)
	if main_file == null or mode_file == null:
		push_error("Online local-transition guard test failed: required scripts could not be read.")
		quit(1)
		return
	var main_source := main_file.get_as_text()
	var mode_source := mode_file.get_as_text()
	var guard := "func _is_local_city_interaction_allowed() -> bool:"
	if not main_source.contains(guard) or not main_source.contains("return not GameModeManager.is_online_ready()"):
		push_error("Online local-transition guard test failed: shared Online guard is missing.")
		quit(1)
		return
	for function_name in ["_summon_player_vehicle", "_toggle_vehicle_use", "enter_building_interior"]:
		var function_start := main_source.find("func " + function_name + "(")
		if function_start < 0:
			push_error("Online local-transition guard test failed: " + function_name + " is missing.")
			quit(1)
			return
		var next_function := main_source.find("\nfunc ", function_start + 1)
		var function_body := main_source.substr(function_start, next_function - function_start if next_function >= 0 else main_source.length() - function_start)
		if not function_body.contains("\n\tif not _is_local_city_interaction_allowed():\n\t\treturn"):
			push_error("Online local-transition guard test failed: " + function_name + " is not guarded at entry.")
			quit(1)
			return
	if not mode_source.contains("func is_online_ready() -> bool:") or not mode_source.contains("current_mode == Mode.ONLINE and connection_state == \"authenticated\""):
		push_error("Online local-transition guard test failed: transport connection is incorrectly treated as authenticated.")
		quit(1)
		return
	if not mode_source.contains("connection_state = \"transport_connected\"") or not mode_source.contains("func confirm_online_authentication() -> bool:"):
		push_error("Online local-transition guard test failed: authenticated transition gate is missing.")
		quit(1)
		return
	if not main_source.contains("if success and GameModeManager.confirm_online_authentication():") or not main_source.contains("_enter_selected_game_mode()"):
		push_error("Online local-transition guard test failed: game mode is not promoted after server authentication.")
		quit(1)
		return
	print("Online local-transition guard source tests passed.")
	quit(0)
